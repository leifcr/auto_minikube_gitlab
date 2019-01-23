#!/bin/sh
echo "Forcing IP as 192.168.99.100 by deleting HostInterfaceNetworking-vboxnet0*"
rm ~/.config/VirtualBox/HostInterfaceNetworking-vboxnet0*
# Start minikube
minikube start --memory 8192 --cpus 4
