#!/usr/bin/env bash

#
# by TS, Mar 2019
#

VAR_MYNAME="$(basename "$0")"

################################################################################

set -e

# USE the trap if you need to also do manual cleanup after the service is stopped,
#     or need to start multiple services in the one container
trap "echo TRAPed signal" HUP INT QUIT TERM

# ----------------------------------------------------------------------
# Host IP/Name

export HOST_IP=$(/sbin/ip route | awk '/default/ { print $3 }')
echo "$HOST_IP dockerhost" >> /etc/hosts

# ----------------------------------------------------------------------
# Volumes

function _dep_setOwnerAndPerms() {
	[ -d "$1" ] && {
		chown $2:$3 "$1" && chmod "$4" "$1"
	}
}

_dep_setOwnerAndPerms "/srv/modoboa/pdfcredentials/" modoboa modoboa "770"
_dep_setOwnerAndPerms "/srv/modoboa/rrdfiles/" modoboa modoboa "770"
_dep_setOwnerAndPerms "/srv/vmail/" vmail vmail "755"
_dep_setOwnerAndPerms "/var/lib/clamav/" clamav clamav "755"
_dep_setOwnerAndPerms "/var/log/apache2/modoboa/" root root "755"
_dep_setOwnerAndPerms "/var/log/mail/" root root "755"
_dep_setOwnerAndPerms "/var/log/radicale/" radicale radicale "755"
_dep_setOwnerAndPerms "/etc/ssl/host-certs" root root "755"
_dep_setOwnerAndPerms "/etc/ssl/host-keys" root ssl-cert "750"
_dep_setOwnerAndPerms "/etc/radicale/modo_rights" radicale radicale "750"
_dep_setOwnerAndPerms "/srv/radicale/collections" radicale radicale "750"

# ----------------------------------------------------------------------
# update settings

LVAR_SETTINGS_CACHE="/usr/local/etc/mdb-settings-cache.sh"

function _dep_updateMdbSettings() {
	if [ "$SETTS_CACHE_DJANGO_SECRET_CHANGED" != "true" ]; then
		echo -e "\n$VAR_MYNAME: Generating Django Secret Key..."
		local TMP_MODOBOA_CONF_DJANGO_SECRETKEY="$(/root/pwgen.sh 32)"
		[ -z "$TMP_MODOBOA_CONF_DJANGO_SECRETKEY" ] && {
			echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr
			return 1
		}
		#echo "$VAR_MYNAME:   (Django SecKey: '$TMP_MODOBOA_CONF_DJANGO_SECRETKEY')"
		/root/mdb_update.sh --django-secretkey "$TMP_MODOBOA_CONF_DJANGO_SECRETKEY"
	fi

	# update all other settings from ENV vars
	echo -e "\n$VAR_MYNAME: Updating settings..."
	/root/mdb_update.sh || return 1

	# get new settings
	. "$LVAR_SETTINGS_CACHE"
}

SETTS_CACHE_ALLSET=false
if [ -f "$LVAR_SETTINGS_CACHE" ]; then
	. "$LVAR_SETTINGS_CACHE" || exit 1
fi

if [ "$CF_AUTO_UPDATE_CONFIG" = "true" ]; then
	_dep_updateMdbSettings || exit 1
fi

# ----------------------------------------------------------------------

if [ "$SETTS_CACHE_ALLSET" = "true" ]; then
	/root/mdb_startservices.sh || exit 1
else
	echo "$VAR_MYNAME: Warning: Not all settings have been updated yet. Not starting services." >/dev/stderr
fi

# ----------------------------------------------------------------------

exec "$@"
