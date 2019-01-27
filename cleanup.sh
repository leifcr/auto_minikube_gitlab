#!/bin/sh
# Delete any keys that might be saved when using git or ssh
ssh-keygen -R $(minikube ip)
ssh-keygen -R gitlab.$(minikube ip).nip.io
ssh-keygen -R $(minikube ip).nip.io
# Delete cluster
minikube delete
# Cleanup virtual ips
echo "Cleaning up virtualbox host only dhcp ips - NOTE: Any host-only ip already set will be deleted on ALL hostonly interfaces"
rm ~/.config/VirtualBox/HostInterfaceNetworking-vboxnet*
