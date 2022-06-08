#!/bin/bash

kubectl get pods -n webapp
echo "Sending panic"
curl -s http://127.0.0.1:9898/panic
