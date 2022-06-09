# ww-core

This repository is the cluster repository for paulcarlton-core EKS cluster. The cluster can be created using the eksctl control file. Update this file with required setting.

    eksctl delete cluster --config-file eksctl-config-ww-core.yaml --wait --force
    eksctl create cluster --config-file eksctl-config-ww-core.yaml 
    aws eks --region "$AWS_REGION" update-kubeconfig --name paulcarlton-core

## AMP

The `amp` folder contains scripts to deploy Prometheus remote write agent to the cluster in order to forward metrics tos Amazon Managed Prometheus and from there ownward to pager duty.

To deploy this execute the amp/setup.sh script. This script requires environmental variables containing pager duty integration key and cluster name.

    export PAGER_DUTY_KEY=<integration key>
    export CLUSTER_NAME=<eks cluster name>
    amp/setup.sh

The `amp/setup.sh` script can be rerun but to avoid it creating a new Amazon Managed Prometheus workspace set the `AMP_ID` environmental variable to the workspace id...

    export AMP_ID=ws-...
    amp/setup.sh
