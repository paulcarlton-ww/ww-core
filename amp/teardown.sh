#!/bin/bash

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

if [ -n "$AMP_ID" ]; then
  aws amp delete-workspace --workspace-id $AMP_ID
fi

policy_arn=$(getPolicyArn pager-lambda-cloudwatch)
if [ -n "$policy_arn" ]; then 
  aws iam detach-role-policy --role-name pager-lambda-cloudwatch --policy-arn $policy_arn
  aws iam delete-policy --policy-arn $policy_arn
fi

role_arn=$(getRoleArn pager-lambda-cloudwatch)
if [ -n "$role_arn" ]; then
  aws iam delete-role --role-name pager-lambda-cloudwatch
fi

aws lambda delete-function --function-name pager

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

aws sns delete-topic --topic-arn arn:aws:logs:$AWS_REGION:$account_id:pager



