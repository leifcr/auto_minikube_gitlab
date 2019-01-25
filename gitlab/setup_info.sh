#!/bin/sh
echo Server: $(kubectl cluster-info | grep 'Kubernetes master' | awk '/http/ {print $NF}')
echo "\nToken:"
echo "$(kubectl get secret $(kubectl get secrets | grep gitlab-token | cut -f1 -d ' ') -o jsonpath="{['data']['token']}" | base64 --decode)"
echo "\nCA:"
echo "$(kubectl get secret $(kubectl get secrets | grep gitlab-token | cut -f1 -d ' ') -o jsonpath="{['data']['ca\.crt']}" | base64 --decode)"
