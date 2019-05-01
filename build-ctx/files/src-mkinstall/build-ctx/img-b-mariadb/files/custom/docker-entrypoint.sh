#! /bin/bash

#
# by TS, Apr 2019
#

# ----------------------------------------------------------------------
# Volumes

function _dep_setOwnerAndPerms_recursive() {
	[ -d "$1" ] && {
		chown $2:$3 -R "$1" && chmod "$4" -R "$1"
	}
}

#_dep_setOwnerAndPerms_recursive "/var/lib/mysql" mysql mysql "750"
_dep_setOwnerAndPerms_recursive "/var/lib/mysql" abc abc "750"

# ----------------------------------------------------------------------

export HOST_IP=$(/sbin/ip route|awk '/default/ { print $3 }')
echo "$HOST_IP dockerhost" >> /etc/hosts

# ----------------------------------------------------------------------

/init "$@"
