#!/bin/bash

#
# by TS, Mar 2019
#

# @return int EXITCODE
function buildTarget_createDbUsers() {
	# Create Database-Users for Modoboa/Amavis/Spamassassin
	db_createModoDbUser "$LVAR_DENV__CF_MODOBOA_CONF_DBNAME_AND_DBUSER" "$LVAR_DENV__CF_MODOBOA_CONF_DBPASS" \
			"$LVAR_DENV__CF_MODOBOA_CONF_DBNAME_AND_DBUSER" "${CFG_MKINST_DOCK_NET_PREFIX}.%" || return 1
	db_createModoDbUser "$LVAR_DENV__CF_AMAVIS_CONF_DBNAME_AND_DBUSER" "$LVAR_DENV__CF_AMAVIS_CONF_DBPASS" \
			"$LVAR_DENV__CF_AMAVIS_CONF_DBNAME_AND_DBUSER" "${CFG_MKINST_DOCK_NET_PREFIX}.%" || return 1
	db_createModoDbUser "$LVAR_DENV__CF_SPAMASSASS_CONF_DBNAME_AND_DBUSER" "$LVAR_DENV__CF_SPAMASSASS_CONF_DBPASS" \
			"$LVAR_DENV__CF_SPAMASSASS_CONF_DBNAME_AND_DBUSER" "${CFG_MKINST_DOCK_NET_PREFIX}.%" || return 1
	if [ "$LVAR_DENV__CF_OPENDKIM_CONF_ENABLE" = "true" ]; then
		db_createModoDbUser "$LVAR_DENV__CF_OPENDKIM_CONF_DBNAME_AND_DBUSER" "$LVAR_DENV__CF_OPENDKIM_CONF_DBPASS" \
				"$LVAR_DENV__CF_OPENDKIM_CONF_DBNAME_AND_DBUSER" "${CFG_MKINST_DOCK_NET_PREFIX}.%" || return 1
	fi

	# Create Database-User for Modo-Installer
	local TMP_DKIM_DB=""
	if [ "$LVAR_DENV__CF_OPENDKIM_CONF_ENABLE" = "true" ]; then
		TMP_DKIM_DB="$LVAR_DENV__CF_OPENDKIM_CONF_DBNAME_AND_DBUSER"
	fi
	db_createModoInstallerDbUser "$LVAR_DENV__CF_MODOBOA_INSTALLER_DBUSER" "$LVAR_DENV__CF_MODOBOA_INSTALLER_DBPASS" \
			"${CFG_MKINST_DOCK_NET_PREFIX}.%" \
			"$LVAR_DENV__CF_MODOBOA_CONF_DBNAME_AND_DBUSER" \
			"$LVAR_DENV__CF_AMAVIS_CONF_DBNAME_AND_DBUSER" \
			"$LVAR_DENV__CF_SPAMASSASS_CONF_DBNAME_AND_DBUSER" \
			"$TMP_DKIM_DB" || return 1

	# Grant SELECT to OpenDKIM-DB-User on Modo-DB
	if [ "$LVAR_DENV__CF_OPENDKIM_CONF_ENABLE" = "true" ]; then
		db_grantDbUserSelectIfExists \
				"$TMP_DKIM_DB" \
				"${CFG_MKINST_DOCK_NET_PREFIX}.%" \
				"$LVAR_DENV__CF_MODOBOA_CONF_DBNAME_AND_DBUSER" || return 1
	fi

	#
	db_runFlushPrivs
}

# @return int EXITCODE
function buildTarget() {
	local LVAR_DB_DUMP_VANILLA="tmp.databases.step3-vanilla.tgz"
	local LVAR_DB_DUMP_STEP3="tmp.databases.step3-post.tgz"

	[ -f "$CFG_MKINST_PATH_BUILDTEMP/$LVAR_DB_DUMP_STEP3" ] && rm "$CFG_MKINST_PATH_BUILDTEMP/$LVAR_DB_DUMP_STEP3"

	################################################################################
	# Restore Databases

	[ -n "$CFG_MKINST_PATH_BUILDTEMP" -a -n "$CFG_MKINST_MARIADB_MNTPOINT" -a \
			-d "$CFG_MKINST_PATH_BUILDTEMP/$CFG_MKINST_MARIADB_MNTPOINT" ] && \
		rm -r "$CFG_MKINST_PATH_BUILDTEMP/$CFG_MKINST_MARIADB_MNTPOINT"

	if [ -f "$CFG_MKINST_PATH_BUILDTEMP/$LVAR_DB_DUMP_VANILLA" ]; then
		echo -e "\n$VAR_MYNAME: Restoring Databases...\n"
		tar xf "$CFG_MKINST_PATH_BUILDTEMP/$LVAR_DB_DUMP_VANILLA" || return 1
	fi

	################################################################################
	# Start Docker Container that contains the relevant ENV vars

	local TMP_RUNVER="$(echo -n "$CFG_MKINST_DOCK_IMG_RELEASE_VERS" | tr -d ".")"
	local TMP_DIN_DAEMON_STEP2="${CFG_MKINST_DOCK_IMG_STEP2}"
	local TMP_DC_DAEMON_STEP2="${TMP_DIN_DAEMON_STEP2}-${TMP_RUNVER}-cnt"

	mkinst_runDockerContainer_daemon "$TMP_DIN_DAEMON_STEP2" "$TMP_DC_DAEMON_STEP2" || return 1

	################################################################################
	# Start DB-Server and wait for server to be up and running

	mkinst_checkDbConnection || return 1

	################################################################################
	# Backup Databases

	if [ ! -f "$CFG_MKINST_PATH_BUILDTEMP/$LVAR_DB_DUMP_VANILLA" ]; then
		mkinst_stopDbServer || return 1
		#
		echo -e "\n$VAR_MYNAME: Backing Databases up...\n"
		tar czf "$CFG_MKINST_PATH_BUILDTEMP/$LVAR_DB_DUMP_VANILLA" "$CFG_MKINST_PATH_BUILDTEMP/$CFG_MKINST_MARIADB_MNTPOINT" || return 1
		#
		mkinst_checkDbConnection || return 1
	fi

	################################################################################
	# Read ENV vars from Docker Image

	local TMP_DC_TO_READ_ENV_FROM="$TMP_DC_DAEMON_STEP2"
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
		echo "$VAR_MYNAME: Error: Could not read ENV vars from Docker Image '$CFG_MKINST_DOCK_IMG_STEP2'. Aborting." >/dev/stderr
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
	# Init DB

	echo -e "\n$VAR_MYNAME: Creating DB-Users and DB-Privileges...\n"
	buildTarget_createDbUsers
	if [ $? -ne 0 ]; then
		echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr
		return 1
	fi

	################################################################################
	# Install Modoboa in Docker Container
	# and then check for Python Module lxml -- sometimes the build process fails

	echo -e "$VAR_MYNAME: Install Modoboa in Docker Container '$TMP_DC_DAEMON_STEP2'...\n"
	docker exec -t "$TMP_DC_DAEMON_STEP2" \
			/bin/bash -c "( \
						cd modoboa-installer-\${CF_MODOBOA_INSTALLER_VERSION}-modified && \
						./run.py --force --debug \"\${CF_MAILDOMAIN}\" && \
						cd .. && \
						rm -r modoboa-installer-\${CF_MODOBOA_INSTALLER_VERSION}-modified && \
						test \"\$(find /srv/modoboa/env/lib/python2.7/site-packages/ -type d -name \"lxml-*-py2.7.egg-info\" | wc -l)\" = '1' \
					)"
	if [ $? -ne 0 ]; then
		echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr
		return 1
	fi

	################################################################################
	# Commit Docker Container to new Image

	local TMP_DI="$(mkinst_getDockerImageNameAndVersionStringForBuildTarget "$OPT_CMD_ARG1")"
	echo -e "\n$VAR_MYNAME: Commiting Docker Container '$TMP_DC_DAEMON_STEP2' to new Image '$TMP_DI'...\n"
	docker commit -m "Installed Modoboa" "$TMP_DC_DAEMON_STEP2" "$TMP_DI"
	if [ $? -ne 0 ]; then
		echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr
		return 1
	fi

	################################################################################
	# Backup Databases

	mkinst_stopDbServer || return 1
	#
	echo -e "\n$VAR_MYNAME: Backing Databases up...\n"
	cd "$VAR_MYDIR" || return 1
	tar czf "$CFG_MKINST_PATH_BUILDTEMP/$LVAR_DB_DUMP_STEP3" "$CFG_MKINST_PATH_BUILDTEMP/$CFG_MKINST_MARIADB_MNTPOINT" || return 1

	echo -e "\n$VAR_MYNAME: Removing Databases...\n"
	[ -n "$CFG_MKINST_PATH_BUILDTEMP" -a -n "$CFG_MKINST_MARIADB_MNTPOINT" -a \
			-d "$CFG_MKINST_PATH_BUILDTEMP/$CFG_MKINST_MARIADB_MNTPOINT" ] && \
		rm -r "$CFG_MKINST_PATH_BUILDTEMP/$CFG_MKINST_MARIADB_MNTPOINT"

	return 0
}
