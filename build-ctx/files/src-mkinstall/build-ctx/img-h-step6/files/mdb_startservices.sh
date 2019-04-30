#!/bin/bash

#
# by TS, Mar 2019
#

VAR_MYNAME="$(basename "$0")"

################################################################################

LVAR_SETTINGS_CACHE="/usr/local/etc/mdb-settings-cache.sh"

[ -f "$LVAR_SETTINGS_CACHE" ] || {
	echo "$VAR_MYNAME: Error: Not all settings have been updated yet. Aborting." >/dev/stderr
	exit 1
}
. "$LVAR_SETTINGS_CACHE"
[ "$SETTS_CACHE_ALLSET" != true ] && {
	echo "$VAR_MYNAME: Error: Not all settings have been updated yet. Aborting." >/dev/stderr
	exit 1
}

echo "$VAR_MYNAME: Stopping services..."
/root/mdb_stopservices.sh || exit 1

echo "$VAR_MYNAME: Starting services..."

service inetutils-syslogd start

if [ "$CF_CLAMAV_CONF_ENABLE" = "true" ]; then
	command -v freshclam >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		# update virus signatures first (usually returns non-zero value)
		if [ ! -f /var/lib/clamav/main.cvd ]; then
			echo "$VAR_MYNAME: Updating ClamAV's virus signatures..."
			freshclam --config-file=/etc/clamav/freshclam.conf || echo -n
		fi
		# now start services
		service clamav-daemon status | grep -q " is running"
		TMP_IS_RUNNING_DAE=$?
		service clamav-freshclam status | grep -q " is running"
		TMP_IS_RUNNING_FRE=$?
		if [ $TMP_IS_RUNNING_DAE -ne 0 -o $TMP_IS_RUNNING_FRE -ne 0 ]; then
			echo "$VAR_MYNAME: Starting ClamAV's services..."
			[ $TMP_IS_RUNNING_DAE -ne 0 ] && service clamav-daemon start
			[ $TMP_IS_RUNNING_FRE -ne 0 ] && service clamav-freshclam start
		fi
	else
		echo "$VAR_MYNAME: Warning: ClamAV should be started but is not supported by this Docker Image." >/dev/stderr
	fi
fi

if [ "$CF_OPENDKIM_CONF_ENABLE" = "true" ]; then
	command -v opendkim >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		if [ -f /var/run/opendkim/opendkim.pid ]; then
			TMP_OD_PID="$(ps ax | grep "/usr/sbin/opendkim" | grep -v " grep " | awk '/opendkim/ { print $1 }')"
			if [ -n "$TMP_OD_PID" -a "$TMP_OD_PID" != "$(cat /var/run/opendkim/opendkim.pid)" ]; then
				echo "$VAR_MYNAME: (removing old opendkim.pid file)"
				rm /var/run/opendkim/opendkim.pid
			fi
		fi
		service opendkim start
	else
		echo "$VAR_MYNAME: Warning: OpenDKIM should be started but is not supported by this Docker Image." >/dev/stderr
	fi
fi

service radicale start

service spamassassin start
service postfix start
service dovecot start
service amavis start
service cron start

service apache2 start

echo "$VAR_MYNAME: All services have been started."
