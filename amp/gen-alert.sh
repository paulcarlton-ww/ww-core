#!/bin/bash

echo "setting up port-forward"
kubectl port-forward -n webapp svc/podinfo 9898 &
port_forward=$!
sleep 2

amp/panic.sh
echo "sleeping 20 seconds"
sleep 20
amp/panic.sh
echo "sleeping 40 seconds"
sleep 40
amp/panic.sh
echo "sleeping 60 seconds"
sleep 60
amp/panic.sh
echo "sleeping 100 seconds"
sleep 100
amp/panic.sh

echo "stopping up port-forward"
sleep 2
kill -9 $port_forward
