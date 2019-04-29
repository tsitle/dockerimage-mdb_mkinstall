#!/bin/bash

#
# by TS, Mar 2019
#

# Outputs CPU architecture string
#
# @return int EXITCODE
function mkinst_getCpuArch() {
	case "$(uname -m)" in
		x86_64*)
			echo -n "x86_64"
			;;
		aarch64)
			echo -n "arm_64"
			;;
		armv7*)
			echo -n "arm_32"
			;;
		*)
			echo "$VAR_MYNAME: Error: Unknown CPU architecture '$(uname -m)'" >/dev/stderr
			return 1
			;;
	esac
	return 0
}

# Outputs string
#
# @param string $1 Input string
# @param string $2 Variable name
# @param string $3 Value
#
# @return void
function mkinst_replaceVarInString() {
	echo -n "$1" | sed -e "s/<$2>/$3/g"
}

# @param string $1 Input filename
# @param string $2 Variable name
# @param string $3 Value
#
# @return int EXITCODE
function mkinst_replaceVarInFile() {
	local TMP_SED_VAL="$(echo -n "$3" | sed -e 's/\//\\\//g')"
	case "$OSTYPE" in
		linux*)
			sed -e "s/<$2>/$TMP_SED_VAL/g" -i "$1" || return 1
			;;
		darwin*)
			sed -e "s/<$2>/$TMP_SED_VAL/g" -i '' "$1" || return 1
			;;
		*)
			echo "$VAR_MYNAME: Error: Unknown OSTYPE '$OSTYPE'" >/dev/stderr
			return 1
			;;
	esac
	return 0
}

# @param string $1 Variable name
#
# @return int EXITCODE
function mkinst_checkVars_isBool() {
	([ -z "${!1}" ] || \
			! ( [ "${!1}" = "true" ] || [ "${!1}" = "false" ])) && {
		echo "$VAR_MYNAME: Error: ${1} empty or not true|false. Aborting." >/dev/stderr
		return 1
	}
	return 0
}

# @param string $1 Variable name
#
# @return int EXITCODE
function mkinst_checkVars_isEmpty() {
	[ -z "${!1}" ] && {
		echo "$VAR_MYNAME: Error: ${1} empty. Aborting." >/dev/stderr
		return 0
	}
	return 1
}

# @return int EXITCODE
function mkinst_checkVars() {
	mkinst_checkVars_isEmpty "CFG_MKINST_DOCK_IMG_RELEASE_VERS" && return 1
	if [ "$CFG_MKINST_DOCK_IMG_RELEASE_VERS" != "latest" ]; then
		echo -n "$CFG_MKINST_DOCK_IMG_RELEASE_VERS" | grep -q -E "^[0-9]*[\.][0-9]*$" || {
			echo "$VAR_MYNAME: Error: Invalid value of CFG_MKINST_DOCK_IMG_RELEASE_VERS. Aborting." >/dev/stderr
			return 1
		}
	fi
	mkinst_checkVars_isEmpty "CFG_MKINST_MODOBOA_VERSION" && return 1
	mkinst_checkVars_isEmpty "CFG_MKINST_MODOBOA_INSTALLER_VERSION" && return 1

	mkinst_checkVars_isEmpty "CFG_MKINST_PATH_BUILDTEMP" && return 1
	mkinst_checkVars_isEmpty "CFG_MKINST_PATH_BUILDOUTPUT" && return 1

	mkinst_checkVars_isEmpty "CFG_MKINST_DOCK_NET_NAME" && return 1
	echo -n "$CFG_MKINST_DOCK_NET_PREFIX" | grep -q -E "^([0-9]{1,3}[\.]){2}[0-9]{1,3}$" || {
		echo "$VAR_MYNAME: Error: Invalid value of CFG_MKINST_DOCK_NET_PREFIX. Aborting." >/dev/stderr
		return 1
	}

	mkinst_checkVars_isEmpty "CFG_MKINST_TIMEZONE" && return 1

	mkinst_checkVars_isEmpty "CFG_MKINST_MARIADB_ROOT_PASS" && return 1
	mkinst_checkVars_isEmpty "CFG_MKINST_MARIADB_SERVER_PORT_ON_HOST" && return 1
	mkinst_checkVars_isEmpty "CFG_MKINST_MARIADB_DOCKERCONTAINER" && return 1
	mkinst_checkVars_isEmpty "CFG_MKINST_MARIADB_MNTPOINT" && return 1
	mkinst_checkVars_isEmpty "CFG_MKINST_MARIADB_MODO_FN_TEMPL" && return 1
	mkinst_checkVars_isEmpty "CFG_MKINST_MARIADB_AMAV_FN_TEMPL" && return 1
	mkinst_checkVars_isEmpty "CFG_MKINST_MARIADB_SPAM_FN_TEMPL" && return 1
	mkinst_checkVars_isEmpty "CFG_MKINST_MARIADB_INSTALLER_DBUSER" && return 1
	[ "$CFG_MKINST_MARIADB_INSTALLER_DBUSER" = "root" ] && {
		echo "$VAR_MYNAME: Error: CFG_MKINST_MARIADB_INSTALLER_DBUSER may not be 'root'. Aborting." >/dev/stderr
		return 1
	}
	mkinst_checkVars_isEmpty "CFG_MKINST_MARIADB_MODOBOA_DBS_PREFIX" && return 1
	mkinst_checkVars_isEmpty "CFG_MKINST_MARIADB_ACCESS_ALLOWED_SOURCE_NETWORK" && return 1

	mkinst_checkVars_isEmpty "CFG_MKINST_CUSTOMIZE_MODO_LCONF_PY_SCRIPT_FN" && return 1

	mkinst_checkVars_isBool "CFG_MKINST_DEBUG_DONT_EXPORT_FINAL_IMG" || return 1
	mkinst_checkVars_isBool "CFG_MKINST_DEBUG_PWGENFNC" || return 1
	mkinst_checkVars_isBool "CFG_MKINST_DEBUG_DISABLE_CLAMAV" || return 1
	mkinst_checkVars_isBool "CFG_MKINST_DEBUG_DISABLE_OPENDKIM" || return 1

	return 0
}

# Outputs string like "NAME-VERSION-cnt" for build target
#
# @param $1 string Build Target
#
# @return void
function mkinst_getDockerContainerNameStringForBuildTarget() {
	echo "${1}-$(echo -n "$CFG_MKINST_DOCK_IMG_RELEASE_VERS" | tr -d ".")-cnt"
}

# Outputs string like "NAME:VERSION" for build target
#
# @param $1 string Build Target
#
# @return void
function mkinst_getDockerImageNameAndVersionStringForBuildTarget() {
	local TMP_OUTP="${1}-$(mkinst_getCpuArch):${CFG_MKINST_DOCK_IMG_RELEASE_VERS}"
	if [ "$1" = "$CFG_MKINST_DOCK_IMG_NGINX" -o \
			"$1" = "$CFG_MKINST_DOCK_IMG_MARIADB" -o \
			"$1" = "$CFG_MKINST_DOCK_IMG_STEP1" -o \
			"$1" = "$CFG_MKINST_DOCK_IMG_STEP2" -o \
			"$1" = "$CFG_MKINST_DOCK_IMG_STEP3" -o \
			"$1" = "$CFG_MKINST_DOCK_IMG_STEP4" -o \
			"$1" = "$CFG_MKINST_DOCK_IMG_STEP5" -o \
			"$1" = "$CFG_MKINST_DOCK_IMG_STEP6" ]; then
		echo -n "$TMP_OUTP"
	else
		echo -n ""
	fi
}

# Outputs string like "BUILDTARGET" for parent of build target
#
# @param $1 string Build Target
#
# @return void
function mkinst_getBuildTargetParent() {
	if [ "$1" = "$CFG_MKINST_DOCK_IMG_STEP2" ]; then
		echo -n "$CFG_MKINST_DOCK_IMG_STEP1"
	elif [ "$1" = "$CFG_MKINST_DOCK_IMG_STEP3" ]; then
		echo -n "$CFG_MKINST_DOCK_IMG_STEP2"
	elif [ "$1" = "$CFG_MKINST_DOCK_IMG_STEP4" ]; then
		echo -n "$CFG_MKINST_DOCK_IMG_STEP3"
	elif [ "$1" = "$CFG_MKINST_DOCK_IMG_STEP5" ]; then
		echo -n "$CFG_MKINST_DOCK_IMG_STEP4"
	elif [ "$1" = "$CFG_MKINST_DOCK_IMG_STEP6" ]; then
		echo -n "$CFG_MKINST_DOCK_IMG_STEP5"
	else
		echo -n ""
	fi
}

# Outputs string like "NAME:VERSION" for parent of build target
#
# @param $1 string Build Target
#
# @return void
function mkinst_getDockerImageNameAndVersionStringForBuildTargetParent() {
	local TMP_PAR_BT="$(mkinst_getBuildTargetParent "$1")"
	if [ -z "$TMP_PAR_BT" ]; then
		echo -n ""
	else
		mkinst_getDockerImageNameAndVersionStringForBuildTarget "$TMP_PAR_BT"
	fi
}

# Outputs string like "NAME:VERSION" for build target
#
# @param $1 string Build Target
#
# @return void
function mkinst_getBuildPathForBuildTarget() {
	if [ "$1" = "$CFG_MKINST_DOCK_IMG_NGINX" ]; then
		echo -n "$CFG_MKINST_DOCK_IMG_NGINX_SRCDIR"
	elif [ "$1" = "$CFG_MKINST_DOCK_IMG_MARIADB" ]; then
		echo -n "$CFG_MKINST_DOCK_IMG_MARIADB_SRCDIR"
	elif [ "$1" = "$CFG_MKINST_DOCK_IMG_STEP1" ]; then
		echo -n "$CFG_MKINST_DOCK_IMG_STEP1_SRCDIR"
	elif [ "$1" = "$CFG_MKINST_DOCK_IMG_STEP2" ]; then
		echo -n "$CFG_MKINST_DOCK_IMG_STEP2_SRCDIR"
	elif [ "$1" = "$CFG_MKINST_DOCK_IMG_STEP3" ]; then
		echo -n "$CFG_MKINST_DOCK_IMG_STEP3_SRCDIR"
	elif [ "$1" = "$CFG_MKINST_DOCK_IMG_STEP4" ]; then
		echo -n "$CFG_MKINST_DOCK_IMG_STEP4_SRCDIR"
	elif [ "$1" = "$CFG_MKINST_DOCK_IMG_STEP5" ]; then
		echo -n "$CFG_MKINST_DOCK_IMG_STEP5_SRCDIR"
	elif [ "$1" = "$CFG_MKINST_DOCK_IMG_STEP6" ]; then
		echo -n "$CFG_MKINST_DOCK_IMG_STEP6_SRCDIR"
	else
		echo -n ""
	fi
}

# @param $1 string Build Target
#
# @return int EXITCODE
function mkinst_batchBuildOneImageIfNotExists() {
	[ -z "$1" ] && {
		echo "$VAR_MYNAME: Error: mkinst_batchBuildOneImageIfNotExists(): Empty param #1. Aborting." >/dev/stderr
		return 1
	}

	local TMP_IMG_N_V="$(mkinst_getDockerImageNameAndVersionStringForBuildTarget "$1")"
	local TMP_IMG_N_V_ARR=(${TMP_IMG_N_V//:/ })
	dck_getDoesDockerImageExist "${TMP_IMG_N_V_ARR[0]}" "${TMP_IMG_N_V_ARR[1]}"
	if [ $? -eq 0 ]; then
		echo "$VAR_MYNAME: Build target $1 already exists"
	else
		echo -e "\n$VAR_MYNAME: Building target $1...\n"
		"$VAR_MYDIR/$VAR_MYNAME" build "$1" $OPT_CMD_ARG2 || return 1
	fi
	return 0
}

# @param $1 string Container Name
#
# @return int EXITCODE
function mkinst_removeOneDockerContainer() {
	[ -z "$1" ] && {
		echo "$VAR_MYNAME: Error: mkinst_removeOneDockerContainer(): Empty param #1. Aborting." >/dev/stderr
		return 1
	}

	dck_getDoesDockerContainerAlreadyExist "$1" || return 0
	dck_getDoesDockerContainerIsRunning "$1"
	if [ $? -eq 0 ]; then
		echo "$VAR_MYNAME: Stopping Docker Container '$1'..."
		docker container stop "$1"
		[ $? -ne 0 ] && {
			echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr
			return 1
		}
		sleep 1
	fi
	dck_getDoesDockerContainerAlreadyExist "$1"
	if [ $? -eq 0 ]; then
		echo "$VAR_MYNAME: Removing Docker Container '$1'..."
		sleep 1
		docker container rm "$1"
		[ $? -ne 0 ] && {
			echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr
			return 1
		}
	fi
	return 0
}

# @param $1 string Build Target
#
# @return int EXITCODE
function mkinst_removeDockerImages() {
	[ -z "$1" ] && {
		echo "$VAR_MYNAME: Error: mkinst_removeDockerImages(): Empty param #1. Aborting." >/dev/stderr
		return 1
	}

	local TMP_RM=""

	# add child images
	if [ "$1" != "$CFG_MKINST_DOCK_IMG_STEP6" ]; then
		TMP_RM="$TMP_RM $(mkinst_getDockerImageNameAndVersionStringForBuildTarget "$CFG_MKINST_DOCK_IMG_STEP6")"
		if [ "$1" != "$CFG_MKINST_DOCK_IMG_STEP5" ]; then
			TMP_RM="$TMP_RM $(mkinst_getDockerImageNameAndVersionStringForBuildTarget "$CFG_MKINST_DOCK_IMG_STEP5")"
			if [ "$1" != "$CFG_MKINST_DOCK_IMG_STEP4" ]; then
				TMP_RM="$TMP_RM $(mkinst_getDockerImageNameAndVersionStringForBuildTarget "$CFG_MKINST_DOCK_IMG_STEP4")"
				if [ "$1" != "$CFG_MKINST_DOCK_IMG_STEP3" ]; then
					TMP_RM="$TMP_RM $(mkinst_getDockerImageNameAndVersionStringForBuildTarget "$CFG_MKINST_DOCK_IMG_STEP3")"
					if [ "$1" != "$CFG_MKINST_DOCK_IMG_STEP2" ]; then
						TMP_RM="$TMP_RM $(mkinst_getDockerImageNameAndVersionStringForBuildTarget "$CFG_MKINST_DOCK_IMG_STEP2")"
						if [ "$1" != "$CFG_MKINST_DOCK_IMG_STEP1" ]; then
							TMP_RM="$TMP_RM $(mkinst_getDockerImageNameAndVersionStringForBuildTarget "$CFG_MKINST_DOCK_IMG_STEP1")"
							if [ "$1" != "$CFG_MKINST_DOCK_IMG_MARIADB" ]; then
								TMP_RM="$TMP_RM $(mkinst_getDockerImageNameAndVersionStringForBuildTarget "$CFG_MKINST_DOCK_IMG_MARIADB")"
							fi
						fi
					fi
				fi
			fi
		fi
	fi

	# add current image
	TMP_RM="$TMP_RM $(mkinst_getDockerImageNameAndVersionStringForBuildTarget "$1")"

	#
	local TMP_RES=0
	for TMP_IMG_TO_RM in $TMP_RM; do
		[ -z "$TMP_IMG_TO_RM" ] && continue
		local TMP_IMG_N_V_ARR=(${TMP_IMG_TO_RM//:/ })
		dck_getDoesDockerImageExist "${TMP_IMG_N_V_ARR[0]}" "${TMP_IMG_N_V_ARR[1]}"
		if [ $? -eq 0 ]; then
			echo -e "$VAR_MYNAME: Removing Docker Image ${TMP_IMG_N_V_ARR[0]}:${TMP_IMG_N_V_ARR[1]}...\n"
			dck_removeDockerImage "${TMP_IMG_N_V_ARR[0]}" "${TMP_IMG_N_V_ARR[1]}"
			TMP_RES=$?
			[ $TMP_RES -eq 1 ] && TMP_RES=0
			[ $TMP_RES -ne 0 ] && {
				echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr
				break
			}
			echo
		fi
	done
	return $TMP_RES
}

# @return int EXITCODE
function mkinst_createDockerNet() {
	docker network ls | grep -q " $CFG_MKINST_DOCK_NET_NAME " || {
		echo "$VAR_MYNAME: Creating Docker Network $CFG_MKINST_DOCK_NET_NAME..."
		docker network create -d bridge --subnet ${CFG_MKINST_DOCK_NET_PREFIX}.0/24 \
				--gateway ${CFG_MKINST_DOCK_NET_PREFIX}.1 $CFG_MKINST_DOCK_NET_NAME || {
			echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr
			return 1
		}
	}
	return 0
}

# @return int EXITCODE
function mkinst_removeDockerNet() {
	[ -z "$CFG_MKINST_DOCK_NET_NAME" ] && {
		echo "$VAR_MYNAME: Error: mkinst_removeDockerNet(): Empty CFG_MKINST_DOCK_NET_NAME. Aborting." >/dev/stderr
		return 1
	}

	docker network ls | grep -q " $CFG_MKINST_DOCK_NET_NAME " && {
		echo "$VAR_MYNAME: Removing Docker Network $CFG_MKINST_DOCK_NET_NAME..."
		docker network rm $CFG_MKINST_DOCK_NET_NAME || {
			echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr
			return 1
		}
	}
	return 0
}

# Outputs a generated random password
#
# @param int $1 optional: MAX_LENGTH
#
# @return int EXITCODE
function mkinst_generatePassword() {
	local TMP_MAXLEN="$1"
	[ -z "$TMP_MAXLEN" ] && TMP_MAXLEN=64

	local TMP_RUNVER="$(echo -n "$CFG_MKINST_DOCK_IMG_RELEASE_VERS" | tr -d ".")"
	local TMP_GPW_DC="${CFG_MKINST_DOCK_IMG_STEP1}-${TMP_RUNVER}-btcnt"
	local TMP_RUNDI="$(mkinst_getDockerImageNameAndVersionStringForBuildTarget "$CFG_MKINST_DOCK_IMG_STEP1")"

	# we need to start the container as daemon since it will print some logs upon start
	docker run \
			--name "$TMP_GPW_DC" \
			--rm \
			-d \
			-it \
			"$TMP_RUNDI" \
			/bin/bash >/dev/null
	if [ $? -ne 0 ]; then
		echo "$VAR_MYNAME: Error: Could not start Docker Container '$TMP_GPW_DC'. Aborting." >/dev/stderr
		return 1
	fi
	# now we can execute commands without stdout/stderr being polluted
	docker exec -t "$TMP_GPW_DC" \
			/root/pwgen.sh "$TMP_MAXLEN" "$CFG_MKINST_DEBUG_PWGENFNC"
	local TMP_RES=$?
	#
	docker container stop "$TMP_GPW_DC" >/dev/null 2>&1
	return $TMP_RES
}

# @param string $1 Build Target
#
# @return int EXITCODE
function mkinst_runDockerContainer_interactive() {
	local TMP_DI_INTER="$(mkinst_getDockerImageNameAndVersionStringForBuildTarget "$1")"

	echo -e "\n$VAR_MYNAME: Starting Docker Container for Image '$TMP_DI_INTER' in interactive mode..."
	docker run \
			--rm \
			-it \
			--network="$CFG_MKINST_DOCK_NET_NAME" \
			"$TMP_DI_INTER" \
			/bin/bash
	echo -e "\n$VAR_MYNAME: Docker Container for '$TMP_DI_INTER' stopped"
	return 0
}

# @param string $1 Build Target
# @param string $2 Docker Container Name
#
# @return int EXITCODE
function mkinst_runDockerContainer_daemon() {
	local TMP_DI_DAEMON="$(mkinst_getDockerImageNameAndVersionStringForBuildTarget "$1")"
	local TMP_DC_DAEMON="$2"

	[ -z "$TMP_DC_DAEMON" ] && {
		echo "$VAR_MYNAME: Error: Argument #2 missing. Aborting." >/dev/stderr
		return 1
	}

	echo -e "\n$VAR_MYNAME: Starting Docker Container '$TMP_DC_DAEMON' in background..."
	docker run \
			--rm \
			-d \
			-i \
			--network="$CFG_MKINST_DOCK_NET_NAME" \
			--name "$TMP_DC_DAEMON" \
			"$TMP_DI_DAEMON" \
			/bin/bash
	if [ $? -ne 0 ]; then
		echo "$VAR_MYNAME: Error: Could not start Docker Container '$TMP_DC_DAEMON' in background. Aborting." >/dev/stderr
		return 1
	fi
	echo "$VAR_MYNAME: Docker Container '$TMP_DC_DAEMON' running"
	return 0
}

# @return int EXITCODE
function mkinst_runDockerContainer_daemon_dbServer() {
	local TMP_DI_MARIADB="$(mkinst_getDockerImageNameAndVersionStringForBuildTarget "$CFG_MKINST_DOCK_IMG_MARIADB")"

	local TMP_MP_BASE="${CF_MKINST_MOUNTPOINTS_BASE_ON_HOST:-$VAR_MYDIR}"
	echo -e "\n$VAR_MYNAME: Starting DB-Server '$VAR_DB_FNCS_DC_MARIADB' (mpBase='$TMP_MP_BASE')..."
	docker run \
			--rm \
			-d \
			--network="$CFG_MKINST_DOCK_NET_NAME" \
			--name "$VAR_DB_FNCS_DC_MARIADB" \
			-v "$TMP_MP_BASE/$CFG_MKINST_PATH_BUILDTEMP/$CFG_MKINST_MARIADB_MNTPOINT":/var/lib/mysql:delegated \
			-e MYSQL_ROOT_PASSWORD="$VAR_DB_FNCS_MARIADB_ROOT_PASS" \
			"$TMP_DI_MARIADB"
	# to access the DB-Server from the host add this line to the arguments above:
	#		-p ${CFG_MKINST_MARIADB_SERVER_PORT_ON_HOST}:3306 \
}

# @return int EXITCODE
function mkinst_checkDbConnection() {
	dck_getDoesDockerContainerAlreadyExist "$VAR_DB_FNCS_DC_MDB"
	if [ $? -ne 0 ]; then
		mkinst_runDockerContainer_daemon "$CFG_MKINST_DOCK_IMG_STEP1" "$VAR_DB_FNCS_DC_MDB" || return 1
	fi

	#
	echo -e "\n$VAR_MYNAME: Starting DB-Server ($VAR_DB_FNCS_DC_MARIADB)..."

	if [ ! -d "$VAR_MYDIR/$CFG_MKINST_PATH_BUILDTEMP" ]; then
		mkdir "$VAR_MYDIR/$CFG_MKINST_PATH_BUILDTEMP" || {
			echo "$VAR_MYNAME: Error: Creating directory '$CFG_MKINST_PATH_BUILDTEMP' failed. Aborting." >/dev/stderr
			return 1
		}
	fi

	mkinst_runDockerContainer_daemon_dbServer
	if [ $? -ne 0 ]; then
		echo "$VAR_MYNAME: Error: Starting DB-Server failed. Aborting." >/dev/stderr
		return 1
	fi
	echo -e "$VAR_MYNAME: DB-Server started. Waiting 5s..."
	sleep 5

	local TMP_WAIT_CNT=0
	while [ $TMP_WAIT_CNT -lt 100 ]; do
		[ "$VAR_TRAPPED_INT" = "true" ] && {
			TMP_WAIT_CNT=100
			break
		}

		dck_getDoesDockerContainerIsRunning "$VAR_DB_FNCS_DC_MARIADB"
		if [ $? -ne 0 ]; then
			echo "$VAR_MYNAME: Error: DB-Server stopped running. Aborting." >/dev/stderr
			return 1
		fi

		db_checkDbConnection && break
		TMP_WAIT_CNT=$(( TMP_WAIT_CNT + 1 ))
		echo "$VAR_MYNAME: DB-Server not ready yet. Waiting 5s..."
		sleep 5
	done
	if [ $TMP_WAIT_CNT -eq 100 ]; then
		echo "$VAR_MYNAME: Error: Could not connect to DB-Server. Aborting." >/dev/stderr
		return 1
	fi
	echo -e "\n$VAR_MYNAME: Connection to DB-Server OK\n"
	return 0
}

# @return int EXITCODE
function mkinst_stopDbServer() {
	echo "$VAR_MYNAME: Stopping DB-Server..."
	docker container stop "$VAR_DB_FNCS_DC_MARIADB"
	if [ $? -ne 0 ]; then
		echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr
		return 1
	fi
	return 0
}

# Outputs the value of the ENV variable
#
# @param string $1 Docker Container Name
# @param string $2 Name of variable
#
# @return int EXITCODE
function mkinst_getEnvVarFromDockerContainer() {
	docker exec \
		"$1" \
		/bin/bash -c "(echo -n "\$$2")"
	if [ $? -ne 0 ]; then
		echo "$VAR_MYNAME: Error: Could not read ENV var '$2' from Docker Container '$1'. Aborting." >/dev/stderr
		return 1
	fi
	return 0
}
