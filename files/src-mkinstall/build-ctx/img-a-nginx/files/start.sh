#! /bin/bash

#
# by TS, Apr 2019
#

# @param string $1 Input filename
# @param string $2 Variable name
# @param string $3 Value
#
# @return int EXITCODE
function _start_replaceVarInFile() {
	local TMP_START_SED_VAL="$(echo -n "$3" | sed -e 's/\//\\\//g')"
	case "$OSTYPE" in
		linux*)
			sed -e "s/<$2>/$TMP_START_SED_VAL/g" -i "$1" || return 1
			;;
		darwin*)
			sed -e "s/<$2>/$TMP_START_SED_VAL/g" -i '' "$1" || return 1
			;;
		*)
			echo "Error: Unknown OSTYPE '$OSTYPE'" >/dev/stderr
			return 1
			;;
	esac
	return 0
}

# @param string $1 Input filename
#
# @return int EXITCODE
function _start_createVhostFile() {
	local TMP_START_OUTP_FN="/etc/nginx/sites-enabled/${1}"
	if [ -f "$TMP_START_OUTP_FN" ]; then
		echo "Not creating '$TMP_START_OUTP_FN'. File already exists."
	else
		echo "Creating '$TMP_START_OUTP_FN'..."
		cp "/etc/nginx/sites-available/${1}.template" "$TMP_START_OUTP_FN" || return 1
		_start_replaceVarInFile "$TMP_START_OUTP_FN" "CF_DAVHOSTNAME" "$CF_DAVHOSTNAME" || return 1
		_start_replaceVarInFile "$TMP_START_OUTP_FN" "CF_MAILHOSTNAME" "$CF_MAILHOSTNAME" || return 1
		_start_replaceVarInFile "$TMP_START_OUTP_FN" "CF_MAILDOMAIN" "$CF_MAILDOMAIN" || return 1
		_start_replaceVarInFile "$TMP_START_OUTP_FN" "CF_DEST_SERVER_ADDR" "$CF_DEST_SERVER_ADDR" || return 1
		_start_replaceVarInFile "$TMP_START_OUTP_FN" "CF_DEST_SERVER_HTTP_PORT" "$CF_DEST_SERVER_HTTP_PORT" || return 1
		_start_replaceVarInFile "$TMP_START_OUTP_FN" "CF_DEST_SERVER_HTTPS_PORT" "$CF_DEST_SERVER_HTTPS_PORT" || return 1
	fi
	return 0
}

# @param string $1 Hostname
# @param string $2 Domain
# @param string $3 optional: "internal"
#
# @return int EXITCODE
function _start_generateSsl() {
	local TMP_START_PATH_SUF=""
	[ "$3" = "internal" ] && TMP_START_PATH_SUF="-$3"
	local TMP_START_PRIVKEY_FN="/etc/ssl/host-keys${TMP_START_PATH_SUF}/private-${1}.${2}.key"
	local TMP_START_PUB_CERT_FN="/etc/ssl/host-certs${TMP_START_PATH_SUF}/client-${1}.${2}.crt"

	if [ -f "$TMP_START_PRIVKEY_FN" -a -f "$TMP_START_PUB_CERT_FN" ]; then
		echo "Not generating '$TMP_START_PRIVKEY_FN' and '$TMP_START_PUB_CERT_FN'. Files already exist."
	else
		echo "Generating '$TMP_START_PRIVKEY_FN' and '$TMP_START_PUB_CERT_FN'..."
		/root/sslgen.sh "${1}.${2}" $3 || return 1
	fi
	return 0
}

#
export HOST_IP=$(/sbin/ip route|awk '/default/ { print $3 }')
echo "$HOST_IP dockerhost" >> /etc/hosts

# generate SSL-Cert/Key for default virtual host
_start_generateSsl "default" "localhost" "internal" || exit 1

#
if [ "$CF_CREATE_VHOSTS" = "true" ]; then
	if [ \
			-n "$CF_MAILHOSTNAME" -a \
			-n "$CF_MAILDOMAIN" -a \
			-n "$CF_DEST_SERVER_ADDR" -a \
			-n "$CF_DEST_SERVER_HTTP_PORT" ]; then
		_start_createVhostFile "060-webmail-https" || exit 1
		_start_createVhostFile "061-webmail-redir_http_https" || exit 1
	else
		echo "Not enabling webmailer virtual hosts." >/dev/stderr
		[ -z "$CF_MAILHOSTNAME" ] && echo "  (CF_MAILHOSTNAME not set)" >/dev/stderr
		[ -z "$CF_MAILDOMAIN" ] && echo "  (CF_MAILDOMAIN not set)" >/dev/stderr
		[ -z "$CF_DEST_SERVER_ADDR" ] && echo "  (CF_DEST_SERVER_ADDR not set)" >/dev/stderr
		[ -z "$CF_DEST_SERVER_HTTP_PORT" ] && echo "  (CF_DEST_SERVER_HTTP_PORT not set)" >/dev/stderr
	fi
	if [ \
			-n "$CF_DAVHOSTNAME" -a \
			-n "$CF_MAILDOMAIN" -a \
			-n "$CF_DEST_SERVER_ADDR" -a \
			-n "$CF_DEST_SERVER_HTTPS_PORT" ]; then
		_start_createVhostFile "050-dav-https" || exit 1
	else
		echo "Not enabling DAV virtual host." >/dev/stderr
		[ -z "$CF_DAVHOSTNAME" ] && echo "  (CF_DAVHOSTNAME not set)" >/dev/stderr
		[ -z "$CF_MAILDOMAIN" ] && echo "  (CF_MAILDOMAIN not set)" >/dev/stderr
		[ -z "$CF_DEST_SERVER_ADDR" ] && echo "  (CF_DEST_SERVER_ADDR not set)" >/dev/stderr
		[ -z "$CF_DEST_SERVER_HTTPS_PORT" ] && echo "  (CF_DEST_SERVER_HTTPS_PORT not set)" >/dev/stderr
	fi
	if [ \
			-n "$CF_MAILDOMAIN" -a \
			-n "$CF_DEST_SERVER_ADDR" -a \
			-n "$CF_DEST_SERVER_HTTP_PORT" ]; then
		_start_createVhostFile "040-autoconfig-http" || exit 1
	else
		echo "Not enabling mail-autoconfig virtual host." >/dev/stderr
		[ -z "$CF_MAILDOMAIN" ] && echo "  (CF_MAILDOMAIN not set)" >/dev/stderr
		[ -z "$CF_DEST_SERVER_ADDR" ] && echo "  (CF_DEST_SERVER_ADDR not set)" >/dev/stderr
		[ -z "$CF_DEST_SERVER_HTTP_PORT" ] && echo "  (CF_DEST_SERVER_HTTP_PORT not set)" >/dev/stderr
	fi
	#
	if [ \
			-n "$CF_MAILHOSTNAME" -a \
			-n "$CF_MAILDOMAIN" ]; then
		_start_generateSsl "$CF_MAILHOSTNAME" "$CF_MAILDOMAIN" || exit 1
	else
		echo "Not generating SSL-Cert/Key for webmailer." >/dev/stderr
		[ -z "$CF_MAILHOSTNAME" ] && echo "  (CF_MAILHOSTNAME not set)" >/dev/stderr
		[ -z "$CF_MAILDOMAIN" ] && echo "  (CF_MAILDOMAIN not set)" >/dev/stderr
	fi
	if [ \
			-n "$CF_DAVHOSTNAME" -a \
			-n "$CF_MAILDOMAIN" ]; then
		_start_generateSsl "$CF_DAVHOSTNAME" "$CF_MAILDOMAIN" || exit 1
	else
		echo "Not generating SSL-Cert/Key for DAV." >/dev/stderr
		[ -z "$CF_DAVHOSTNAME" ] && echo "  (CF_DAVHOSTNAME not set)" >/dev/stderr
		[ -z "$CF_MAILDOMAIN" ] && echo "  (CF_MAILDOMAIN not set)" >/dev/stderr
	fi
else
	echo "Not creating virtual hosts (CF_CREATE_VHOSTS=false)."
fi

#
echo "Starting Nginx service in foreground..."
nginx -g "daemon off;"
