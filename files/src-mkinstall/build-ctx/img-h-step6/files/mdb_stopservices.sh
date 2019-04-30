#!/bin/bash

#
# by TS, Mar 2019
#

################################################################################

# @param string $1 Service-Name
#
# @return int EXITCODE
function _mdbStop_stopServiceIfRunning() {
	service $1 status | grep -q " is running" && service $1 stop
}

_mdbStop_stopServiceIfRunning apache2

_mdbStop_stopServiceIfRunning cron

_mdbStop_stopServiceIfRunning amavis

_mdbStop_stopServiceIfRunning dovecot

# the postfix service definition in /etc/init.d/postfix
# is buggy at the moment so we use our own 'service postfix stop' implementation
TMP_PF_PID="$(ps ax | grep "/usr/lib/postfix/sbin/master" | grep -v " grep " | awk '/postfix/ { print $1 }')"
if [ -n "$TMP_PF_PID" ]; then
	## pretend to stop the service...
	service postfix stop
	## now really stop the service...
	kill $TMP_PF_PID
fi
#
_mdbStop_stopServiceIfRunning spamassassin

_mdbStop_stopServiceIfRunning radicale

if [ "$CF_OPENDKIM_CONF_ENABLE" = "true" ]; then
	command -v opendkim >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		# the opendkim service definition in /etc/init.d/opendkim
		# is buggy at the moment so we use our own 'service opendkim stop' implementation
		if [ -f /var/run/opendkim/opendkim.pid ]; then
			TMP_OD_PID="$(ps ax | grep "/usr/sbin/opendkim" | grep -v " grep " | awk '/opendkim/ { print $1 }')"
			if [ -n "$TMP_OD_PID" ]; then
				echo -n "Stopping OpenDKIM Mail-signing service: opendkim"
				kill $(cat /var/run/opendkim/opendkim.pid)
				sleep 1
				echo "."
			fi
		fi
		[ -f /var/run/opendkim/opendkim.pid ] && rm /var/run/opendkim/opendkim.pid
	fi
fi

if [ "$CF_CLAMAV_CONF_ENABLE" = "true" ]; then
	command -v freshclam >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		_mdbStop_stopServiceIfRunning clamav-freshclam
		_mdbStop_stopServiceIfRunning clamav-daemon
	fi
fi

_mdbStop_stopServiceIfRunning inetutils-syslogd

exit 0
