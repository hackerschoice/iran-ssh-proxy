#! /bin/bash

[[ ! -d /config/etc/ssh ]] && mkdir -p /config/etc/ssh
[[ ! -f /config/etc/ssh/ssh_host_rsa_key ]] && ssh-keygen -A -f /config

ulimit -n 1048576
exec /usr/sbin/sshd -u0 -D
