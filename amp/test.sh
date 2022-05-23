#/bin/bash/env


awscurl --region eu-west-1 --service aps https://aps-workspaces.eu-west-1.amazonaws.com/workspaces/ws-47eb7077-4478-40e7-bb62-624957283ad8/alertmanager/api/v2/alerts -H 'Content-Type: application/json' | jq -r '.'
