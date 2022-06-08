#!/bin/bash

set -e

account_id=$(aws sts get-caller-identity --query "Account" --output text)

function getRoleArn() {
  OUTPUT=$(aws iam get-role --role-name $1 --query 'Role.Arn' --output text 2>&1)

  # Check for an expected exception
  if [[ $? -eq 0 ]]; then
    echo $OUTPUT
  elif [[ -n $(grep "NoSuchEntity" <<< $OUTPUT) ]]; then
    echo ""
  else
    >&2 echo $OUTPUT
    return 1
  fi
}

function getPolicyArn() {
  OUTPUT=$(aws iam get-policy --policy-arn arn:aws:iam::$account_id:policy/$1 --query 'Policy.Arn' --output text 2>&1)

  # Check for an expected exception
  if [[ $? -eq 0 ]]; then
    echo $OUTPUT
  elif [[ -n $(grep "NoSuchEntity" <<< $OUTPUT) ]]; then
    echo ""
  else
    >&2 echo $OUTPUT
    return 1
  fi
}

if [ -z "$CLUSTER_NAME" ]; then
  echo "export CLUSTER_NAME=<name of eks cluster>"
  exit 1
fi

if [ -z "$AMP_ID" ]; then
  amp_id=$(aws amp create-workspace | jq -r '."workspaceId"')
else
  amp_id=$AMP_ID
fi

export amp_endpoint=$(aws amp describe-workspace --workspace-id $amp_id | jq -r '.workspace.prometheusEndpoint')

export CLUSTER_NAME=paulcarlton-core
./amp/amp-ingest.sh
./amp/amp-query.sh
git add -A
git commit -a -m "deploy prometheus"
git push

pushd amp/alerts
for name_space in $(aws amp list-rule-groups-namespaces --workspace-id $amp_id --region $AWS_REGION | jq -r '.ruleGroupsNamespaces[].name')
do
  aws amp delete-rule-groups-namespace --name $name_space --workspace-id $amp_id --region $AWS_REGION
done

while [ -n "$(aws amp list-rule-groups-namespaces --workspace-id $amp_id --region $AWS_REGION | jq -r '.ruleGroupsNamespaces[].name')" ]
do
  echo "waiting for previous rule namespaces to be deleted"
  sleep 1
done

base64 < alert_rules1.yaml > /tmp/alert_rules1.b64
base64 < alert_rules2.yaml > /tmp/alert_rules2.b64
base64 < alert_rules3.yaml > /tmp/alert_rules3.b64
base64 < alert_rules4.yaml > /tmp/alert_rules4.b64
base64 < test_alert_rules.yaml > /tmp/test_alert_rules.b64
aws amp  create-rule-groups-namespace --data file:///tmp/alert_rules1.b64 --name k8s.rules1 --workspace-id $amp_id --region $AWS_REGION
aws amp  create-rule-groups-namespace --data file:///tmp/alert_rules2.b64 --name k8s.rules2 --workspace-id $amp_id --region $AWS_REGION
aws amp  create-rule-groups-namespace --data file:///tmp/alert_rules3.b64 --name k8s.rules3 --workspace-id $amp_id --region $AWS_REGION
aws amp  create-rule-groups-namespace --data file:///tmp/alert_rules4.b64 --name k8s.rules4 --workspace-id $amp_id --region $AWS_REGION
aws amp  create-rule-groups-namespace --data file:///tmp/test_alert_rules.b64 --name test --workspace-id $amp_id --region $AWS_REGION

policy_arn=$(getPolicyArn pager-lambda-cloudwatch)
if [ -z "$policy_arn" ]; then 
  policy_arn=$(aws iam create-policy --policy-name pager-lambda-cloudwatch --policy-document file:///tmp/pager-lambda-cloudwatch.json | jq -r '.Policy.Arn')
fi
role_arn=$(getRoleArn pager-lambda-cloudwatch)
if [ -z "$role_arn" ]; then
  role_arn=$(aws iam create-role --role-name pager-lambda-cloudwatch --assume-role-policy-document file://sns-trust.json | jq -r '.Role.Arn')
fi
aws iam attach-role-policy --role-name pager-lambda-cloudwatch --policy-arn $policy_arn

lambda_arn=$(aws lambda get-function --function-name pager | jq -r '.Configuration.FunctionArn')
if [ -z "$lambda_arn" ]; then
  src=$PWD
  rm -rf /tmp/pager-sourcecode-function
  mkdir -p /tmp/pager-sourcecode-function
  pushd /tmp/pager-sourcecode-function
  cp $src/pager.py lambda_function.py
  python3 -m venv myvenv
  source myvenv/bin/activate
  pip install --target ./package requests
  pip3 install --target ./package requests
  pip3 install --target ./package urllib3
  pip3 install --target ./package pyyaml
  pushd package
  zip -r ../pager-deployment-package.zip .
  popd
  zip -g pager-deployment-package.zip lambda_function.py
  lambda_arn=$(aws lambda create-function --function-name pager --zip-file fileb://pager-deployment-package.zip \
              --handler lambda_function.lambda_handler --runtime python3.9 --role $role_arn | jq -r '."FunctionArn"')
  popd
fi
popd

cat <<EOF >/tmp/pager-lambda-cloudwatch.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "arn:aws:logs:$AWS_REGION:$account_id:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:$AWS_REGION:$account_id:log-group:/aws/lambda/pager:*"
            ]
        }
    ]
}
EOF

topic_arn=$(aws sns get-topic-attributes --topic-arn arn:aws:sns:$AWS_REGION:$account_id:pager | jq -r '.Attributes.TopicArn')
if [ -z "$topic_arn" ]; then
  topic_arn=$(aws sns create-topic --name pager | jq -r '.TopicArn')
  aws lambda add-permission --function-name pager --source-arn $topic_arn --statement-id pager --action "lambda:InvokeFunction" --principal sns.amazonaws.com
fi

cat <<EOF >/tmp/sns-policy.json
{
  "Version": "2008-10-17",
  "Id": "__default_policy_ID",
  "Statement": [
    {
        "Sid": "Allow_Publish_Alarms",
        "Effect": "Allow",
        "Principal": {
            "Service": "aps.amazonaws.com"
        },
        "Action": [
            "sns:Publish",
            "sns:GetTopicAttributes"
        ],
        "Condition": {
            "ArnEquals": {
                "aws:SourceArn": "arn:aws:aps:$AWS_REGION:$account_id:workspace/$amp_id"
            },
            "StringEquals": {
                "AWS:SourceAccount": "$account_id"
            }
        },
        "Resource": "$topic_arn"
    }
  ]
}
EOF

aws sns set-topic-attributes --topic-arn $topic_arn --attribute-name 'Policy' --attribute-value file:///tmp/sns-policy.json

aws sns subscribe --protocol lambda --topic-arn $topic_arn --notification-endpoint $lambda_arn

cat <<EOF >/tmp/alert-mgr.yaml
alertmanager_config: |
  route:
    group_by: ['alertname']
    group_wait: 30s
    group_interval: 1m
    repeat_interval: 5m
    receiver: Demo_Receiver

  receivers:
  - name: Demo_Receiver
    sns_configs:
    - send_resolved: true
      topic_arn: $topic_arn
      sigv4:
        region: $AWS_REGION
      message: |
        routing_key: $PAGER_DUTY_KEY
        dedup_key: {{ .CommonLabels.alertname }}  
        severity: {{ .CommonLabels.severity }}
        client_url: {{ .ExternalURL }}  
        description: {{ .CommonAnnotations.summary }}  
        details:
          node: {{ .CommonLabels.node }}
          namespace: {{ .CommonLabels.namespace }}
          pod: {{ .CommonLabels.pod }}
          instance: {{ .CommonLabels.instance }}  
          alert_name: {{ .CommonLabels.alertname }}
EOF

set +e
aws amp describe-alert-manager-definition --workspace-id $amp_id
if [ $? == 0 ]; then
  op=put
else
  op=create
fi
set -e

#aws amp delete-alert-manager-definition --workspace-id $amp_id

base64 < /tmp/alert-mgr.yaml > /tmp/alert-mgr.b64
aws amp $op-alert-manager-definition --data file:///tmp/alert-mgr.b64 --workspace-id $amp_id

echo "paste command below into your shell"
echo "export AMP_ID=$amp_id"
