#!/bin/bash/env

kubectl port-forward -n webapp svc/podinfo 9898 &
port_forward=$!

