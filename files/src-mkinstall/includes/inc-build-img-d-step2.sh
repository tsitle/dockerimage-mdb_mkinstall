#!/bin/bash

#
# by TS, Mar 2019
#

# @return int EXITCODE
function buildTarget() {
	echo "$VAR_MYNAME: Checking Password-Generator..."
	mkinst_generatePassword >/dev/null || return 1

	echo "$VAR_MYNAME: Generating variables..."
	echo "$VAR_MYNAME:    * MAILHOSTNAME"
	local LVAR_MAILHOSTNAME="modomail"
	echo "$VAR_MYNAME:    * MAILDOMAIN"
	local LVAR_MAILDOMAIN="$(mkinst_generatePassword $(( 43 - ${#LVAR_MAILHOSTNAME} )) ).local"

	#[ $(( ${#LVAR_MAILHOSTNAME} + ${#LVAR_MAILDOMAIN} )) -gt 64 ] && {
	#	# OpenSSL allows max. 64 chars for CN in keys/certs
	#	echo "$MYNAME: Error: Mail-FQDN may not be longer than 64 chars. Aborting." > /dev/stderr
	#	exit 1
	#}
	[ $(( ${#LVAR_MAILHOSTNAME} + ${#LVAR_MAILDOMAIN} )) -gt 50 ] && {
		# DB-Table modoboa.django_site allows max. 50 chars for field 'name'
		echo "$VAR_MYNAME: Error: Mail-FQDN may not be longer than 50 chars. Aborting." > /dev/stderr
		return 1
	}

	echo "$VAR_MYNAME:    * MODOBOA_INSTALLER_DBPASS"
	local LVAR_MODOBOA_INSTALLER_DBPASS="$(mkinst_generatePassword 16)"
	[ ${#LVAR_MODOBOA_INSTALLER_DBPASS} -ne 16 ] && {
		echo "$VAR_MYNAME: Error: Unexpected password length. Aborting." > /dev/stderr
		return 1
	}

	echo "$VAR_MYNAME:    * MODOBOA_CONF_DBNAME_AND_DBUSER"
	local LVAR_MODOBOA_CONF_DBNAME_AND_DBUSER="${CFG_MKINST_MARIADB_MODOBOA_DBS_PREFIX}modoboa"
	echo "$VAR_MYNAME:    * AMAVIS_CONF_DBNAME_AND_DBUSER"
	local LVAR_AMAVIS_CONF_DBNAME_AND_DBUSER="${CFG_MKINST_MARIADB_MODOBOA_DBS_PREFIX}amavis"
	echo "$VAR_MYNAME:    * SPAMASSASS_CONF_DBNAME_AND_DBUSER"
	local LVAR_SPAMASSASS_CONF_DBNAME_AND_DBUSER="${CFG_MKINST_MARIADB_MODOBOA_DBS_PREFIX}spamassassin"
	local LVAR_OPENDKIM_CONF_DBNAME_AND_DBUSER="--"
	if [ "$CFG_MKINST_DEBUG_DISABLE_OPENDKIM" != "true" ]; then
		echo "$VAR_MYNAME:    * OPENDKIM_CONF_DBNAME_AND_DBUSER"
		LVAR_OPENDKIM_CONF_DBNAME_AND_DBUSER="${CFG_MKINST_MARIADB_MODOBOA_DBS_PREFIX}opendkim"
	fi

	echo "$VAR_MYNAME:    * MODOBOA_CONF_DBPASS"
	local LVAR_MODOBOA_CONF_DBPASS="$(mkinst_generatePassword 32)"
	echo "$VAR_MYNAME:    * AMAVIS_CONF_DBPASS"
	local LVAR_AMAVIS_CONF_DBPASS="$(mkinst_generatePassword 32)"
	echo "$VAR_MYNAME:    * SPAMASSASS_CONF_DBPASS"
	local LVAR_SPAMASSASS_CONF_DBPASS="$(mkinst_generatePassword 32)"
	local LVAR_OPENDKIM_CONF_DBPASS="--"
	if [ "$CFG_MKINST_DEBUG_DISABLE_OPENDKIM" != "true" ]; then
		echo "$VAR_MYNAME:    * OPENDKIM_CONF_DBPASS"
		LVAR_OPENDKIM_CONF_DBPASS="$(mkinst_generatePassword 32)"
	fi

	echo "$VAR_MYNAME:   * Mail-FQDN          : $LVAR_MAILHOSTNAME.$LVAR_MAILDOMAIN"
	echo "$VAR_MYNAME:   * Password ModoInstDb: $LVAR_MODOBOA_INSTALLER_DBPASS"
	echo "$VAR_MYNAME:   * Password ModoDb    : $LVAR_MODOBOA_CONF_DBPASS"
	echo "$VAR_MYNAME:   * Password AmaDb     : $LVAR_AMAVIS_CONF_DBPASS"
	echo "$VAR_MYNAME:   * Password SpamDb    : $LVAR_SPAMASSASS_CONF_DBPASS"
	if [ "$CFG_MKINST_DEBUG_DISABLE_OPENDKIM" != "true" ]; then
		echo "$VAR_MYNAME:   * Password DkimDb    : $LVAR_OPENDKIM_CONF_DBPASS"
	fi

	# ------------------------
	cd "$(mkinst_getBuildPathForBuildTarget "$OPT_CMD_ARG1")" || return 1

	local TMP_DI="$(mkinst_getDockerImageNameAndVersionStringForBuildTarget "$OPT_CMD_ARG1")"

	echo -e "$VAR_MYNAME: Building Docker Image '$TMP_DI'...\n"

	#
	local TMP_DI_PARENT="$(mkinst_getDockerImageNameAndVersionStringForBuildTargetParent "$OPT_CMD_ARG1")"
	local TMP_IMG_N_V_ARR=(${TMP_DI_PARENT//:/ })
	cp "Dockerfile.template" "Dockerfile.tmp" || return 1
	mkinst_replaceVarInFile "Dockerfile.tmp" "IMGNAME" "${TMP_IMG_N_V_ARR[0]}" || return 1
	mkinst_replaceVarInFile "Dockerfile.tmp" "IMGVERS" "${TMP_IMG_N_V_ARR[1]}" || return 1

	#
	[ -f "modoboa-installer-${CFG_MKINST_MODOBOA_INSTALLER_VERSION}-modified.tgz" ] && \
		rm "modoboa-installer-${CFG_MKINST_MODOBOA_INSTALLER_VERSION}-modified.tgz"
	tar czf "modoboa-installer-${CFG_MKINST_MODOBOA_INSTALLER_VERSION}-modified.tgz" \
			"modoboa-installer-${CFG_MKINST_MODOBOA_INSTALLER_VERSION}-modified" || return 1

	local TMP_CLAMAV_CONF_ENABLE=true
	[ "$CFG_MKINST_DEBUG_DISABLE_CLAMAV" = "true" ] && TMP_CLAMAV_CONF_ENABLE=false
	local TMP_OPENDKIM_CONF_ENABLE=true
	[ "$CFG_MKINST_DEBUG_DISABLE_OPENDKIM" = "true" ] && TMP_OPENDKIM_CONF_ENABLE=false

	docker image build \
			--build-arg CF_MAILHOSTNAME="$LVAR_MAILHOSTNAME" \
			--build-arg CF_MAILDOMAIN="$LVAR_MAILDOMAIN" \
			--build-arg CF_TIMEZONE="$CFG_MKINST_TIMEZONE" \
			\
			--build-arg CF_MARIADB_DOCKERHOST="$VAR_DB_FNCS_DC_MARIADB" \
			\
			--build-arg CF_MODOBOA_VERSION="$CFG_MKINST_MODOBOA_VERSION" \
			--build-arg CF_MODOBOA_INSTALLER_DBUSER="$CFG_MKINST_MARIADB_INSTALLER_DBUSER" \
			--build-arg CF_MODOBOA_INSTALLER_DBPASS="$LVAR_MODOBOA_INSTALLER_DBPASS" \
			--build-arg CF_MODOBOA_INSTALLER_VERSION="$CFG_MKINST_MODOBOA_INSTALLER_VERSION" \
			\
			--build-arg CF_MODOBOA_CONF_DBNAME_AND_DBUSER="$LVAR_MODOBOA_CONF_DBNAME_AND_DBUSER" \
			--build-arg CF_MODOBOA_CONF_DBPASS="$LVAR_MODOBOA_CONF_DBPASS" \
			\
			--build-arg CF_AMAVIS_CONF_DBNAME_AND_DBUSER="$LVAR_AMAVIS_CONF_DBNAME_AND_DBUSER" \
			--build-arg CF_AMAVIS_CONF_DBPASS="$LVAR_AMAVIS_CONF_DBPASS" \
			\
			--build-arg CF_SPAMASSASS_CONF_DBNAME_AND_DBUSER="$LVAR_SPAMASSASS_CONF_DBNAME_AND_DBUSER" \
			--build-arg CF_SPAMASSASS_CONF_DBPASS="$LVAR_SPAMASSASS_CONF_DBPASS" \
			\
			--build-arg CF_CLAMAV_CONF_ENABLE="$TMP_CLAMAV_CONF_ENABLE" \
			\
			--build-arg CF_OPENDKIM_CONF_ENABLE="$TMP_OPENDKIM_CONF_ENABLE" \
			--build-arg CF_OPENDKIM_CONF_DBNAME_AND_DBUSER="$LVAR_OPENDKIM_CONF_DBNAME_AND_DBUSER" \
			--build-arg CF_OPENDKIM_CONF_DBPASS="$LVAR_OPENDKIM_CONF_DBPASS" \
			-t "$TMP_DI" \
			-f Dockerfile.tmp \
			.
	local TMP_RES=$?
	rm Dockerfile.tmp
	rm "modoboa-installer-${CFG_MKINST_MODOBOA_INSTALLER_VERSION}-modified.tgz"
	[ $TMP_RES -ne 0 ] && echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr
	return $TMP_RES
}
