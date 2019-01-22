#!/bin/sh
echo "Forcing IP as 192.168.99.100 by deleting HostInterfaceNetworking-vboxnet0*"
rm ~/.config/VirtualBox/HostInterfaceNetworking-vboxnet0*

# Create certificates
./certs.sh 192.168.99.100

# Copy certificates

# Start minikube
minikube start
minikube ip

# Install gitlab using helm

# All good?