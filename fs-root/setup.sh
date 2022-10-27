#! /bin/bash



sed  '/^proxy.*/d' -i /etc/passwd
sed  '/^proxy.*/d' -i /etc/group
useradd -s /bin/proxysh proxy
echo "proxy:proxy" | chpasswd
mkdir /home/proxy
chown proxy:proxy /home/proxy

mkdir -p /run/sshd


