#/bin/bash
set -x
session_token=$(aws configure get aws_session_token | sed s/\"//g)
access_key_id=$(aws configure get aws_access_key_id | sed s/\"//g)
access_secret=$(aws configure get aws_secret_access_key | sed s/\"//g)
awscurl -v --region $AWS_REGION --access_key $access_key_id --secret_key $access_secret --session_token $session_token --service aps https://aps-workspaces.eu-west-1.amazonaws.com/workspaces/$AMP_ID/alertmanager/api/v2/alerts -H 'Accept: application/json' | jq -r '.'
