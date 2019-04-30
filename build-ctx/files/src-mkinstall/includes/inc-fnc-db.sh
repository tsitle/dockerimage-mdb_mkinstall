#!/bin/bash

#
# depends on mariadb >= 10.1,
#            grep, tr, tail
#            gzip
#

################################################################################
# Database Functions

# Outputs result of SQL-Query if any
#
# @param string $1 SQL-Query
#
# @return int EXITCODE
function db__execSqlQuery() {
	if [ -z "$VAR_DB_FNCS_DC_MARIADB" ]; then
		echo "$VAR_MYNAME: Error: VAR_DB_FNCS_DC_MARIADB empty. Aborting." >/dev/stderr
		return 1
	fi
	if [ -z "$VAR_DB_FNCS_MARIADB_ROOT_PASS" ]; then
		echo "$VAR_MYNAME: Error: VAR_DB_FNCS_MARIADB_ROOT_PASS empty. Aborting." >/dev/stderr
		return 1
	fi
	if [ -z "$VAR_DB_FNCS_DC_MDB" ]; then
		echo "$VAR_MYNAME: Error: VAR_DB_FNCS_DC_MDB empty. Aborting." >/dev/stderr
		return 1
	fi
	if [ -z "$VAR_TEMPFILE_PREFIX" ]; then
		echo "$VAR_MYNAME: Error: VAR_TEMPFILE_PREFIX empty. Aborting." >/dev/stderr
		return 1
	fi
	if [ -z "$1" ]; then
		echo "$VAR_MYNAME: Error: SQL-Query must not be empty. Aborting." >/dev/stderr
		return 1
	fi

	#echo -n "++ ping $VAR_DB_FNCS_DC_MARIADB: " >/dev/stderr
	#docker exec "$VAR_DB_FNCS_DC_MDB" ping -c1 -n -W1 $VAR_DB_FNCS_DC_MARIADB >/dev/null 2>&1
	#[ $? -eq 0 ] && echo "OK" >/dev/stderr || echo "FAIL" >/dev/stderr
	#echo "++ DBUSER: 'root'" >/dev/stderr
	#echo "++ DBPASS: '$VAR_DB_FNCS_MARIADB_ROOT_PASS'" >/dev/stderr
	#echo -e "\n++ CMD: '$1'\n" >/dev/stderr
	#echo "VAR_DB_FNCS_DC_MDB=$VAR_DB_FNCS_DC_MDB" >/dev/stderr

	#echo "$VAR_MYNAME: running SQL-Query..." >/dev/stderr
	docker exec "$VAR_DB_FNCS_DC_MDB" \
			mysql -h "$VAR_DB_FNCS_DC_MARIADB" --port=3306 --protocol tcp \
					-u "root" \
					--password="$VAR_DB_FNCS_MARIADB_ROOT_PASS" \
					--connect-timeout=1 \
					-e "$1" >"${VAR_TEMPFILE_PREFIX}fnc-db1" 2>/dev/stderr
	local TMP_RES=$?

	#echo -e "\n++## RESP:" >/dev/stderr
	#cat "${VAR_TEMPFILE_PREFIX}fnc-db1" >/dev/stderr
	#echo >/dev/stderr

	if [ $TMP_RES -eq 0 ]; then
		grep -v "Using a password on the command line" "${VAR_TEMPFILE_PREFIX}fnc-db1" 2>/dev/null
	fi
	rm "${VAR_TEMPFILE_PREFIX}fnc-db1"
	return $TMP_RES
}

# @return int EXITCODE
function db_checkSqlRootUser() {
	local TMP_DBFNC_RES=0
	if [ -z "$VAR_DB_FNCS_MARIADB_ROOT_PASS" ]; then
		echo "$VAR_MYNAME: Error: VAR_DB_FNCS_MARIADB_ROOT_PASS empty. Aborting." >/dev/stderr
		TMP_DBFNC_RES=1
	fi
	return $TMP_DBFNC_RES
}

# @return int EXITCODE
function db_checkDbConnection() {
	db__execSqlQuery "SHOW DATABASES;" >/dev/null
}

# @param string $1 DBNAME
#
# @return int EXITCODE
function db_checkIfDbSchemeExists() {
	db__execSqlQuery "SHOW DATABASES;" | grep -q "^$1$"
}

# @return int EXITCODE
function db_runFlushPrivs() {
	db__execSqlQuery "FLUSH PRIVILEGES;"
}

# @param string $1 USER
# @param string $2 ALLOWED_HOST_FOR_USER
#
# @return int EXITCODE
function db_checkIfSqlUserExists() {
	local TMP_DBFNC_CMD="SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '$1' AND host = '$2');"
	db__execSqlQuery "$TMP_DBFNC_CMD" >"${VAR_TEMPFILE_PREFIX}fnc-db2"
	local TMP_RES=$?
	if [ $TMP_RES -eq 0 ]; then
		local TMP_QUERYRES="$(grep -v -e "\-------" -e "EXISTS" "${VAR_TEMPFILE_PREFIX}fnc-db2")"
		if [ "$TMP_QUERYRES" = "1" ]; then
			TMP_RES=0
		else
			TMP_RES=1
		fi
	fi
	rm "${VAR_TEMPFILE_PREFIX}fnc-db2"
	return $TMP_RES
}

# Outputs LIST_OF_HOSTS - one per line
#
# @param string $1 USER
#
# @return int EXITCODE 
function db_getSqlUserHosts() {
	local TMP_DBFNC_CMD="SELECT host FROM mysql.user WHERE user = '$1';"
	db__execSqlQuery "$TMP_DBFNC_CMD" >"${VAR_TEMPFILE_PREFIX}fnc-db2"
	local TMP_RES=$?
	if [ $TMP_RES -eq 0 ]; then
		tail -n +2 "${VAR_TEMPFILE_PREFIX}fnc-db2"
	fi
	rm "${VAR_TEMPFILE_PREFIX}fnc-db2"
	return $TMP_RES
}

# @param string $1 USER
# @param string $2 ALLOWED_HOST_FOR_USER
#
# @return int EXITCODE
function db_dropDbUserIfExists() {
	[ -z "$1" -o "$1" = "root" ] && return 1
	db_checkIfSqlUserExists "$1" "$2" || return 1

	echo "$VAR_MYNAME: - Dropping DB-User '$1'@'$2'"
	db__execSqlQuery "DROP USER '$1'@'$2';"
}

# @param string $1 USER
# @param string $2 ALLOWED_HOST_FOR_USER
# @param string $3 PASSWORD
#
# @return int EXITCODE
function db_createDbUserIfNotExists() {
	[ -z "$1" -o "$1" = "root" ] && return 1
	db_checkIfSqlUserExists "$1" "$2" && return 1

	echo "$VAR_MYNAME: + Creating DB-User '$1'@'$2'"
	local TMP_DBFNC_CMD="CREATE USER '$1'@'$2' IDENTIFIED WITH mysql_native_password; \
			SET PASSWORD FOR '$1'@'$2' = PASSWORD('$3');"
	db__execSqlQuery "$TMP_DBFNC_CMD"
}

# @param string $1 USER
# @param string $2 ALLOWED_HOST_FOR_USER
# @param string $3 DBNAME
#
# @return int EXITCODE
function db_grantDbUserIfExists() {
	[ -z "$1" -o "$1" = "root" ] && return 1
	db_checkIfSqlUserExists "$1" "$2" || return 1

	echo "$VAR_MYNAME: / Granting access for DB-User '$1'@'$2' to DB-Scheme '$3'"
	local TMP_DBFNC_CMD="GRANT ALL PRIVILEGES ON \`$3\`.* TO '$1'@'$2'; \
			FLUSH PRIVILEGES;"
	db__execSqlQuery "$TMP_DBFNC_CMD"
}

# @param string $1 USER
# @param string $2 ALLOWED_HOST_FOR_USER
# @param string $3 DBNAME
#
# @return int EXITCODE
function db_grantDbUserSelectIfExists() {
	[ -z "$1" -o "$1" = "root" ] && return 1
	db_checkIfSqlUserExists "$1" "$2" || return 1

	echo "$VAR_MYNAME: / Granting SELECT to DB-User '$1'@'$2' to DB-Scheme '$3'"
	local TMP_DBFNC_CMD="GRANT SELECT ON \`$3\`.* TO '$1'@'$2'; \
			FLUSH PRIVILEGES;"
	db__execSqlQuery "$TMP_DBFNC_CMD"
}

# @param string $1 USER
# @param string $2 ALLOWED_HOST_FOR_USER
# @param string $3 PASSWORD
#
# @return int EXITCODE
function db_changeDbUserPwIfExists() {
	[ -z "$1" -o "$1" = "root" ] && return 1
	db_checkIfSqlUserExists "$1" "$2" || return 1

	echo "$VAR_MYNAME: / Changing password for DB-User '$1'@'$2' to '$3'"
	local TMP_DBFNC_CMD="SET PASSWORD FOR '$1'@'$2' = PASSWORD('$3');"
	db__execSqlQuery "$TMP_DBFNC_CMD"
}

# @param string $1 USER
# @param string $2 ALLOWED_HOST_FOR_USER
# @param string $3 DBNAME
# @param string $4 ALLOWED_HOST_FOR_USER_TEMPLATE
#
# @return int EXITCODE
function db_createModoDbUser() {
	[ -z "$1" -o "$1" = "root" ] && return 1
	[ -z "$2" -o -z "$3" -o -z "$4" ] && return 1
	for SRC in `db_getSqlUserHosts "$1"`; do
		db_dropDbUserIfExists "$1" "$SRC"
	done
	db_createDbUserIfNotExists "$1" "localhost" "$2"
	db_grantDbUserIfExists "$1" "localhost" "$3"
	db_createDbUserIfNotExists "$1" "$VAR_DB_FNCS_DC_MARIADB" "$2"
	db_grantDbUserIfExists "$1" "$VAR_DB_FNCS_DC_MARIADB" "$3"
	db_createDbUserIfNotExists "$1" "$4" "$2"
	db_grantDbUserIfExists "$1" "$4" "$3"
	return 0
}

# @param string $1 USER
# @param string $2 PASSWORD
# @param string $3 ALLOWED_HOST_FOR_USER_TEMPLATE
# @param string $4 MODO_DBNAME
# @param string $5 AMAVIS_DBNAME
# @param string $6 SPAM_DBNAME
# @param string $7 optional: DKIM_DBNAME
#
# @return int EXITCODE
function db_createModoInstallerDbUser() {
	[ -z "$1" -o "$1" = "root" ] && return 1
	for SRC in `db_getSqlUserHosts "$1"`; do
		db_dropDbUserIfExists "$1" "$SRC"
	done

	db_createDbUserIfNotExists "$1" "$3" "$2"
	db_grantDbUserIfExists "$1" "$3" "$4"
	db_grantDbUserIfExists "$1" "$3" "$5"
	db_grantDbUserIfExists "$1" "$3" "$6"
	if [ -n "$7" ]; then
		db_grantDbUserIfExists "$1" "$3" "$7"
	fi

	db_createDbUserIfNotExists "$1" "localhost" "$2"
	db_grantDbUserIfExists "$1" "localhost" "$4"
	db_grantDbUserIfExists "$1" "localhost" "$5"
	db_grantDbUserIfExists "$1" "localhost" "$6"
	if [ -n "$7" ]; then
		db_grantDbUserIfExists "$1" "localhost" "$7"
	fi

	db_createDbUserIfNotExists "$1" "$VAR_DB_FNCS_DC_MARIADB" "$2"
	db_grantDbUserIfExists "$1" "$VAR_DB_FNCS_DC_MARIADB" "$4"
	db_grantDbUserIfExists "$1" "$VAR_DB_FNCS_DC_MARIADB" "$5"
	db_grantDbUserIfExists "$1" "$VAR_DB_FNCS_DC_MARIADB" "$6"
	if [ -n "$7" ]; then
		db_grantDbUserIfExists "$1" "$VAR_DB_FNCS_DC_MARIADB" "$7"
	fi

	return 0
}

# @param string $1 MODO_INSTALLER_DBUSER
# @param string $2 MODO_DBUSER
# @param string $3 AMAVIS_DBUSER
# @param string $4 SPAM_DBUSER
# @param string $5 optional: DKIM_DBNAME
#
# @return int EXITCODE
function db_dropAllModoDbUsers() {
	if [ "$1" != "ignore" ]; then
		for SRC in `db_getSqlUserHosts "$1"`; do
			db_dropDbUserIfExists "$1" "$SRC"
		done
	fi
	for SRC in `db_getSqlUserHosts "$2"`; do
		db_dropDbUserIfExists "$2" "$SRC"
	done
	for SRC in `db_getSqlUserHosts "$3"`; do
		db_dropDbUserIfExists "$3" "$SRC"
	done
	for SRC in `db_getSqlUserHosts "$4"`; do
		db_dropDbUserIfExists "$4" "$SRC"
	done
	if [ -n "$5" ]; then
		for SRC in `db_getSqlUserHosts "$5"`; do
			db_dropDbUserIfExists "$5" "$SRC"
		done
	fi
	return 0
}

# Outputs CONF_JSON_ENC
#
# @param string $1 MODO_DBNAME
#
# @return int EXITCODE
function db_readModoLocalconf() {
	local TMP_DBFNC_CMD="USE \`$1\`; \
			SELECT _parameters FROM \`core_localconfig\` WHERE id = 1;"
	db__execSqlQuery "$TMP_DBFNC_CMD" >"${VAR_TEMPFILE_PREFIX}fnc-db2"
	local TMP_RES=$?
	if [ $TMP_RES -eq 0 ]; then
		tail -n +2 "${VAR_TEMPFILE_PREFIX}fnc-db2"
	fi
	rm "${VAR_TEMPFILE_PREFIX}fnc-db2"
	return $TMP_RES
}

# @param string $1 MODO_DBNAME
# @param string $2 CONF_JSON_ENC
#
# @return int EXITCODE
function db_writeModoLocalconf() {
	local TMP_DBFNC_CMD="USE \`$1\`; \
			UPDATE \`core_localconfig\` SET _parameters = '$2' WHERE id = 1;"
	db__execSqlQuery "$TMP_DBFNC_CMD"
}

# @param string $1 DBNAME
# @param string $2 OUTPUT_FN on Host
#
# @return int EXITCODE
function db_exportDb() {
	echo "$VAR_MYNAME: > exporting DB '$1' to '$2.gz'"
	[ -z "$2" -o ${#2} -lt 5 ] && return 1
	[ -f "$2" ] && rm "$2"
	[ -f "$2.gz" ] && rm "$2.gz"

	docker exec "$VAR_DB_FNCS_DC_MDB" \
			mysqldump "$1" \
					-h "$VAR_DB_FNCS_DC_MARIADB" --port=3306 --protocol tcp \
					-u "root" \
					--password="$VAR_DB_FNCS_MARIADB_ROOT_PASS" \
					--add-drop-table \
					>"$2" || return 1
	gzip "$2"
}

# @param string $1 DBNAME
# @param string $2 INPUT_FN in Container
#
# @return int EXITCODE
function db_importDb() {
	[ -z "$2" -o ${#2} -lt 5 ] && return 1

	local TMP_INPFN="$2"
	echo -n "$TMP_INPFN" | grep -q "\.gz$" || TMP_INPFN="${TMP_INPFN}.gz"
	echo "$VAR_MYNAME: < importing DB '$1' from '$VAR_DB_FNCS_DC_MDB:$TMP_INPFN'"

	docker exec -it "$VAR_DB_FNCS_DC_MDB" \
			bash -c "gunzip -c \"$TMP_INPFN\" | mysql \"$1\" \
					-h \"$VAR_DB_FNCS_DC_MARIADB\" --port=3306 --protocol tcp \
					-u \"root\" \
					--password=\"$VAR_DB_FNCS_MARIADB_ROOT_PASS\""
}

# @param string $1 DBNAME
#
# @return int EXITCODE
function db_createDb() {
	[ -z "$1" -o "$1" = "information_schema" -o "$1" = "mysql" -o "$1" = "performance_schema" -o "$1" = "phpmyadmin" ] && return 1
	local TMP_DBFNC_CMD="CREATE DATABASE IF NOT EXISTS \`$1\` DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;"
	db__execSqlQuery "$TMP_DBFNC_CMD"
}

# @param string $1 DBNAME
# @param string $2 INPUT_FN
#
# @return int EXITCODE
function db_createAndImportDb() {
	db_createDb "$1" || {
		echo "$VAR_MYNAME: Error: creating DB '$1' failed. Aborting." >/dev/stderr
		return 1
	}
	db_importDb "$1" "$2" || {
		echo "$VAR_MYNAME: Error: importing DB '$1' failed. Aborting." >/dev/stderr
		return 1
	}
	return 0
}

# @param string $1 DBNAME
#
# @return int EXITCODE
function db_dropDb() {
	[ -z "$1" -o \
			"$1" = "information_schema" -o \
			"$1" = "mysql" -o \
			"$1" = "performance_schema" -o \
			"$1" = "phpmyadmin" ] && return 1
	echo "$VAR_MYNAME: - Dropping DB '$1'"
	local TMP_DBFNC_CMD="DROP DATABASE IF EXISTS \`$1\`;"
	db__execSqlQuery "$TMP_DBFNC_CMD"
}

# @param string $1 MODO_DBNAME
# @param string $2 AMAVIS_DBNAME
# @param string $3 SPAM_DBNAME
# @param string $4 optional: DKIM_DBNAME
#
# @return int EXITCODE
function db_dropModoDbs() {
	db_dropDb "$1" || return 1
	db_dropDb "$2" || return 1
	db_dropDb "$3" || return 1
	if [ -n "$4" ]; then
		db_dropDb "$4" || return 1
	fi
	return 0
}
