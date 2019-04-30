#!/bin/bash

#
# by TS, Mar 2019
#

VAR_MYNAME="$(basename "$0")"
VAR_MYDIR="$(realpath "$0")"
VAR_MYDIR="$(dirname "$VAR_MYDIR")"

################################################################################

# delete compiled settings.pyc
LVAR_MODO_SETTS_PY="/srv/modoboa/instance/instance/settings.py"
LVAR_MODO_SETTS_PYC="$(dirname "$LVAR_MODO_SETTS_PY")/$(basename "$LVAR_MODO_SETTS_PY" ".py").pyc"

[ -f "$LVAR_MODO_SETTS_PYC" ] && rm "$LVAR_MODO_SETTS_PYC"

#
LVAR_SETTINGS_CACHE="/usr/local/etc/mdb-settings-cache.sh"

[ -f "$LVAR_SETTINGS_CACHE" ] || touch "$LVAR_SETTINGS_CACHE"
. "$LVAR_SETTINGS_CACHE"

SETTS_CACHE_DJANGO_SECRET_CHANGED=${SETTS_CACHE_DJANGO_SECRET_CHANGED:-false}

#
LVAR_SSL_CERTS="/etc/ssl/host-certs"
LVAR_SSL_KEYS="/etc/ssl/host-keys"

LVAR_SSL_POSTFIX_KEY="/etc/ssl/host-postfix.key"
LVAR_SSL_POSTFIX_CRT="/etc/ssl/host-postfix.crt"
LVAR_SSL_DOVECOT_KEY="/etc/ssl/host-dovecot.key"
LVAR_SSL_DOVECOT_CRT="/etc/ssl/host-dovecot.crt"

#
LVAR_DB_TEMPFILE_PREFIX="/tmp/tmp.mdb_update.$$-"

#
LVAR_CUSTOMIZE_MODO_LCONF_PY_SCRIPT_FN="/root/customize_modo_lconf.py"

################################################################################

LVAR_TRAPPED_INT=false

function _mdbUpd__trapCallback_int() {
	echo "$VAR_MYNAME: Trapped CTRL-C" >/dev/stderr
	LVAR_TRAPPED_INT=true
}

# trap ctrl-c (INTERRUPT signal)
trap _mdbUpd__trapCallback_int INT

################################################################################
# Database Functions

# Outputs result of SQL-Query if any
#
# @param string $1 DBUSER
# @param string $2 DBPASS
# @param string $3 SQL-Query
#
# @return int EXITCODE
function _mdbUpd__execSqlQuery() {
	if [ -z "$1" -o -z "$2" ]; then
		echo "$VAR_MYNAME: Error: DBUSER or DBPASS empty. Aborting." >/dev/stderr
		return 1
	fi
	if [ -z "$3" ]; then
		echo "$VAR_MYNAME: Error: SQL-Query must not be empty. Aborting." >/dev/stderr
		return 1
	fi

	mysql -h "$LVAR_ARG_MARIADB_DOCKERHOST" --port=3306 --protocol tcp \
			-u "$1" \
			--password="$2" \
			--connect-timeout=1 \
			-e "$3" \
			>"${LVAR_DB_TEMPFILE_PREFIX}db1" 2>/dev/stderr
	local TMP_RES=$?

	#echo -e "\n++## RESP:" >/dev/stderr
	#cat "${LVAR_DB_TEMPFILE_PREFIX}db1" >/dev/stderr
	#echo >/dev/stderr

	if [ $TMP_RES -eq 0 ]; then
		grep -v "Using a password on the command line" "${LVAR_DB_TEMPFILE_PREFIX}db1"
	fi
	rm "${LVAR_DB_TEMPFILE_PREFIX}db1"
	return $TMP_RES
}

# @param string $1 DBUSER
# @param string $2 DBPASS
#
# @return int EXITCODE
function _mdbUpd_db_checkDbConnection_sub() {
	local TMP_CMD="SHOW DATABASES;"
	_mdbUpd__execSqlQuery "$1" "$2" "$TMP_CMD" >/dev/null
}

# @param string $1 DBUSER
# @param string $2 DBPASS
#
# @return int EXITCODE
function _mdbUpd_db_checkDbConnection() {
	echo "$VAR_MYNAME: Checking connection to DB-Server..."
	local TMP_WAIT_CNT=0
	while [ $TMP_WAIT_CNT -lt 100 ]; do
		[ "$LVAR_TRAPPED_INT" = "true" ] && {
			TMP_WAIT_CNT=100
			break
		}
		_mdbUpd_db_checkDbConnection_sub "$1" "$2" && break
		TMP_WAIT_CNT=$(( TMP_WAIT_CNT + 1 ))
		echo "$VAR_MYNAME: DB-Server not ready yet. Waiting 5s..."
		sleep 5
	done
	if [ $TMP_WAIT_CNT -eq 100 ]; then
		echo "$VAR_MYNAME: Error: Could not connect to DB-Server. Aborting." >/dev/stderr
		return 1
	fi
	echo "$VAR_MYNAME: Connection to DB-Server OK"
}

# Outputs CONF_JSON_ENC
#
# @param string $1 MODO_DBNAME
# @param string $2 MODO_DBPASS
#
# @return int EXITCODE
function _mdbUpd_db_readModoLocalconf() {
	local TMP_CMD="USE \`$1\`; \
			SELECT _parameters FROM \`core_localconfig\` WHERE id = 1;"
	_mdbUpd__execSqlQuery "$1" "$2" "$TMP_CMD" | tail -n +2
}

# @param string $1 MODO_DBNAME
# @param string $2 MODO_DBPASS
# @param string $3 CONF_JSON_ENC
#
# @return int EXITCODE
function _mdbUpd_db_writeModoLocalconf() {
	local TMP_CMD="USE \`$1\`; \
			UPDATE \`core_localconfig\` SET _parameters = '$3' WHERE id = 1;"
	_mdbUpd__execSqlQuery "$1" "$2" "$TMP_CMD"
}

# @param string $1 MODO_DBNAME
# @param string $2 MODO_DBPASS
# @param string $3 CONF_FQDN
#
# @return int EXITCODE
function _mdbUpd_db_writeModoDjangoSite() {
	local TMP_CMD="USE \`$1\`; \
			UPDATE \`django_site\` SET domain = '$3', name = '$3' WHERE id = 1;"
	_mdbUpd__execSqlQuery "$1" "$2" "$TMP_CMD"
}

# @param string $1 MODO_DBNAME
# @param string $2 MODO_DBPASS
# @param string $3 CONF_LANG_CODE
#
# @return int EXITCODE
function _mdbUpd_db_writeModoAdminLang() {
	local TMP_CMD="USE \`$1\`; \
			UPDATE \`core_user\` SET language = '$3' WHERE id = 1;"
	_mdbUpd__execSqlQuery "$1" "$2" "$TMP_CMD"
}

# @param string $1 MODO_DBNAME
# @param string $2 MODO_DBPASS
#
# @return int EXITCODE
function _mdbUpd_db_updateModoDkimView() {
	local TMP_CMD=""
	TMP_CMD="${TMP_CMD} SELECT CONCAT(\"ALTER DEFINER='$1'@'%' VIEW \","
	TMP_CMD="${TMP_CMD} table_name, \" AS \", view_definition, \";\")"
	TMP_CMD="${TMP_CMD} FROM information_schema.views"
	TMP_CMD="${TMP_CMD} WHERE table_schema='$1';"

	local TMP_ALTER_CMD="$(_mdbUpd__execSqlQuery "$1" "$2" "$TMP_CMD" | tail -n +2)"
	if [ -z "$TMP_ALTER_CMD" ]; then
		echo "$VAR_MYNAME: Error: Could not get generated ALTER statement. Aborting." >/dev/stderr
		return 1
	fi
	_mdbUpd__execSqlQuery "$1" "$2" "USE \`$1\`; $TMP_ALTER_CMD"
}

# @param string $1 FILENAME
#
# @return void
function _mdbUpd_printDebugFilename() {
	[ "$CF_DEBUG_MDB_SCRIPTS" = "true" ] && echo "$VAR_MYNAME:   * $1"
}

# @param string $1 TITLE
#
# @return void
function _mdbUpd_printDebugOther() {
	[ "$CF_DEBUG_MDB_SCRIPTS" = "true" ] && echo "$VAR_MYNAME:   * $1"
}

################################################################################

function showUsage() {
	echo "Usage: $VAR_MYNAME OPTION ARGUMENT [...]" >/dev/stderr
	echo >/dev/stderr
	echo "Examples: $VAR_MYNAME" >/dev/stderr
	echo "            (to update all settings except for the django-secretkey)" >/dev/stderr
	echo "          $VAR_MYNAME --django-secretkey 'SeCRetKEy0123'" >/dev/stderr
	echo "            (to update only the django-secretkey)" >/dev/stderr
	echo >/dev/stderr
	echo "Options:" >/dev/stderr
	echo "  --django-secretkey ARG" >/dev/stderr
	exit 1
}

################################################################################

# @param string $1 NEW_BOOL_VALUE
#
# @return int EXITCODE
function runUpdateModoCsrf() {
	echo -ne "\n$VAR_MYNAME: "
	[ "$1" = "true" ] && echo -n "En" || echo -n "Dis"
	echo "abling Modoboa's CSRF-Protection"

	local TMP_BOOL_PYTH="False"
	[ "$1" = "true" ] && TMP_BOOL_PYTH="True"

	_mdbUpd_printDebugFilename "$LVAR_MODO_SETTS_PY"
	sed -i \
			-e "s/^CSRF_COOKIE_SECURE = .*$/CSRF_COOKIE_SECURE = $TMP_BOOL_PYTH/g" \
			-e "s/^SESSION_COOKIE_SECURE = .*$/SESSION_COOKIE_SECURE = $TMP_BOOL_PYTH/g" \
			"$LVAR_MODO_SETTS_PY"
}

# @param string $1 NEW_BOOL_VALUE
#
# @return int EXITCODE
function runUpdateOpenDkimEnabled() {
	echo -ne "\n$VAR_MYNAME: "
	[ "$1" = "true" ] && echo -n "En" || echo -n "Dis"
	echo "abling OpenDKIM"

	local TMP_CRON_FN="/etc/cron.d/modoboa"
	local TMP_PF_M_FN="/etc/postfix/main.cf"

	if [ "$1" = "true" ]; then
		_mdbUpd_printDebugFilename "$TMP_CRON_FN"
		sed -i \
				-e "s/^#\*.*opendkim.*manage_dkim_keys$/\*       \*       \*       \*       \*       opendkim    umask 077 \&\& \$PYTHON \$INSTANCE\/manage.py modo manage_dkim_keys/g" \
				"$TMP_CRON_FN" || return 1
		_mdbUpd_printDebugFilename "$TMP_PF_M_FN"
		sed -i \
				-e "s/^#smtpd_milters =/smtpd_milters =/g" \
				-e "s/^#non_smtpd_milters =/non_smtpd_milters =/g" \
				-e "s/^#milter_default_action =/milter_default_action =/g" \
				-e "s/^#milter_content_timeout =/milter_content_timeout =/g" \
				"$TMP_PF_M_FN" || return 1
	else
		_mdbUpd_printDebugFilename "$TMP_CRON_FN"
		sed -i \
				-e "s/^\*.*opendkim.*manage_dkim_keys$/\#\*       \*       \*       \*       \*       opendkim    umask 077 \&\& \$PYTHON \$INSTANCE\/manage.py modo manage_dkim_keys/g" \
				"$TMP_CRON_FN" || return 1
		_mdbUpd_printDebugFilename "$TMP_PF_M_FN"
		sed -i \
				-e "s/^smtpd_milters =/#smtpd_milters =/g" \
				-e "s/^non_smtpd_milters =/#non_smtpd_milters =/g" \
				-e "s/^milter_default_action =/#milter_default_action =/g" \
				-e "s/^milter_content_timeout =/#milter_content_timeout =/g" \
				"$TMP_PF_M_FN" || return 1
	fi
	return 0
}

# @param string $1 NEW_BOOL_VALUE
#
# @return int EXITCODE
function runUpdateClamAvEnabled() {
	echo -ne "\n$VAR_MYNAME: "
	[ "$1" = "true" ] && echo -n "En" || echo -n "Dis"
	echo "abling ClamAV"

	local TMP_AMAV_FM_FN="/etc/amavis/conf.d/15-content_filter_mode"

	if [ "$1" = "true" ]; then
		_mdbUpd_printDebugFilename "$TMP_AMAV_FM_FN"
		sed -i \
				-e "s/^#\@bypass_virus_checks_maps =/\@bypass_virus_checks_maps =/g" \
				-e "s/^# *\\\%bypass_virus_checks/   \\\%bypass_virus_checks/g" \
				"$TMP_AMAV_FM_FN" || return 1
	else
		_mdbUpd_printDebugFilename "$TMP_AMAV_FM_FN"
		sed -i \
				-e "s/^\@bypass_virus_checks_maps =/#\@bypass_virus_checks_maps =/g" \
				-e "s/^ *\\\%bypass_virus_checks/#   \\\%bypass_virus_checks/g" \
				"$TMP_AMAV_FM_FN" || return 1
	fi
	return 0
}

# @param string $1 NEW_SECRET_KEY
#
# @return int EXITCODE
function runUpdateDjangoSecretkey() {
	echo "$VAR_MYNAME: Updating Django's SECRET_KEY"

	local TMP_SEC="$(grep "^SECRET_KEY = '" "$LVAR_MODO_SETTS_PY" | cut -c15-)"
	local TMP_SEC="$(echo -n "$TMP_SEC" | cut -c-$(( ${#TMP_SEC} - 1 )))"
	if [ "$CF_DEBUG_MDB_SCRIPTS" = "true" ]; then
		echo "$VAR_MYNAME:   last SECRET_KEY='$TMP_SEC'"
		echo "$VAR_MYNAME:   new  SECRET_KEY='$1'"
	fi

	_mdbUpd_printDebugFilename "$LVAR_MODO_SETTS_PY"
	sed -i -e "s/^SECRET_KEY = '.*'$/SECRET_KEY = '$1'/g" "$LVAR_MODO_SETTS_PY"
}

# @param string $1 DB_NAME_AND_USER
# @param string $2 DB_PASS
# @param string $3 FN_FOR_SED
#
# @return int EXITCODE
function runUpdateDbModo_postfix() {
	_mdbUpd_printDebugFilename "$3"
	[ ! -f "$3" ] && {
		echo "$VAR_MYNAME:     file '$3' not found. ignoring."
		return 0
	}
	sed -i \
			-e "s/^user = .*$/user = $1/g" \
			-e "s/^password = .*$/password = $2/g" \
			-e "s/^dbname = .*$/dbname = $1/g" \
			-e "s/^hosts = .*$/hosts = $LVAR_ARG_MARIADB_DOCKERHOST/g" \
			"$3"
}

# @param string $1 DB_NAME_AND_USER
# @param string $2 DB_PASS
#
# @return int EXITCODE
function runUpdateDbModo() {
	local TMP_LAST_U="$SETTS_CACHE_DB_MODO_USER"
	local TMP_LAST_P="$SETTS_CACHE_DB_MODO_PASS"

	if [ "$SETTS_CACHE_MARIADB_DOCKERHOST" != "$LVAR_ARG_MARIADB_DOCKERHOST" ]; then
		echo "$VAR_MYNAME: Updating DB-Modoboa hostname"
		if [ "$CF_DEBUG_MDB_SCRIPTS" = "true" ]; then
			echo "$VAR_MYNAME:   last MARIADB_DOCKERHOST='$SETTS_CACHE_MARIADB_DOCKERHOST'"
			echo "$VAR_MYNAME:   cur  MARIADB_DOCKERHOST='$LVAR_ARG_MARIADB_DOCKERHOST'"
		fi
	fi
	if [ "$TMP_LAST_U" != "$1" -o "$TMP_LAST_P" != "$2" ]; then
		echo "$VAR_MYNAME: Updating DB-Modoboa user credentials"
		if [ "$CF_DEBUG_MDB_SCRIPTS" = "true" ]; then
			echo "$VAR_MYNAME:   last DBNAME/USER='$TMP_LAST_U'"
			echo "$VAR_MYNAME:   new  DBNAME/USER='$1'"
			echo "$VAR_MYNAME:   last DBPASS     ='$TMP_LAST_P'"
			echo "$VAR_MYNAME:   new  DBPASS     ='$2'"
		fi
	fi

	# Modoboa Settings: "DATABASES"
	_mdbUpd_printDebugFilename "$LVAR_MODO_SETTS_PY"
	sed -i \
			-e "s/'NAME': '$TMP_LAST_U',/'NAME': '$1',/g" \
			-e "s/'USER': '$TMP_LAST_U',/'USER': '$1',/g" \
			-e "s/'PASSWORD': '$TMP_LAST_P',/'PASSWORD': '$2',/g" \
			-e "s/'HOST': '$SETTS_CACHE_MARIADB_DOCKERHOST',/'HOST': '$LVAR_ARG_MARIADB_DOCKERHOST',/g" \
			"$LVAR_MODO_SETTS_PY"

	#
	_mdbUpd_printDebugFilename "/usr/local/bin/postlogin.sh"
	sed -i \
			-e "s/^DBNAME=.* DBUSER=.* DBPASSWORD=.*/DBNAME=\"$1\" DBUSER=\"$1\" DBPASSWORD=\"$2\" DBHOST=\"$LVAR_ARG_MARIADB_DOCKERHOST\"/g" \
			-e "s/mysql -u \$DBUSER -p\$DBPASSWORD \$DBNAME/mysql -h \"\$DBHOST\" -u \"\$DBUSER\" --password=\"\$DBPASSWORD\" \"\$DBNAME\"/g" \
			-e "s/mysql -h \"\$DBHOST\" -u \"\$DBUSER\" --password=\"\$DBPASSWORD\" \"\$DBNAME\"/mysql -h \"\$DBHOST\" -u \"\$DBUSER\" --password=\"\$DBPASSWORD\" \"\$DBNAME\"/g" \
			/usr/local/bin/postlogin.sh

	#
	_mdbUpd_printDebugFilename "/etc/automx.conf"
	sed -i \
			-e "s/^host = mysql.*$/host = mysql:\/\/$1:$2@$LVAR_ARG_MARIADB_DOCKERHOST\/$1/g" \
			/etc/automx.conf

	#
	_mdbUpd_printDebugFilename "/etc/dovecot/dovecot-sql.conf.ext"
	_mdbUpd_printDebugFilename "/etc/dovecot/dovecot-sql-master.conf.ext"
	_mdbUpd_printDebugFilename "/etc/dovecot/dovecot-dict-sql.conf.ext"
	sed -i \
			-e "s/^connect = host=.*$/connect = host=$LVAR_ARG_MARIADB_DOCKERHOST dbname=$1 user=$1 password=$2/g" \
			/etc/dovecot/dovecot-sql.conf.ext \
			/etc/dovecot/dovecot-sql-master.conf.ext \
			/etc/dovecot/dovecot-dict-sql.conf.ext

	#
	runUpdateDbModo_postfix "$1" "$2" "/etc/postfix/sql-aliases.cf" || return 1
	runUpdateDbModo_postfix "$1" "$2" "/etc/postfix/sql-domains.cf" || return 1
	runUpdateDbModo_postfix "$1" "$2" "/etc/postfix/sql-domain-aliases.cf" || return 1
	runUpdateDbModo_postfix "$1" "$2" "/etc/postfix/sql-spliteddomains-transport.cf" || return 1
	runUpdateDbModo_postfix "$1" "$2" "/etc/postfix/sql-maintain.cf" || return 1
	runUpdateDbModo_postfix "$1" "$2" "/etc/postfix/sql-relay-recipient-verification.cf" || return 1
	runUpdateDbModo_postfix "$1" "$2" "/etc/postfix/sql-relaydomains.cf" || return 1
	runUpdateDbModo_postfix "$1" "$2" "/etc/postfix/sql-transport.cf" || return 1
	runUpdateDbModo_postfix "$1" "$2" "/etc/postfix/sql-sender-login-map.cf" || return 1

	#
	if [ "$TMP_LAST_U" != "$1" -o "$TMP_LAST_P" != "$2" ]; then
		command -v opendkim >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			_mdbUpd_printDebugOther "dkim DB-View"
			_mdbUpd_db_checkDbConnection "$1" "$2" || {
				echo "$VAR_MYNAME: Error: Can't connect to DB '$1@$LVAR_ARG_MARIADB_DOCKERHOST'. Aborting." > /dev/stderr
				return 1
			}
			_mdbUpd_db_updateModoDkimView "$1" "$2" || return 1
		fi
	fi

	return 0
}

# @param string $1 DB_NAME_AND_USER
# @param string $2 DB_PASS
#
# @return int EXITCODE
function runUpdateDbAmav() {
	local TMP_LAST_U="$SETTS_CACHE_DB_AMAV_USER"
	local TMP_LAST_P="$SETTS_CACHE_DB_AMAV_PASS"

	if [ "$SETTS_CACHE_MARIADB_DOCKERHOST" != "$LVAR_ARG_MARIADB_DOCKERHOST" ]; then
		echo "$VAR_MYNAME: Updating DB-Amavis hostname"
		if [ "$CF_DEBUG_MDB_SCRIPTS" = "true" ]; then
			echo "$VAR_MYNAME:   last MARIADB_DOCKERHOST='$SETTS_CACHE_MARIADB_DOCKERHOST'"
			echo "$VAR_MYNAME:   cur  MARIADB_DOCKERHOST='$LVAR_ARG_MARIADB_DOCKERHOST'"
		fi
	fi
	if [ "$TMP_LAST_U" != "$1" -o "$TMP_LAST_P" != "$2" ]; then
		echo "$VAR_MYNAME: Updating DB-Amavis user credentials"
		if [ "$CF_DEBUG_MDB_SCRIPTS" = "true" ]; then
			echo "$VAR_MYNAME:   last DBNAME/USER='$TMP_LAST_U'"
			echo "$VAR_MYNAME:   new  DBNAME/USER='$1'"
			echo "$VAR_MYNAME:   last DBPASS     ='$TMP_LAST_P'"
			echo "$VAR_MYNAME:   new  DBPASS     ='$2'"
		fi
	fi

	# Modoboa Settings: "DATABASES"
	_mdbUpd_printDebugFilename "$LVAR_MODO_SETTS_PY"
	sed -i \
			-e "s/'NAME': '$TMP_LAST_U',/'NAME': '$1',/g" \
			-e "s/'USER': '$TMP_LAST_U',/'USER': '$1',/g" \
			-e "s/'PASSWORD': '$TMP_LAST_P',/'PASSWORD': '$2',/g" \
			-e "s/'HOST': '$SETTS_CACHE_MARIADB_DOCKERHOST',/'HOST': '$LVAR_ARG_MARIADB_DOCKERHOST',/g" \
			"$LVAR_MODO_SETTS_PY"

	#
	_mdbUpd_printDebugFilename "/etc/amavis/conf.d/50-user"
	sed -i \
			-e "s/^\@lookup_sql_dsn = .*;$/@lookup_sql_dsn = ( [ 'DBI:mysql:database=$1;host=$LVAR_ARG_MARIADB_DOCKERHOST', '$1', '$2' ]);/g" \
			/etc/amavis/conf.d/50-user
}

# @param string $1 DB_NAME_AND_USER
# @param string $2 DB_PASS
#
# @return int EXITCODE
function runUpdateDbSpam() {
	local TMP_LAST_U="$SETTS_CACHE_DB_SPAM_USER"
	local TMP_LAST_P="$SETTS_CACHE_DB_SPAM_PASS"

	if [ "$SETTS_CACHE_MARIADB_DOCKERHOST" != "$LVAR_ARG_MARIADB_DOCKERHOST" ]; then
		echo "$VAR_MYNAME: Updating DB-Spamassassin hostname"
		if [ "$CF_DEBUG_MDB_SCRIPTS" = "true" ]; then
			echo "$VAR_MYNAME:   last MARIADB_DOCKERHOST='$SETTS_CACHE_MARIADB_DOCKERHOST'"
			echo "$VAR_MYNAME:   cur  MARIADB_DOCKERHOST='$LVAR_ARG_MARIADB_DOCKERHOST'"
		fi
	fi
	if [ "$TMP_LAST_U" != "$1" -o "$TMP_LAST_P" != "$2" ]; then
		echo "$VAR_MYNAME: Updating DB-Spamassassin user credentials"
		if [ "$CF_DEBUG_MDB_SCRIPTS" = "true" ]; then
			echo "$VAR_MYNAME:   last DBNAME/USER='$TMP_LAST_U'"
			echo "$VAR_MYNAME:   new  DBNAME/USER='$1'"
			echo "$VAR_MYNAME:   last DBPASS     ='$TMP_LAST_P'"
			echo "$VAR_MYNAME:   new  DBPASS     ='$2'"
		fi
	fi

	#
	_mdbUpd_printDebugFilename "/etc/spamassassin/local.cf"
	sed -i \
			-e "s/^bayes_sql_dsn .*$/bayes_sql_dsn         DBI:mysql:$1:$LVAR_ARG_MARIADB_DOCKERHOST/g" \
			-e "s/^bayes_sql_username .*$/bayes_sql_username    $1/g" \
			-e "s/^bayes_sql_password .*$/bayes_sql_password    $2/g" \
			/etc/spamassassin/local.cf
}

# @param string $1 DB_NAME_AND_USER
# @param string $2 DB_PASS
#
# @return int EXITCODE
function runUpdateDbDkim() {
	local TMP_LAST_U="$SETTS_CACHE_DB_DKIM_USER"
	local TMP_LAST_P="$SETTS_CACHE_DB_DKIM_PASS"

	if [ "$SETTS_CACHE_MARIADB_DOCKERHOST" != "$LVAR_ARG_MARIADB_DOCKERHOST" ]; then
		echo "$VAR_MYNAME: Updating DB-OpenDKIM hostname"
		if [ "$CF_DEBUG_MDB_SCRIPTS" = "true" ]; then
			echo "$VAR_MYNAME:   last MARIADB_DOCKERHOST='$SETTS_CACHE_MARIADB_DOCKERHOST'"
			echo "$VAR_MYNAME:   cur  MARIADB_DOCKERHOST='$LVAR_ARG_MARIADB_DOCKERHOST'"
		fi
	fi
	if [ "$TMP_LAST_U" != "$1" -o "$TMP_LAST_P" != "$2" ]; then
		echo "$VAR_MYNAME: Updating DB-OpenDKIM user credentials"
		if [ "$CF_DEBUG_MDB_SCRIPTS" = "true" ]; then
			echo "$VAR_MYNAME:   last DBNAME/USER='$TMP_LAST_U'"
			echo "$VAR_MYNAME:   new  DBNAME/USER='$1'"
			echo "$VAR_MYNAME:   last DBPASS     ='$TMP_LAST_P'"
			echo "$VAR_MYNAME:   new  DBPASS     ='$2'"
		fi
	fi

	#
	_mdbUpd_printDebugFilename "/etc/opendkim.conf"
	sed -i \
			-e "s/^KeyTable.*$/KeyTable dsn:mysql:\/\/$1:$2@${LVAR_ARG_MARIADB_DOCKERHOST}\/${LVAR_ARG_DB_MODO_USER}\/table=dkim?keycol=id?datacol=domain_name,selector,private_key_path/g" \
			-e "s/^SigningTable.*$/SigningTable dsn:mysql:\/\/$1:$2@${LVAR_ARG_MARIADB_DOCKERHOST}\/${LVAR_ARG_DB_MODO_USER}\/table=dkim?keycol=domain_name?datacol=id/g" \
			/etc/opendkim.conf
}

# @param string $1 NEW_HOSTNAME
# @param string $2 NEW_MAILDOMAIN
#
# @return int EXITCODE
function runUpdateMaildomain() {
	echo -e "\n$VAR_MYNAME: Updating Mail-Hostname and -Domain"

	local TMP_LASTH="$SETTS_CACHE_MAILHOSTNAME"
	local TMP_LASTD="$SETTS_CACHE_MAILDOMAIN"

	if [ "$CF_DEBUG_MDB_SCRIPTS" = "true" ]; then
		echo "$VAR_MYNAME:   last MAIL-FQDN='$TMP_LASTH.$TMP_LASTD'"
		echo "$VAR_MYNAME:   new  MAIL-FQDN='$1.$2'"
	fi

	#
	TMP_LASTH="$(echo -n "$TMP_LASTH" | sed -e 's/\./\\./g')"
	TMP_LASTD="$(echo -n "$TMP_LASTD" | sed -e 's/\./\\./g')"

	# Modoboa Settings: "ALLOWED_HOSTS"
	_mdbUpd_printDebugFilename "$LVAR_MODO_SETTS_PY"
	sed -i -e "s/'$TMP_LASTH\.$TMP_LASTD'/'$1.$2'/g" "$LVAR_MODO_SETTS_PY"

	#
	_mdbUpd_printDebugFilename "/etc/mailname"
	echo "$1.$2" > /etc/mailname

	#
	_mdbUpd_printDebugFilename "/etc/automx.conf"
	sed -i -e "s/^provider = .*$/provider = $2/g" /etc/automx.conf
	sed -i \
			-e "s/^smtp_server = .*$/smtp_server = $1.$2/g" \
			-e "s/^imap_server = .*$/imap_server = $1.$2/g" \
			-e "s/^pop_server = .*$/pop_server = $1.$2/g" \
			/etc/automx.conf

	#
	_mdbUpd_printDebugFilename "/etc/cron.d/modoboa"
	sed -i \
			-e "s/manage\.py amnotify --baseurl='http\:\/\/.*'$/manage.py amnotify --baseurl='http\:\/\/$1.$2'/g" \
			/etc/cron.d/modoboa

	# create new SSL Cert/Key
	if [ -f "$LVAR_SSL_KEYS/private-$1.$2.key" -a -f "$LVAR_SSL_CERTS/client-$1.$2.crt" ]; then
		_mdbUpd_printDebugOther "SSL Cert/Key already exist"
	else
		_mdbUpd_printDebugOther "generating new self-signed SSL Cert/Key"

		[ -f "$LVAR_SSL_KEYS/private-$1.$2.key" ] && rm "$LVAR_SSL_KEYS/private-$1.$2.key"
		[ -f "$LVAR_SSL_CERTS/client-$1.$2.crt" ] && rm "$LVAR_SSL_CERTS/client-$1.$2.crt"

		/root/sslgen.sh "$1.$2" || return 1
	fi

	[ -h "$LVAR_SSL_POSTFIX_KEY" ] && rm "$LVAR_SSL_POSTFIX_KEY"
	[ -h "$LVAR_SSL_POSTFIX_CRT" ] && rm "$LVAR_SSL_POSTFIX_CRT"
	ln -s "$LVAR_SSL_KEYS/private-$1.$2.key" "$LVAR_SSL_POSTFIX_KEY"
	ln -s "$LVAR_SSL_CERTS/client-$1.$2.crt" "$LVAR_SSL_POSTFIX_CRT"
	
	[ -h "$LVAR_SSL_DOVECOT_KEY" ] && rm "$LVAR_SSL_DOVECOT_KEY"
	[ -h "$LVAR_SSL_DOVECOT_CRT" ] && rm "$LVAR_SSL_DOVECOT_CRT"
	ln -s "$LVAR_SSL_KEYS/private-$1.$2.key" "$LVAR_SSL_DOVECOT_KEY"
	ln -s "$LVAR_SSL_CERTS/client-$1.$2.crt" "$LVAR_SSL_DOVECOT_CRT"
	
	#
	_mdbUpd_printDebugFilename "/etc/postfix/main.cf"
	sed -i \
			-e "s/^myhostname = .*$/myhostname = $1.$2/g" \
			-e "s/^smtpd_tls_key_file = .*$/smtpd_tls_key_file = $(echo -n "$LVAR_SSL_POSTFIX_KEY" | sed -e 's/\//\\\//g')/g" \
			-e "s/^smtpd_tls_cert_file = .*$/smtpd_tls_cert_file = $(echo -n "$LVAR_SSL_POSTFIX_CRT" | sed -e 's/\//\\\//g')/g" \
			/etc/postfix/main.cf

	#
	_mdbUpd_printDebugFilename "/etc/apache2/sites-available/xxx.conf"
	sed -i \
			-e "s/ServerName $TMP_LASTH\.$TMP_LASTD/ServerName $1.$2/g" \
			-e "s/ServerName autoconfig\.$TMP_LASTD/ServerName autoconfig.$2/g" \
			-e "s/\"http\:\/\/$TMP_LASTH\.$TMP_LASTD\"/\"http:\/\/$1.$2\"/g" \
			/etc/apache2/sites-available/000-common.conf \
			/etc/apache2/sites-available/050-modoboa.conf \
			/etc/apache2/sites-available/060-modoboa-automx.conf

	#
	_mdbUpd_printDebugFilename "/etc/dovecot/conf.d/10-ssl.conf"
	sed -i \
			-e "s/^ssl_key = <.*$/ssl_key = <$(echo -n "$LVAR_SSL_DOVECOT_KEY" | sed -e 's/\//\\\//g')/g" \
			-e "s/^ssl_cert = <.*$/ssl_cert = <$(echo -n "$LVAR_SSL_DOVECOT_CRT" | sed -e 's/\//\\\//g')/g" \
			/etc/dovecot/conf.d/10-ssl.conf
	_mdbUpd_printDebugFilename "/etc/dovecot/conf.d/20-lmtp.conf"
	sed -i \
			-e "s/postmaster_address = postmaster\@.*$/postmaster_address = postmaster@$2/g" \
			/etc/dovecot/conf.d/20-lmtp.conf

	#
	_mdbUpd_printDebugFilename "/etc/amavis/conf.d/05-node_id"
	sed -i \
			-e "s/^\$myhostname = \".*\";$/\$myhostname = \"$1.$2\";/g" \
			/etc/amavis/conf.d/05-node_id

	#
	_mdbUpd_printDebugFilename "/etc/aliases.db"
	newaliases

	# Modo DB Table 'core_localconfig'
	_mdbUpd_printDebugOther "Modo DB Table 'core_localconfig'"

	local TMP_JSON="$(_mdbUpd_db_readModoLocalconf "$SETTS_CACHE_DB_MODO_USER" "$SETTS_CACHE_DB_MODO_PASS")"
	local TMP_JSON_MOD=""

	TMP_JSON_MOD="$(echo "$TMP_JSON" | \
			python "$LVAR_CUSTOMIZE_MODO_LCONF_PY_SCRIPT_FN" --mailhost "$1" --maildomain "$2" inst -)"
	
	[ -z "$TMP_JSON_MOD" ] && {
		echo "$VAR_MYNAME: Error: '$LVAR_CUSTOMIZE_MODO_LCONF_PY_SCRIPT_FN' failed. Aborting." >/dev/stderr
		return 1
	}

	_mdbUpd_db_writeModoLocalconf "$SETTS_CACHE_DB_MODO_USER" "$SETTS_CACHE_DB_MODO_PASS" "$TMP_JSON_MOD"

	# Modo DB Table 'django_site'
	_mdbUpd_printDebugOther "Modo DB Table 'django_site'"
	_mdbUpd_db_writeModoDjangoSite "$SETTS_CACHE_DB_MODO_USER" "$SETTS_CACHE_DB_MODO_PASS" "$1.$2"
}

# @param string $1 NEW_HOSTNAME
# @param string $2 NEW_MAILDOMAIN
#
# @return int EXITCODE
function runUpdateDavHostname() {
	echo -e "\n$VAR_MYNAME: Updating DAV-Hostname and -Domain"

	local TMP_LASTH="$SETTS_CACHE_DAVHOSTNAME"
	local TMP_LASTD="$TMP_SETTS_CACHE_MAILDOMAIN_LAST"

	if [ "$CF_DEBUG_MDB_SCRIPTS" = "true" ]; then
		echo "$VAR_MYNAME:   last DAV-FQDN='$TMP_LASTH.$TMP_LASTD'"
		echo "$VAR_MYNAME:   new  DAV-FQDN='$1.$2'"
	fi

	#
	TMP_LASTH="$(echo -n "$TMP_LASTH" | sed -e 's/\./\\./g')"
	TMP_LASTD="$(echo -n "$TMP_LASTD" | sed -e 's/\./\\./g')"

	# create new SSL Cert/Key
	if [ -f "${LVAR_SSL_KEYS}/private-$1.$2.key" -a -f "${LVAR_SSL_CERTS}/client-$1.$2.crt" ]; then
		_mdbUpd_printDebugOther "SSL Cert/Key already exist"
	else
		_mdbUpd_printDebugOther "generating new self-signed SSL Cert/Key"
		[ -f "${LVAR_SSL_KEYS}/private-$1.$2.key" ] && rm "${LVAR_SSL_KEYS}/private-$1.$2.key"
		[ -f "${LVAR_SSL_CERTS}/client-$1.$2.crt" ] && rm "${LVAR_SSL_CERTS}/client-$1.$2.crt"

		/root/sslgen.sh "$1.$2" || return 1
	fi

	#
	_mdbUpd_printDebugFilename "/etc/hosts"
	sed \
			-e "s/127\.0\.0\.1 $TMP_LASTH\.$TMP_LASTD/127.0.0.1 $1.$2/g" \
			/etc/hosts > /tmp/xxx.tmp.${VAR_MYNAME}.$$
	cp /tmp/xxx.tmp.${VAR_MYNAME}.$$ /etc/hosts || {
		echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr
		return 1
	}
	rm /tmp/xxx.tmp.${VAR_MYNAME}.$$
	grep -q " $1.$2$" /etc/hosts || echo "127.0.0.1 $1.$2" >> /etc/hosts

	#
	_mdbUpd_printDebugFilename "/etc/apache2/sites-available/070-radicale_reverse-ssl.conf"
	sed -i \
			-e "s/ServerName $TMP_LASTH\.$TMP_LASTD/ServerName $1.$2/g" \
			-e "s/\/client-$TMP_LASTH\.$TMP_LASTD\.crt/\/client-$1.$2.crt/g" \
			-e "s/\/private-$TMP_LASTH\.$TMP_LASTD\.key/\/private-$1.$2.key/g" \
			/etc/apache2/sites-available/070-radicale_reverse-ssl.conf

	# Modo DB Table 'core_localconfig'
	_mdbUpd_printDebugOther "Modo DB Table 'core_localconfig'"

	local TMP_JSON="$(_mdbUpd_db_readModoLocalconf "$SETTS_CACHE_DB_MODO_USER" "$SETTS_CACHE_DB_MODO_PASS")"
	local TMP_JSON_MOD=""

	TMP_JSON_MOD="$(echo "$TMP_JSON" | \
			python "$LVAR_CUSTOMIZE_MODO_LCONF_PY_SCRIPT_FN" --davhost "$1" --maildomain "$2" inst -)"

	[ -z "$TMP_JSON_MOD" ] && {
		echo "$VAR_MYNAME: Error: '$LVAR_CUSTOMIZE_MODO_LCONF_PY_SCRIPT_FN' failed. Aborting." >/dev/stderr
		return 1
	}

	_mdbUpd_db_writeModoLocalconf "$SETTS_CACHE_DB_MODO_USER" "$SETTS_CACHE_DB_MODO_PASS" "$TMP_JSON_MOD"
}

# @param string $1 NEW_TIMEZONE
#
# @return int EXITCODE
function runUpdateTimezone() {
	echo -e "\n$VAR_MYNAME: Updating Timezone"

	local TMP_LAST="$SETTS_CACHE_TIMEZONE"

	if [ "$CF_DEBUG_MDB_SCRIPTS" = "true" ]; then
		echo "$VAR_MYNAME:   last TZ='$TMP_LAST'"
		echo "$VAR_MYNAME:   new  TZ='$1'"
	fi

	#
	_mdbUpd_printDebugFilename "/etc/localtime"
	if [ -f "/usr/share/zoneinfo/$1" ]; then
		rm /etc/localtime
		ln -s /usr/share/zoneinfo/$1 /etc/localtime
	else
		echo "$VAR_MYNAME: Warning: Invalid Timezone '$1'. Ignoring." >/dev/stderr
		return 0
	fi

	# Modoboa Settings: "TIMEZONE"
	_mdbUpd_printDebugFilename "$LVAR_MODO_SETTS_PY"
	sed -i \
			-e "s/^TIME_ZONE = '.*'$/TIME_ZONE = '$(echo -n "$1" | sed -e 's/\//\\\//g')'/g" \
			"$LVAR_MODO_SETTS_PY"

	return 0
}

# @param string $1 NEW_LANGUAGE
#
# @return int EXITCODE
function runUpdateLanguage() {
	echo -e "\n$VAR_MYNAME: Updating default Language"

	local TMP_LAST="$SETTS_CACHE_LANGUAGE"

	if [ "$CF_DEBUG_MDB_SCRIPTS" = "true" ]; then
		echo "$VAR_MYNAME:   last LANG='$TMP_LAST'"
		echo "$VAR_MYNAME:   new  LANG='$1'"
	fi

	# Modoboa Settings: "LANGUAGE_CODE"
	_mdbUpd_printDebugFilename "$LVAR_MODO_SETTS_PY"
	sed -i \
			-e "s/^LANGUAGE_CODE = '.*'$/LANGUAGE_CODE = '$1'/g" \
			"$LVAR_MODO_SETTS_PY"

	# Modo DB Table 'core_user'
	_mdbUpd_printDebugOther "Admin User in Modo DB Table 'core_user'"
	_mdbUpd_db_writeModoAdminLang "$SETTS_CACHE_DB_MODO_USER" "$SETTS_CACHE_DB_MODO_PASS" "$1"

	return 0
}

# @param string $1 NEW_HOSTNAME
#
# @return int EXITCODE
function runUpdateMariadbDockerhost() {
	echo -e "\n$VAR_MYNAME: Updating MariaDB Dockerhost"
	if [ "$CF_DEBUG_MDB_SCRIPTS" = "true" ]; then
		echo "$VAR_MYNAME:   last MARIADB_DOCKERHOST='$SETTS_CACHE_MARIADB_DOCKERHOST'"
		echo "$VAR_MYNAME:   new  MARIADB_DOCKERHOST='$1'"
	fi

	local TMP_USER="$SETTS_CACHE_DB_MODO_USER"
	local TMP_PASS="$SETTS_CACHE_DB_MODO_PASS"
	[ -z "$TMP_USER" ] && TMP_USER="$LVAR_ARG_DB_MODO_USER"
	[ -z "$TMP_PASS" ] && TMP_PASS="$LVAR_ARG_DB_MODO_PASS"

	runUpdateDbModo "$TMP_USER" "$TMP_PASS" || {
		echo "$VAR_MYNAME: Error: runUpdateDbModo() failed. Aborting." > /dev/stderr
		return 1
	}

	TMP_USER="$SETTS_CACHE_DB_AMAV_USER"
	TMP_PASS="$SETTS_CACHE_DB_AMAV_PASS"
	[ -z "$TMP_USER" ] && TMP_USER="$LVAR_ARG_DB_AMAV_USER"
	[ -z "$TMP_PASS" ] && TMP_PASS="$LVAR_ARG_DB_AMAV_PASS"

	runUpdateDbAmav "$TMP_USER" "$TMP_PASS" || {
		echo "$VAR_MYNAME: Error: runUpdateDbAmav() failed. Aborting." > /dev/stderr
		return 1
	}

	TMP_USER="$SETTS_CACHE_DB_SPAM_USER"
	TMP_PASS="$SETTS_CACHE_DB_SPAM_PASS"
	[ -z "$TMP_USER" ] && TMP_USER="$LVAR_ARG_DB_SPAM_USER"
	[ -z "$TMP_PASS" ] && TMP_PASS="$LVAR_ARG_DB_SPAM_PASS"

	runUpdateDbSpam "$TMP_USER" "$TMP_PASS" || {
		echo "$VAR_MYNAME: Error: runUpdateDbSpam() failed. Aborting." > /dev/stderr
		return 1
	}

	TMP_USER="$SETTS_CACHE_DB_DKIM_USER"
	TMP_PASS="$SETTS_CACHE_DB_DKIM_PASS"
	[ -z "$TMP_USER" ] && TMP_USER="$LVAR_ARG_DB_DKIM_USER"
	[ -z "$TMP_PASS" ] && TMP_PASS="$LVAR_ARG_DB_DKIM_PASS"

	runUpdateDbDkim "$TMP_USER" "$TMP_PASS" || {
		echo "$VAR_MYNAME: Error: runUpdateDbDkim() failed. Aborting." > /dev/stderr
		return 1
	}

	return 0
}

# @param string $1 HOSTNAME
# @param string $2 DOMAIN
#
# @return int EXITCODE 0=Cert is self-signed, 1=Cert does not exist, 2=Cert is not self-signed
function runUpdateCaldavSslVerification_isSelfSigned() {
	local TMP_FN_C="/etc/ssl/host-certs/client-${1}.${2}.crt"
	if [ ! -f "$TMP_FN_C" ]; then
		echo "$VAR_MYNAME: Error: The file '$TMP_FN_C' does not exist. Aborting." >/dev/stderr
		return 1
	fi

	local TMP_ISSUER_SUBJECT="$(openssl x509 -noout -text -in "$TMP_FN_C" | grep -e "^ *Issuer: " -e "^ *Subject: " | cut -f2- -d:)"
	local TMP_ISSUER="$(echo "$TMP_ISSUER_SUBJECT" | head -n1)"
	local TMP_SUBJECT="$(echo "$TMP_ISSUER_SUBJECT" | tail -n +2)"
	[ "$TMP_ISSUER" = "$TMP_SUBJECT" ] && return 0
	return 2
}

# @return int EXITCODE
function runUpdateCaldavSslVerification() {
	local TMP_FN="/srv/modoboa/env/lib/python2.7/site-packages/modoboa_radicale/backends/caldav_.py"

	if [ ! -f "$TMP_FN" ]; then
		echo "$VAR_MYNAME: Error: The file '$TMP_FN' does not exist. Aborting." >/dev/stderr
		return 1
	fi

	local TMP_DOES_VERIFY=false
	grep -q -e "username=username, password=password, ssl_verify_cert=True)" "$TMP_FN"
	[ $? -eq 0 ] && TMP_DOES_VERIFY=true

	if [ "$TMP_DOES_VERIFY" != "true" ]; then
		# check if patch has been applied
		grep -q -e "username=username, password=password, ssl_verify_cert=" "$TMP_FN"
		if [ $? -ne 0 ]; then
			echo "$VAR_MYNAME: Error: The file '$TMP_FN' has not been patched. Aborting." >/dev/stderr
			return 1
		fi
	fi

	#
	runUpdateCaldavSslVerification_isSelfSigned "$SETTS_CACHE_DAVHOSTNAME" "$SETTS_CACHE_MAILDOMAIN"
	local TMP_RES=$?
	if [ $TMP_RES -eq 1 ]; then
		return 1
	fi
	if [ $TMP_RES -eq 0 -a "$TMP_DOES_VERIFY" = "true" ]; then
		echo -e "\n$VAR_MYNAME: Disabling SSL-Verification in Python CalDAV Library because of self-signed SSL-Certificate"
		echo "$VAR_MYNAME:   (otherwise accessing calendars/contacts from Modoboa's webinterface would not work)"
		_mdbUpd_printDebugFilename "$TMP_FN"
		sed -i \
				-e "s/username=username, password=password, ssl_verify_cert=True)/username=username, password=password, ssl_verify_cert=False)/g" \
				"$TMP_FN"
	elif [ $TMP_RES -eq 2 -a "$TMP_DOES_VERIFY" = "false" ]; then
		echo -e "\n$VAR_MYNAME: Enabling SSL-Verification in Python CalDAV Library because of CA-signed SSL-Certificate"
		_mdbUpd_printDebugFilename "$TMP_FN"
		sed -i \
				-e "s/username=username, password=password, ssl_verify_cert=False)/username=username, password=password, ssl_verify_cert=True)/g" \
				"$TMP_FN"
	elif [ "$CF_DEBUG_MDB_SCRIPTS" = "true" ]; then
		echo -ne "\n$VAR_MYNAME: Not changing SSL-Verification in Python CalDAV Library (is "
		[ "$TMP_DOES_VERIFY" = "false" ] && echo -n "disabled" || echo -n "enabled"
		echo ")"
	fi
	return 0
}

# -----------------------------------------------------------------
# Get arguments

if [ $# -eq 1 -a "$1" = "--help" ]; then
	showUsage
fi

LVAR_ARG_DJANGO_SECRETKEY=""

LVAR_ARG_ENABLE_MODOBOA_CSRF="$CF_MODOBOA_CSRF_PROTECTION_ENABLE"
[ "$LVAR_ARG_ENABLE_MODOBOA_CSRF" != "true" ] && LVAR_ARG_ENABLE_MODOBOA_CSRF=false
LVAR_ARG_MARIADB_DOCKERHOST="$CF_MARIADB_DOCKERHOST"
LVAR_ARG_DAVHOSTNAME="$CF_DAVHOSTNAME"
LVAR_ARG_MAILHOSTNAME="$CF_MAILHOSTNAME"
LVAR_ARG_MAILDOMAIN="$CF_MAILDOMAIN"
LVAR_ARG_TIMEZONE="$CF_TIMEZONE"
LVAR_ARG_LANGUAGE="$CF_LANGUAGE"
LVAR_ARG_DB_MODO_USER="$CF_MODOBOA_CONF_DBNAME_AND_DBUSER"
LVAR_ARG_DB_MODO_PASS="$CF_MODOBOA_CONF_DBPASS"
LVAR_ARG_DB_AMAV_USER="$CF_AMAVIS_CONF_DBNAME_AND_DBUSER"
LVAR_ARG_DB_AMAV_PASS="$CF_AMAVIS_CONF_DBPASS"
LVAR_ARG_DB_SPAM_USER="$CF_SPAMASSASS_CONF_DBNAME_AND_DBUSER"
LVAR_ARG_DB_SPAM_PASS="$CF_SPAMASSASS_CONF_DBPASS"
LVAR_ARG_OPENDKIM_CONF_ENABLE="$CF_OPENDKIM_CONF_ENABLE"
[ "$LVAR_ARG_OPENDKIM_CONF_ENABLE" != "true" ] && LVAR_ARG_OPENDKIM_CONF_ENABLE=false
LVAR_ARG_DB_DKIM_USER="$CF_OPENDKIM_CONF_DBNAME_AND_DBUSER"
LVAR_ARG_DB_DKIM_PASS="$CF_OPENDKIM_CONF_DBPASS"
LVAR_ARG_CLAMAV_CONF_ENABLE="$CF_CLAMAV_CONF_ENABLE"
[ "$LVAR_ARG_CLAMAV_CONF_ENABLE" != "true" ] && LVAR_ARG_CLAMAV_CONF_ENABLE=false

while [ $# -gt 0 ]; do
	curOpt="$1"
	curOptArg=""
	#echo "- curOpt= '$curOpt'"
	shift
	#
	if ( [ "$curOpt" = "--django-secretkey" ] || \
			[ "x" = "y" ] ); then
		if [ $# -eq 0 ]; then
			echo "$VAR_MYNAME: Argument missing for '$curOpt'. Aborting." >/dev/stderr
			echo "Help: $VAR_MYNAME --help" >/dev/stderr
			exit 1
		else
			curOptArg="$(echo -n "$1" | sed -e "s/'/\\'/g")"
			#echo "- curOptArg= '$curOptArg'"
			shift
		fi
	else
		echo "$VAR_MYNAME: Invalid parameter '$curOpt'. Aborting." >/dev/stderr
		echo "Help: $VAR_MYNAME --help" >/dev/stderr
		exit 1
	fi
	#
	if [ "$curOpt" = "--django-secretkey" ]; then
		LVAR_ARG_DJANGO_SECRETKEY="$curOptArg"
	fi
done

if [ -z "$LVAR_ARG_MARIADB_DOCKERHOST" ]; then
	echo "$VAR_MYNAME: Error: LVAR_ARG_MARIADB_DOCKERHOST may not be empty. Aborting." > /dev/stderr
	exit 1
fi
if [ -z "$SETTS_CACHE_MARIADB_DOCKERHOST" ]; then
	echo "$VAR_MYNAME: Error: SETTS_CACHE_MARIADB_DOCKERHOST may not be empty. Aborting." > /dev/stderr
	exit 1
fi

# -----------------------------------------------------------------
# Update settings

if [ -n "$LVAR_ARG_DJANGO_SECRETKEY" ]; then
	[ ${#LVAR_ARG_DJANGO_SECRETKEY} -lt 16 -o ${#LVAR_ARG_DJANGO_SECRETKEY} -gt 64 ] && {
		echo "$VAR_MYNAME: Error: Django-SECRET_KEY must be between 16 and 64 chars long. Aborting." > /dev/stderr
		exit 1
	}
	runUpdateDjangoSecretkey "$LVAR_ARG_DJANGO_SECRETKEY" || {
		echo "$VAR_MYNAME: Error: runUpdateDjangoSecretkey() failed. Aborting." > /dev/stderr
		exit 1
	}
	SETTS_CACHE_DJANGO_SECRET_CHANGED=true
else
	if [ -n "$LVAR_ARG_ENABLE_MODOBOA_CSRF" ]; then
		# overwrite cached value here
		SETTS_CACHE_ENABLE_MODOBOA_CSRF=false
		grep -q "^CSRF_COOKIE_SECURE = True" "$LVAR_MODO_SETTS_PY"
		TMP_BOOL_VAL1=$?
		grep -q "^SESSION_COOKIE_SECURE = True" "$LVAR_MODO_SETTS_PY"
		TMP_BOOL_VAL2=$?
		[ $TMP_BOOL_VAL1 -eq 0 -a $TMP_BOOL_VAL2 -eq 0 ] && SETTS_CACHE_ENABLE_MODOBOA_CSRF=true
		#
		if [ "$LVAR_ARG_ENABLE_MODOBOA_CSRF" != "$SETTS_CACHE_ENABLE_MODOBOA_CSRF" -o \
				$TMP_BOOL_VAL1 -ne $TMP_BOOL_VAL2 ]; then
			runUpdateModoCsrf "$LVAR_ARG_ENABLE_MODOBOA_CSRF" || {
				echo "$VAR_MYNAME: Error: runUpdateModoCsrf() failed. Aborting." > /dev/stderr
				exit 1
			}
		fi
		SETTS_CACHE_ENABLE_MODOBOA_CSRF="$LVAR_ARG_ENABLE_MODOBOA_CSRF"
	fi

	if [ -n "$LVAR_ARG_MARIADB_DOCKERHOST" ]; then
		if [ "$LVAR_ARG_MARIADB_DOCKERHOST" != "$SETTS_CACHE_MARIADB_DOCKERHOST" ]; then
			runUpdateMariadbDockerhost "$LVAR_ARG_MARIADB_DOCKERHOST" || {
				echo "$VAR_MYNAME: Error: runUpdateMariadbDockerhost() failed. Aborting." > /dev/stderr
				exit 1
			}
		fi
		SETTS_CACHE_MARIADB_DOCKERHOST="$LVAR_ARG_MARIADB_DOCKERHOST"
	fi

	if ( [ -n "$LVAR_ARG_DB_MODO_USER" ] && [ -n "$LVAR_ARG_DB_MODO_PASS" ] ); then
		if [ "$LVAR_ARG_DB_MODO_USER" != "$SETTS_CACHE_DB_MODO_USER" -o \
				"$LVAR_ARG_DB_MODO_PASS" != "$SETTS_CACHE_DB_MODO_PASS" ]; then
			runUpdateDbModo "$LVAR_ARG_DB_MODO_USER" "$LVAR_ARG_DB_MODO_PASS" || {
				echo "$VAR_MYNAME: Error: runUpdateDbModo() failed. Aborting." > /dev/stderr
				exit 1
			}
		fi
		SETTS_CACHE_DB_MODO_USER="$LVAR_ARG_DB_MODO_USER"
		SETTS_CACHE_DB_MODO_PASS="$LVAR_ARG_DB_MODO_PASS"
	fi

	if ( [ -n "$LVAR_ARG_DB_AMAV_USER" ] && [ -n "$LVAR_ARG_DB_AMAV_PASS" ] ); then
		if [ "$LVAR_ARG_DB_AMAV_USER" != "$SETTS_CACHE_DB_AMAV_USER" -o \
				"$LVAR_ARG_DB_AMAV_PASS" != "$SETTS_CACHE_DB_AMAV_PASS" ]; then
			runUpdateDbAmav "$LVAR_ARG_DB_AMAV_USER" "$LVAR_ARG_DB_AMAV_PASS" || {
				echo "$VAR_MYNAME: Error: runUpdateDbAmav() failed. Aborting." > /dev/stderr
				exit 1
			}
		fi
		SETTS_CACHE_DB_AMAV_USER="$LVAR_ARG_DB_AMAV_USER"
		SETTS_CACHE_DB_AMAV_PASS="$LVAR_ARG_DB_AMAV_PASS"
	fi

	if ( [ -n "$LVAR_ARG_DB_SPAM_USER" ] && [ -n "$LVAR_ARG_DB_SPAM_PASS" ] ); then
		if [ "$LVAR_ARG_DB_SPAM_USER" != "$SETTS_CACHE_DB_SPAM_USER" -o \
				"$LVAR_ARG_DB_SPAM_PASS" != "$SETTS_CACHE_DB_SPAM_PASS" ]; then
			runUpdateDbSpam "$LVAR_ARG_DB_SPAM_USER" "$LVAR_ARG_DB_SPAM_PASS" || {
				echo "$VAR_MYNAME: Error: runUpdateDbSpam() failed. Aborting." > /dev/stderr
				exit 1
			}
		fi
		SETTS_CACHE_DB_SPAM_USER="$LVAR_ARG_DB_SPAM_USER"
		SETTS_CACHE_DB_SPAM_PASS="$LVAR_ARG_DB_SPAM_PASS"
	fi

	if ( [ -n "$LVAR_ARG_DB_DKIM_USER" ] && [ -n "$LVAR_ARG_DB_DKIM_PASS" ] ); then
		if [ "$LVAR_ARG_DB_DKIM_USER" != "$SETTS_CACHE_DB_DKIM_USER" -o \
				"$LVAR_ARG_DB_DKIM_PASS" != "$SETTS_CACHE_DB_DKIM_PASS" ]; then
			runUpdateDbDkim "$LVAR_ARG_DB_DKIM_USER" "$LVAR_ARG_DB_DKIM_PASS" || {
				echo "$VAR_MYNAME: Error: runUpdateDbSpam() failed. Aborting." > /dev/stderr
				exit 1
			}
		fi
		SETTS_CACHE_DB_DKIM_USER="$LVAR_ARG_DB_DKIM_USER"
		SETTS_CACHE_DB_DKIM_PASS="$LVAR_ARG_DB_DKIM_PASS"
	fi

	if [ -n "$LVAR_ARG_OPENDKIM_CONF_ENABLE" ]; then
		# overwrite cached value here
		SETTS_CACHE_OPENDKIM_CONF_ENABLE=false
		grep -q "^\*.*opendkim.*manage_dkim_keys$" "/etc/cron.d/modoboa"
		TMP_BOOL_VAL1=$?
		command -v opendkim >/dev/null 2>&1
		TMP_BOOL_VAL2=$?
		[ $TMP_BOOL_VAL1 -eq 0 -a $TMP_BOOL_VAL2 -eq 0 ] && SETTS_CACHE_OPENDKIM_CONF_ENABLE=true
		#
		[ "$LVAR_ARG_OPENDKIM_CONF_ENABLE" = "true" -a $TMP_BOOL_VAL2 -ne 0 ] && LVAR_ARG_OPENDKIM_CONF_ENABLE=false
		#
		if [ "$LVAR_ARG_OPENDKIM_CONF_ENABLE" != "$SETTS_CACHE_OPENDKIM_CONF_ENABLE" ]; then
			runUpdateOpenDkimEnabled "$LVAR_ARG_OPENDKIM_CONF_ENABLE" || {
				echo "$VAR_MYNAME: Error: runUpdateOpenDkimEnabled() failed. Aborting." > /dev/stderr
				exit 1
			}
		fi
		SETTS_CACHE_OPENDKIM_CONF_ENABLE="$LVAR_ARG_OPENDKIM_CONF_ENABLE"
	fi

	if [ -n "$LVAR_ARG_CLAMAV_CONF_ENABLE" ]; then
		# overwrite cached value here
		SETTS_CACHE_CLAMAV_CONF_ENABLE=false
		grep -q "^\@bypass_virus_checks_maps =" "/etc/amavis/conf.d/15-content_filter_mode"
		TMP_BOOL_VAL1=$?
		command -v freshclam >/dev/null 2>&1
		TMP_BOOL_VAL2=$?
		[ $TMP_BOOL_VAL1 -eq 0 -a $TMP_BOOL_VAL2 -eq 0 ] && SETTS_CACHE_CLAMAV_CONF_ENABLE=true
		#
		[ "$LVAR_ARG_CLAMAV_CONF_ENABLE" = "true" -a $TMP_BOOL_VAL2 -ne 0 ] && LVAR_ARG_CLAMAV_CONF_ENABLE=false
		#
		if [ "$LVAR_ARG_CLAMAV_CONF_ENABLE" != "$SETTS_CACHE_CLAMAV_CONF_ENABLE" ]; then
			runUpdateClamAvEnabled "$LVAR_ARG_CLAMAV_CONF_ENABLE" || {
				echo "$VAR_MYNAME: Error: runUpdateClamAvEnabled() failed. Aborting." > /dev/stderr
				exit 1
			}
		fi
		SETTS_CACHE_CLAMAV_CONF_ENABLE="$LVAR_ARG_CLAMAV_CONF_ENABLE"
	fi

	if [ -n "$LVAR_ARG_TIMEZONE" ]; then
		if [ "$LVAR_ARG_TIMEZONE" != "$SETTS_CACHE_TIMEZONE" ]; then
			runUpdateTimezone "$LVAR_ARG_TIMEZONE" || {
				echo "$VAR_MYNAME: Error: runUpdateTimezone() failed. Aborting." > /dev/stderr
				exit 1
			}
		fi
		SETTS_CACHE_TIMEZONE="$LVAR_ARG_TIMEZONE"
	fi

	if [ -n "$LVAR_ARG_LANGUAGE" ]; then
		if [ "$LVAR_ARG_LANGUAGE" != "$SETTS_CACHE_LANGUAGE" ]; then
			TMP_USER="$SETTS_CACHE_DB_MODO_USER"
			TMP_PASS="$SETTS_CACHE_DB_MODO_PASS"
			[ -z "$TMP_USER" ] && TMP_USER="$LVAR_ARG_DB_MODO_USER"
			[ -z "$TMP_PASS" ] && TMP_PASS="$LVAR_ARG_DB_MODO_PASS"

			[ -z "$TMP_USER" -o -z "$TMP_PASS" ] && {
				echo "$VAR_MYNAME: Error: CF_MODOBOA_CONF_DBNAME_AND_DBUSER or CF_MODOBOA_CONF_DBPASS not set. Aborting." > /dev/stderr
				exit 1
			}
			_mdbUpd_db_checkDbConnection "$TMP_USER" "$TMP_PASS" || {
				echo "$VAR_MYNAME: Error: Can't connect to DB '$TMP_USER@$LVAR_ARG_MARIADB_DOCKERHOST'. Aborting." > /dev/stderr
				exit 1
			}

			runUpdateLanguage "$LVAR_ARG_LANGUAGE" || {
				echo "$VAR_MYNAME: Error: runUpdateLanguage() failed. Aborting." > /dev/stderr
				exit 1
			}
		fi
		SETTS_CACHE_LANGUAGE="$LVAR_ARG_LANGUAGE"
	fi

	TMP_HAS_MAILDOMAIN_CHANGED=false
	[ "$LVAR_ARG_MAILDOMAIN" != "$SETTS_CACHE_MAILDOMAIN" ] && TMP_HAS_MAILDOMAIN_CHANGED=true

	TMP_SETTS_CACHE_MAILDOMAIN_LAST="$SETTS_CACHE_MAILDOMAIN"

	[ -n "$LVAR_ARG_MAILHOSTNAME" -a -n "$LVAR_ARG_DAVHOSTNAME" -a \
			"$LVAR_ARG_MAILHOSTNAME" = "$LVAR_ARG__DAVHOSTNAME" ] && {
		echo "$VAR_MYNAME: Error: DAV-Hostname must differ from Mail-Hostname. Aborting." > /dev/stderr
		exit 1
	}

	if ( [ -n "$LVAR_ARG_MAILHOSTNAME" ] && [ -n "$LVAR_ARG_MAILDOMAIN" ] ); then
		if [ "$LVAR_ARG_MAILHOSTNAME" != "$SETTS_CACHE_MAILHOSTNAME" -o \
				"$TMP_HAS_MAILDOMAIN_CHANGED" = "true" ]; then
			#[ $(( ${#LVAR_ARG_MAILHOSTNAME} + ${#LVAR_ARG_MAILDOMAIN} )) -gt 64 ] && {
			#	# OpenSSL allows max. 64 chars for CN in keys/certs
			#	echo "$VAR_MYNAME: Error: Mail-FQDN may not be longer than 64 chars. Aborting." > /dev/stderr
			#	exit 1
			#}
			[ $(( ${#LVAR_ARG_MAILHOSTNAME} + ${#LVAR_ARG_MAILDOMAIN} )) -gt 50 ] && {
				# DB-Table modoboa.django_site allows max. 50 chars for field 'name'
				echo "$VAR_MYNAME: Error: Mail-FQDN may not be longer than 50 chars. Aborting." > /dev/stderr
				exit 1
			}

			TMP_USER="$SETTS_CACHE_DB_MODO_USER"
			TMP_PASS="$SETTS_CACHE_DB_MODO_PASS"
			[ -z "$TMP_USER" ] && TMP_USER="$LVAR_ARG_DB_MODO_USER"
			[ -z "$TMP_PASS" ] && TMP_PASS="$LVAR_ARG_DB_MODO_PASS"

			[ -z "$TMP_USER" -o -z "$TMP_PASS" ] && {
				echo "$VAR_MYNAME: Error: CF_MODOBOA_CONF_DBNAME_AND_DBUSER or CF_MODOBOA_CONF_DBPASS not set. Aborting." > /dev/stderr
				exit 1
			}
			_mdbUpd_db_checkDbConnection "$TMP_USER" "$TMP_PASS" || {
				echo "$VAR_MYNAME: Error: Can't connect to DB '$TMP_USER@$LVAR_ARG_MARIADB_DOCKERHOST'. Aborting." > /dev/stderr
				exit 1
			}

			runUpdateMaildomain "$LVAR_ARG_MAILHOSTNAME" "$LVAR_ARG_MAILDOMAIN" || {
				echo "$VAR_MYNAME: Error: runUpdateMaildomain() failed. Aborting." > /dev/stderr
				exit 1
			}
		fi
		SETTS_CACHE_MAILHOSTNAME="$LVAR_ARG_MAILHOSTNAME"
		SETTS_CACHE_MAILDOMAIN="$LVAR_ARG_MAILDOMAIN"
	fi

	if ( [ -n "$LVAR_ARG_DAVHOSTNAME" ] && [ -n "$SETTS_CACHE_MAILDOMAIN" ] ); then
		if [ "$LVAR_ARG_DAVHOSTNAME" != "$SETTS_CACHE_DAVHOSTNAME" -o \
				"$TMP_HAS_MAILDOMAIN_CHANGED" = "true" ]; then
			#[ $(( ${#LVAR_ARG_DAVHOSTNAME} + ${#SETTS_CACHE_MAILDOMAIN} )) -gt 64 ] && {
			#	# OpenSSL allows max. 64 chars for CN in keys/certs
			#	echo "$VAR_MYNAME: Error: DAV-FQDN may not be longer than 64 chars. Aborting." > /dev/stderr
			#	exit 1
			#}
			[ $(( ${#LVAR_ARG_DAVHOSTNAME} + ${#SETTS_CACHE_MAILDOMAIN} )) -gt 50 ] && {
				echo "$VAR_MYNAME: Error: DAV-FQDN may not be longer than 50 chars. Aborting." > /dev/stderr
				exit 1
			}

			TMP_USER="$SETTS_CACHE_DB_MODO_USER"
			TMP_PASS="$SETTS_CACHE_DB_MODO_PASS"
			[ -z "$TMP_USER" ] && TMP_USER="$LVAR_ARG_DB_MODO_USER"
			[ -z "$TMP_PASS" ] && TMP_PASS="$LVAR_ARG_DB_MODO_PASS"

			[ -z "$TMP_USER" -o -z "$TMP_PASS" ] && {
				echo "$VAR_MYNAME: Error: CF_MODOBOA_CONF_DBNAME_AND_DBUSER or CF_MODOBOA_CONF_DBPASS not set. Aborting." > /dev/stderr
				exit 1
			}
			_mdbUpd_db_checkDbConnection "$TMP_USER" "$TMP_PASS" || {
				echo "$VAR_MYNAME: Error: Can't connect to DB '$TMP_USER@$LVAR_ARG_MARIADB_DOCKERHOST'. Aborting." > /dev/stderr
				exit 1
			}

			runUpdateDavHostname "$LVAR_ARG_DAVHOSTNAME" "$LVAR_ARG_MAILDOMAIN" || {
				echo "$VAR_MYNAME: Error: runUpdateDavHostname() failed. Aborting." > /dev/stderr
				exit 1
			}
		fi
		SETTS_CACHE_DAVHOSTNAME="$LVAR_ARG_DAVHOSTNAME"
	fi

	# -------------------
	# Enable/Disable SSL-Certificate verification if necessary
	runUpdateCaldavSslVerification || exit 1
fi

# -----------------------------------------------------------------
# Save new settings to cache

rm "$LVAR_SETTINGS_CACHE" && touch "$LVAR_SETTINGS_CACHE"

echo "# settings cache for /root/mdb_update.sh" > "$LVAR_SETTINGS_CACHE"

echo "SETTS_CACHE_DJANGO_SECRET_CHANGED=${SETTS_CACHE_DJANGO_SECRET_CHANGED:-false}" >> "$LVAR_SETTINGS_CACHE"

echo "SETTS_CACHE_ENABLE_MODOBOA_CSRF=$SETTS_CACHE_ENABLE_MODOBOA_CSRF" >> "$LVAR_SETTINGS_CACHE"
echo "SETTS_CACHE_MARIADB_DOCKERHOST='$SETTS_CACHE_MARIADB_DOCKERHOST'" >> "$LVAR_SETTINGS_CACHE"
echo "SETTS_CACHE_DB_MODO_USER='$SETTS_CACHE_DB_MODO_USER'" >> "$LVAR_SETTINGS_CACHE"
echo "SETTS_CACHE_DB_MODO_PASS='$SETTS_CACHE_DB_MODO_PASS'" >> "$LVAR_SETTINGS_CACHE"
echo "SETTS_CACHE_DB_AMAV_USER='$SETTS_CACHE_DB_AMAV_USER'" >> "$LVAR_SETTINGS_CACHE"
echo "SETTS_CACHE_DB_AMAV_PASS='$SETTS_CACHE_DB_AMAV_PASS'" >> "$LVAR_SETTINGS_CACHE"
echo "SETTS_CACHE_DB_SPAM_USER='$SETTS_CACHE_DB_SPAM_USER'" >> "$LVAR_SETTINGS_CACHE"
echo "SETTS_CACHE_DB_SPAM_PASS='$SETTS_CACHE_DB_SPAM_PASS'" >> "$LVAR_SETTINGS_CACHE"
echo "SETTS_CACHE_OPENDKIM_CONF_ENABLE=$SETTS_CACHE_OPENDKIM_CONF_ENABLE" >> "$LVAR_SETTINGS_CACHE"
echo "SETTS_CACHE_DB_DKIM_USER='$SETTS_CACHE_DB_DKIM_USER'" >> "$LVAR_SETTINGS_CACHE"
echo "SETTS_CACHE_DB_DKIM_PASS='$SETTS_CACHE_DB_DKIM_PASS'" >> "$LVAR_SETTINGS_CACHE"
echo "SETTS_CACHE_DAVHOSTNAME='$SETTS_CACHE_DAVHOSTNAME'" >> "$LVAR_SETTINGS_CACHE"
echo "SETTS_CACHE_MAILHOSTNAME='$SETTS_CACHE_MAILHOSTNAME'" >> "$LVAR_SETTINGS_CACHE"
echo "SETTS_CACHE_MAILDOMAIN='$SETTS_CACHE_MAILDOMAIN'" >> "$LVAR_SETTINGS_CACHE"
echo "SETTS_CACHE_TIMEZONE='$SETTS_CACHE_TIMEZONE'" >> "$LVAR_SETTINGS_CACHE"
echo "SETTS_CACHE_LANGUAGE='$SETTS_CACHE_LANGUAGE'" >> "$LVAR_SETTINGS_CACHE"
echo "SETTS_CACHE_CLAMAV_CONF_ENABLE=$SETTS_CACHE_CLAMAV_CONF_ENABLE" >> "$LVAR_SETTINGS_CACHE"

SETTS_CACHE_ALLSET=false
[ \
		"$SETTS_CACHE_DJANGO_SECRET_CHANGED" = "true" -a \
		-n "$SETTS_CACHE_ENABLE_MODOBOA_CSRF" -a \
		-n "$SETTS_CACHE_MARIADB_DOCKERHOST" -a \
		-n "$SETTS_CACHE_DB_MODO_USER" -a \
		-n "$SETTS_CACHE_DB_MODO_PASS" -a \
		-n "$SETTS_CACHE_DB_AMAV_USER" -a \
		-n "$SETTS_CACHE_DB_AMAV_PASS" -a \
		-n "$SETTS_CACHE_DB_SPAM_USER" -a \
		-n "$SETTS_CACHE_DB_SPAM_PASS" -a \
		-n "$SETTS_CACHE_OPENDKIM_CONF_ENABLE" -a \
		-n "$SETTS_CACHE_DB_DKIM_USER" -a \
		-n "$SETTS_CACHE_DB_DKIM_PASS" -a \
		-n "$SETTS_CACHE_DAVHOSTNAME" -a \
		-n "$SETTS_CACHE_MAILHOSTNAME" -a \
		-n "$SETTS_CACHE_MAILDOMAIN" -a \
		-n "$SETTS_CACHE_TIMEZONE" -a \
		-n "$SETTS_CACHE_LANGUAGE" -a \
		-n "$SETTS_CACHE_CLAMAV_CONF_ENABLE" -a \
		"x" = "x" ] && \
	SETTS_CACHE_ALLSET=true
echo "SETTS_CACHE_ALLSET=$SETTS_CACHE_ALLSET" >> "$LVAR_SETTINGS_CACHE"

chmod 600 "$LVAR_SETTINGS_CACHE"

# -----------------------------------------------------------------

echo -e "\n$VAR_MYNAME: Done.\n"
