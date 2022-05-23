#/bin/bash


awscurl --region eu-west-1 --service aps https://aps-workspaces.eu-west-1.amazonaws.com/workspaces/$AMP_ID/alertmanager/api/v2/alerts -H 'Accept: application/json' | jq -r '.'
