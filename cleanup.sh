#!/bin/sh
# Delete any keys that might be saved when using git or ssh
IP=$(minikube ip)
ssh-keygen -R $IP
ssh-keygen -R gitlab.$IP.nip.io
ssh-keygen -R $IP.nip.io
ssh-keygen -R "[gitlab.$IP.nip.io]:2222"
ssh-keygen -R "[$IP]:2222"
# Delete cluster
minikube delete
# Cleanup virtual ips
echo "Cleaning up virtualbox host only dhcp ips - NOTE: Any host-only ip already set will be deleted on ALL hostonly interfaces"
rm ~/.config/VirtualBox/HostInterfaceNetworking-vboxnet0*
