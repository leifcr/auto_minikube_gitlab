#!/bin/sh
IP=$(minikube ip)
echo "\nInformation for gitlab setup"
echo "API  ip: Server: $(kubectl cluster-info | grep 'Kubernetes master' | awk '/http/ {print $NF}')"
echo "    url: HTTPS:  https://kubeapi.$IP.nip.io:8443"
echo "         HTTP:   http://kubeapi.$IP.nip.io:8443"
echo "\nToken:"
echo "$(kubectl get secret $(kubectl get secrets | grep gitlab-token | cut -f1 -d ' ') -o jsonpath="{['data']['token']}" | base64 --decode)"
echo "\nCA:"
echo "$(kubectl get secret $(kubectl get secrets | grep gitlab-token | cut -f1 -d ' ') -o jsonpath="{['data']['ca\.crt']}" | base64 --decode)"

