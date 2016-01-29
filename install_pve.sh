#!/bin/bash

hostsContents=$( cat /etc/hosts )
echo "$hostsContents" | grep --invert-match `hostname` >/etc/hosts && echo `hostname -I` `hostname` `hostname -f` pvelocalhost >>/etc/hosts

if ( test -f /etc/apt/sources.list.d/pve-enterprise.list ); then
    mv /etc/apt/sources.list.d/pve-enterprise.list /etc/apt/sources.list.d/pve-enterprise.list.disabled
fi

export DEBIAN_FRONTEND=noninteractive

if ( ! `dpkg --get-selections | grep --quiet proxmox-ve` ); then
    echo "deb http://download.proxmox.com/debian jessie pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list
    wget -O- "http://download.proxmox.com/debian/key.asc" | apt-key add -

    apt-get --assume-yes --quiet update
    apt-get --assume-yes --quiet dist-upgrade
    apt-get --assume-yes --quiet install proxmox-ve ssh postfix ksm-control-daemon open-iscsi openvswitch-switch zfsutils

    interfacesContents=$( cat <<interfacesContents
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

allow-vmbr0 eth0
iface eth0 inet manual
        ovs_type OVSPort
        ovs_bridge vmbr0

auto vmbr0
iface vmbr0 inet dhcp
        ovs_type OVSBridge
        ovs_ports eth0

allow-ovs vmbr0
interfacesContents
)
    echo "$interfacesContents" >/etc/network/interfaces

    shutdown -r 1
elif ( `dpkg --get-selections | grep --quiet linux-base` ); then
    apt-get --assume-yes --quiet --purge remove linux-image-amd64 linux-base
    update-grub

    zpool create firstpool /dev/disk/by-partlabel/firstpool
    pvesm add zfspool zfs_firstpool -pool firstpool -content rootdir -nodes `hostname` -sparse

    # clean up
    apt-get clean

    # Zero free space to aid VM compression
    dd if=/dev/zero of=/EMPTY bs=1M
    rm -f /EMPTY

    shutdown -h 1
fi
