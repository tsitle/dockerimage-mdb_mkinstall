#!/bin/bash

#
# by TS, Mar 2019
#

# @param string $1 Docker Container Name
#
# @return int EXITCODE
function buildTarget_runExportModo() {
	# customize Modoboa Localconf
	echo "$VAR_MYNAME: < reading Modo Localconf from DB"
	local TMP_JSON="$(db_readModoLocalconf "$LVAR_DENV__CF_MODOBOA_CONF_DBNAME_AND_DBUSER")"

	#echo "$TMP_JSON" > tmp.json.out

	local TMP_JSON_MOD="$(echo -n "$TMP_JSON" | docker exec -i "$1" \
			"/root/$CFG_MKINST_CUSTOMIZE_MODO_LCONF_PY_SCRIPT_FN" \
					--mailhost "$LVAR_DENV__CF_MAILHOSTNAME" \
					--maildomain "$LVAR_DENV__CF_MAILDOMAIN" \
					build -)"
	[ -z "$TMP_JSON_MOD" ] && {
		echo "$VAR_MYNAME: Error: Customizing failed. Aborting." >/dev/stderr
		return 1
	}

	echo "$VAR_MYNAME: > writing customized Modo Localconf to DB"
	db_writeModoLocalconf "$LVAR_DENV__CF_MODOBOA_CONF_DBNAME_AND_DBUSER" "$TMP_JSON_MOD"

	# export DBs
	db_exportDb "$LVAR_DENV__CF_MODOBOA_CONF_DBNAME_AND_DBUSER" "$CFG_MKINST_PATH_BUILDTEMP/$LVAR_DB_MODO_FN" || {
		echo "$VAR_MYNAME: Error: Exporting DB failed. Aborting." >/dev/stderr
		return 1
	}
	db_exportDb "$LVAR_DENV__CF_AMAVIS_CONF_DBNAME_AND_DBUSER" "$CFG_MKINST_PATH_BUILDTEMP/$LVAR_DB_AMAV_FN" || {
		echo "$VAR_MYNAME: Error: Exporting DB failed. Aborting." >/dev/stderr
		return 1
	}
	db_exportDb "$LVAR_DENV__CF_SPAMASSASS_CONF_DBNAME_AND_DBUSER" "$CFG_MKINST_PATH_BUILDTEMP/$LVAR_DB_SPAM_FN" || {
		echo "$VAR_MYNAME: Error: Exporting DB failed. Aborting." >/dev/stderr
		return 1
	}

	return 0
}

# @return int EXITCODE
function buildTarget_runPostDb() {
	local TMP_DKIM_DB=""
	if [ "$LVAR_DENV__CF_OPENDKIM_CONF_ENABLE" = "true" ]; then
		TMP_DKIM_DB="$LVAR_DENV__CF_OPENDKIM_CONF_DBNAME_AND_DBUSER"
	fi

	db_dropAllModoDbUsers "$LVAR_DENV__CF_MODOBOA_INSTALLER_DBUSER" \
			"$LVAR_DENV__CF_MODOBOA_CONF_DBNAME_AND_DBUSER" \
			"$LVAR_DENV__CF_AMAVIS_CONF_DBNAME_AND_DBUSER" \
			"$LVAR_DENV__CF_SPAMASSASS_CONF_DBNAME_AND_DBUSER" \
			"$TMP_DKIM_DB" || return 1

	db_runFlushPrivs || return 1

	TMP_DKIM_DB=""
	db_dropModoDbs "$LVAR_DENV__CF_MODOBOA_CONF_DBNAME_AND_DBUSER" \
			"$LVAR_DENV__CF_AMAVIS_CONF_DBNAME_AND_DBUSER" \
			"$LVAR_DENV__CF_SPAMASSASS_CONF_DBNAME_AND_DBUSER" \
			"$TMP_DKIM_DB" || {
		echo "$VAR_MYNAME: Error: Dropping DBs failed. Aborting." >/dev/stderr
		return 1
	}

	return 0
}

# @return int EXITCODE
function buildTarget() {
	local LVAR_DB_MODO_FN="$(mkinst_replaceVarInString "$CFG_MKINST_MARIADB_MODO_FN_TEMPL" "MODOBOA_VERSION" "$CFG_MKINST_MODOBOA_VERSION")"
	local LVAR_DB_AMAV_FN="$(mkinst_replaceVarInString "$CFG_MKINST_MARIADB_AMAV_FN_TEMPL" "MODOBOA_VERSION" "$CFG_MKINST_MODOBOA_VERSION")"
	local LVAR_DB_SPAM_FN="$(mkinst_replaceVarInString "$CFG_MKINST_MARIADB_SPAM_FN_TEMPL" "MODOBOA_VERSION" "$CFG_MKINST_MODOBOA_VERSION")"

	[ -f "$CFG_MKINST_PATH_BUILDTEMP/$LVAR_DB_MODO_FN.gz" ] && rm "$CFG_MKINST_PATH_BUILDTEMP/$LVAR_DB_MODO_FN.gz"
	[ -f "$CFG_MKINST_PATH_BUILDTEMP/$LVAR_DB_AMAV_FN.gz" ] && rm "$CFG_MKINST_PATH_BUILDTEMP/$LVAR_DB_AMAV_FN.gz"
	[ -f "$CFG_MKINST_PATH_BUILDTEMP/$LVAR_DB_SPAM_FN.gz" ] && rm "$CFG_MKINST_PATH_BUILDTEMP/$LVAR_DB_SPAM_FN.gz"

	#
	local LVAR_DB_DUMP_STEP3="tmp.databases.step3-post.tgz"
	local LVAR_DB_DUMP_STEP4="tmp.databases.step4-post.tgz"

	[ -f "$CFG_MKINST_PATH_BUILDTEMP/$LVAR_DB_DUMP_STEP4" ] && rm "$CFG_MKINST_PATH_BUILDTEMP/$LVAR_DB_DUMP_STEP4"

	################################################################################
	# Restore Databases

	[ -n "$CFG_MKINST_PATH_BUILDTEMP" -a -n "$CFG_MKINST_MARIADB_MNTPOINT" -a \
			-d "$CFG_MKINST_PATH_BUILDTEMP/$CFG_MKINST_MARIADB_MNTPOINT" ] && \
		rm -r "$CFG_MKINST_PATH_BUILDTEMP/$CFG_MKINST_MARIADB_MNTPOINT"

	echo -e "\n$VAR_MYNAME: Restoring Databases...\n"
	if [ -f "$CFG_MKINST_PATH_BUILDTEMP/$LVAR_DB_DUMP_STEP3" ]; then
		tar xf "$CFG_MKINST_PATH_BUILDTEMP/$LVAR_DB_DUMP_STEP3" || return 1
	else
		echo "$VAR_MYNAME: Error: Database backup '$CFG_MKINST_PATH_BUILDTEMP/$LVAR_DB_DUMP_STEP3' not found. Aborting." >/dev/stderr
		return 1
	fi

	################################################################################
	# Start Docker Container that contains the relevant ENV vars

	local TMP_RUNVER="$(echo -n "$CFG_MKINST_DOCK_IMG_RELEASE_VERS" | tr -d ".")"
	local TMP_DIN_DAEMON_STEP3="${CFG_MKINST_DOCK_IMG_STEP3}"
	local TMP_DC_DAEMON_STEP3="${TMP_DIN_DAEMON_STEP3}-${TMP_RUNVER}-cnt"

	mkinst_runDockerContainer_daemon "$TMP_DIN_DAEMON_STEP3" "$TMP_DC_DAEMON_STEP3" || return 1

	################################################################################
	# Start DB-Server and wait for server to be up and running

	mkinst_checkDbConnection || return 1

	################################################################################
	# Read ENV vars from Docker Image

	local TMP_DC_TO_READ_ENV_FROM="$TMP_DC_DAEMON_STEP3"
	echo -e "\n$VAR_MYNAME: Reading ENV Vars from Docker Container '$TMP_DC_TO_READ_ENV_FROM'...\n"
	local LVAR_DENV__CF_MAILHOSTNAME="$(mkinst_getEnvVarFromDockerContainer "$TMP_DC_TO_READ_ENV_FROM" "CF_MAILHOSTNAME")"
	local LVAR_DENV__CF_MAILDOMAIN="$(mkinst_getEnvVarFromDockerContainer "$TMP_DC_TO_READ_ENV_FROM" "CF_MAILDOMAIN")"
	local LVAR_DENV__CF_MODOBOA_INSTALLER_DBUSER="$(mkinst_getEnvVarFromDockerContainer "$TMP_DC_TO_READ_ENV_FROM" "CF_MODOBOA_INSTALLER_DBUSER")"
	local LVAR_DENV__CF_MODOBOA_INSTALLER_DBPASS="$(mkinst_getEnvVarFromDockerContainer "$TMP_DC_TO_READ_ENV_FROM" "CF_MODOBOA_INSTALLER_DBPASS")"
	local LVAR_DENV__CF_MODOBOA_CONF_DBNAME_AND_DBUSER="$(mkinst_getEnvVarFromDockerContainer "$TMP_DC_TO_READ_ENV_FROM" "CF_MODOBOA_CONF_DBNAME_AND_DBUSER")"
	local LVAR_DENV__CF_MODOBOA_CONF_DBPASS="$(mkinst_getEnvVarFromDockerContainer "$TMP_DC_TO_READ_ENV_FROM" "CF_MODOBOA_CONF_DBPASS")"
	local LVAR_DENV__CF_AMAVIS_CONF_DBNAME_AND_DBUSER="$(mkinst_getEnvVarFromDockerContainer "$TMP_DC_TO_READ_ENV_FROM" "CF_AMAVIS_CONF_DBNAME_AND_DBUSER")"
	local LVAR_DENV__CF_AMAVIS_CONF_DBPASS="$(mkinst_getEnvVarFromDockerContainer "$TMP_DC_TO_READ_ENV_FROM" "CF_AMAVIS_CONF_DBPASS")"
	local LVAR_DENV__CF_SPAMASSASS_CONF_DBNAME_AND_DBUSER="$(mkinst_getEnvVarFromDockerContainer "$TMP_DC_TO_READ_ENV_FROM" "CF_SPAMASSASS_CONF_DBNAME_AND_DBUSER")"
	local LVAR_DENV__CF_SPAMASSASS_CONF_DBPASS="$(mkinst_getEnvVarFromDockerContainer "$TMP_DC_TO_READ_ENV_FROM" "CF_SPAMASSASS_CONF_DBPASS")"
	local LVAR_DENV__CF_OPENDKIM_CONF_ENABLE="$(mkinst_getEnvVarFromDockerContainer "$TMP_DC_TO_READ_ENV_FROM" "CF_OPENDKIM_CONF_ENABLE")"
	local LVAR_DENV__CF_OPENDKIM_CONF_DBNAME_AND_DBUSER="$(mkinst_getEnvVarFromDockerContainer "$TMP_DC_TO_READ_ENV_FROM" "CF_OPENDKIM_CONF_DBNAME_AND_DBUSER")"
	local LVAR_DENV__CF_OPENDKIM_CONF_DBPASS="$(mkinst_getEnvVarFromDockerContainer "$TMP_DC_TO_READ_ENV_FROM" "CF_OPENDKIM_CONF_DBPASS")"

	if [ \
				-z "$LVAR_DENV__CF_MAILHOSTNAME" -o \
				-z "$LVAR_DENV__CF_MAILDOMAIN" -o \
				-z "$LVAR_DENV__CF_MODOBOA_INSTALLER_DBUSER" -o \
				-z "$LVAR_DENV__CF_MODOBOA_INSTALLER_DBPASS" -o \
				-z "$LVAR_DENV__CF_MODOBOA_CONF_DBNAME_AND_DBUSER" -o \
				-z "$LVAR_DENV__CF_MODOBOA_CONF_DBPASS" -o \
				-z "$LVAR_DENV__CF_AMAVIS_CONF_DBNAME_AND_DBUSER" -o \
				-z "$LVAR_DENV__CF_AMAVIS_CONF_DBPASS" -o \
				-z "$LVAR_DENV__CF_SPAMASSASS_CONF_DBNAME_AND_DBUSER" -o \
				-z "$LVAR_DENV__CF_SPAMASSASS_CONF_DBPASS" -o \
				-z "$LVAR_DENV__CF_OPENDKIM_CONF_ENABLE" -o \
				-z "$LVAR_DENV__CF_OPENDKIM_CONF_DBNAME_AND_DBUSER" -o \
				-z "$LVAR_DENV__CF_OPENDKIM_CONF_DBPASS" -o \
				"false" = "true" \
			]; then
		echo "$VAR_MYNAME: Error: Could not read ENV vars from Docker Image '$CFG_MKINST_DOCK_IMG_STEP3'. Aborting." >/dev/stderr
		return 1
	fi

	echo "$VAR_MYNAME:   * ENV CF_MAILHOSTNAME='$LVAR_DENV__CF_MAILHOSTNAME'"
	echo "$VAR_MYNAME:   * ENV CF_MAILDOMAIN='$LVAR_DENV__CF_MAILDOMAIN'"
	echo "$VAR_MYNAME:   * ENV CF_MODOBOA_INSTALLER_DBUSER='$LVAR_DENV__CF_MODOBOA_INSTALLER_DBUSER'"
	echo "$VAR_MYNAME:   * ENV CF_MODOBOA_INSTALLER_DBPASS='$LVAR_DENV__CF_MODOBOA_INSTALLER_DBPASS'"
	echo "$VAR_MYNAME:   * ENV CF_MODOBOA_CONF_DBNAME_AND_DBUSER='$LVAR_DENV__CF_MODOBOA_CONF_DBNAME_AND_DBUSER'"
	echo "$VAR_MYNAME:   * ENV CF_MODOBOA_CONF_DBPASS='$LVAR_DENV__CF_MODOBOA_CONF_DBPASS'"
	echo "$VAR_MYNAME:   * ENV CF_AMAVIS_CONF_DBNAME_AND_DBUSER='$LVAR_DENV__CF_AMAVIS_CONF_DBNAME_AND_DBUSER'"
	echo "$VAR_MYNAME:   * ENV CF_AMAVIS_CONF_DBPASS='$LVAR_DENV__CF_AMAVIS_CONF_DBPASS'"
	echo "$VAR_MYNAME:   * ENV CF_SPAMASSASS_CONF_DBNAME_AND_DBUSER='$LVAR_DENV__CF_SPAMASSASS_CONF_DBNAME_AND_DBUSER'"
	echo "$VAR_MYNAME:   * ENV CF_SPAMASSASS_CONF_DBPASS='$LVAR_DENV__CF_SPAMASSASS_CONF_DBPASS'"
	echo "$VAR_MYNAME:   * ENV CF_OPENDKIM_CONF_ENABLE='$LVAR_DENV__CF_OPENDKIM_CONF_ENABLE'"
	if [ "$LVAR_DENV__CF_OPENDKIM_CONF_ENABLE" = "true" ]; then
		echo "$VAR_MYNAME:   * ENV CF_OPENDKIM_CONF_DBNAME_AND_DBUSER='$LVAR_DENV__CF_OPENDKIM_CONF_DBNAME_AND_DBUSER'"
		echo "$VAR_MYNAME:   * ENV CF_OPENDKIM_CONF_DBPASS='$LVAR_DENV__CF_OPENDKIM_CONF_DBPASS'"
	fi

	################################################################################
	# Export Modoboa DBs

	echo -e "\n$VAR_MYNAME: Exporting Modoboa DBs...\n"
	buildTarget_runExportModo "$TMP_DC_DAEMON_STEP3" || return 1

	################################################################################
	# Remove DB-Users

	echo -e "\n$VAR_MYNAME: Removing DB and DB-Users...\n"
	buildTarget_runPostDb
	if [ $? -ne 0 ]; then
		echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr
		return 1
	fi

	################################################################################
	# Copy DB-Dumps to Container

	echo -e "\n$VAR_MYNAME: Copying DB-Dumps to Docker Container...\n"
	docker cp "$CFG_MKINST_PATH_BUILDTEMP/$LVAR_DB_MODO_FN.gz" "$TMP_DC_DAEMON_STEP3":/root/
	if [ $? -ne 0 ]; then
		echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr
		return 1
	fi
	docker cp "$CFG_MKINST_PATH_BUILDTEMP/$LVAR_DB_AMAV_FN.gz" "$TMP_DC_DAEMON_STEP3":/root/
	docker cp "$CFG_MKINST_PATH_BUILDTEMP/$LVAR_DB_SPAM_FN.gz" "$TMP_DC_DAEMON_STEP3":/root/

	docker exec "$TMP_DC_DAEMON_STEP3" \
			chown root:root \
					"/root/$LVAR_DB_MODO_FN.gz" \
					"/root/$LVAR_DB_AMAV_FN.gz" \
					"/root/$LVAR_DB_SPAM_FN.gz"

	rm \
			"$CFG_MKINST_PATH_BUILDTEMP/$LVAR_DB_MODO_FN.gz" \
			"$CFG_MKINST_PATH_BUILDTEMP/$LVAR_DB_AMAV_FN.gz" \
			"$CFG_MKINST_PATH_BUILDTEMP/$LVAR_DB_SPAM_FN.gz"

	################################################################################
	# Commit Docker Container to new Image

	local TMP_DI="$(mkinst_getDockerImageNameAndVersionStringForBuildTarget "$OPT_CMD_ARG1")"
	echo -e "\n$VAR_MYNAME: Commiting Docker Container '$TMP_DC_DAEMON_STEP3' to new Image '$TMP_DI'...\n"
	docker commit -m "Installed Modoboa" "$TMP_DC_DAEMON_STEP3" "$TMP_DI"
	if [ $? -ne 0 ]; then
		echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr
		return 1
	fi

	################################################################################
	# Remove Databases

	mkinst_stopDbServer || return 1
	#
	echo -e "\n$VAR_MYNAME: Removing Databases...\n"
	cd "$VAR_MYDIR" || return 1
	[ -n "$CFG_MKINST_PATH_BUILDTEMP" -a -n "$CFG_MKINST_MARIADB_MNTPOINT" -a \
			-d "$CFG_MKINST_PATH_BUILDTEMP/$CFG_MKINST_MARIADB_MNTPOINT" ] && \
		rm -r "$CFG_MKINST_PATH_BUILDTEMP/$CFG_MKINST_MARIADB_MNTPOINT"

	return 0
}
