#!/bin/sh
echo "Cleaning up virtualbox host only dhcp ips - NOTE: Any host-only ip already set will be deleted on ALL hostonly interfaces"
rm ~/.config/VirtualBox/HostInterfaceNetworking-vboxnet*
