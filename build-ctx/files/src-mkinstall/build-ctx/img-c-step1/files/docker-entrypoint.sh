#!/usr/bin/env bash

#
# by TS, Mar 2019
#

set -e

# Host IP/Name
export HOST_IP=$(/sbin/ip route | awk '/default/ { print $3 }')
echo "$HOST_IP dockerhost" >> /etc/hosts

#
a2ensite default-ssl.conf
service apache2 start

#
exec "$@"
