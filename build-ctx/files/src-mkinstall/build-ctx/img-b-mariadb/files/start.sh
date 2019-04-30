#! /bin/bash

#
# by TS, Apr 2019
#

# ----------------------------------------------------------------------
# Volumes

function _dep_setOwnerAndPerms() {
	[ -d "$1" ] && {
		chown $2:$3 "$1" && chmod "$4" "$1"
	}
}

_dep_setOwnerAndPerms "/var/lib/mysql" mysql mysql "750"

# ----------------------------------------------------------------------

export HOST_IP=$(/sbin/ip route|awk '/default/ { print $3 }')
echo "$HOST_IP dockerhost" >> /etc/hosts

/docker-entrypoint.sh mysqld
