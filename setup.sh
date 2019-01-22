#!/bin/sh
echo "Forcing IP as 192.168.99.100 by deleting HostInterfaceNetworking-vboxnet0*"
rm ~/.config/VirtualBox/HostInterfaceNetworking-vboxnet0*

# Create certificates
./certs.sh 192.168.99.100

# Copy certificates

mkdir -p ~/.minikube/certs
cp ./certs/minikube-self-ca.crt ~/.minikube/certs/ca.pem
cp ./certs/minikube-self-ca.key ~/.minikube/certs/ca-key.pem
cp ./certs/minikube-self-ca.crt ~/.minikube/ca.crt
cp ./certs/minikube-self-ca.key ~/.minikube/ca.key

# Start minikube
minikube start
minikube ip

# Install gitlab using helm

# All good?