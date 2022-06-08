#!/bin/bash
set -x
kubectl port-forward -n webapp svc/podinfo 9898 &
port_forward=$!
sleep 2
curl -s http://127.0.0.1:9898/panic
sleep 2
kill -9 $port_forward
