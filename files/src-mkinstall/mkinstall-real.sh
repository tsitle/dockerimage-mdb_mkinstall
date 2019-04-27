#!/bin/bash

#
# by TS, Mar 2019
#

# @param string $1 Path
# @param int $2 Recursion level
#
# @return string Absolute path
function realpath_osx() {
	local TMP_RP_OSX_RES=
	[[ $1 = /* ]] && TMP_RP_OSX_RES="$1" || TMP_RP_OSX_RES="$PWD/${1#./}"

	if [ -h "$TMP_RP_OSX_RES" ]; then
		TMP_RP_OSX_RES="$(readlink "$TMP_RP_OSX_RES")"
		# possible infinite loop...
		local TMP_RP_OSX_RECLEV=$2
		[ -z "$TMP_RP_OSX_RECLEV" ] && TMP_RP_OSX_RECLEV=0
		TMP_RP_OSX_RECLEV=$(( TMP_RP_OSX_RECLEV + 1 ))
		if [ $TMP_RP_OSX_RECLEV -gt 20 ]; then
			# too much recursion
			TMP_RP_OSX_RES="--error--"
		else
			TMP_RP_OSX_RES="$(realpath_osx "$TMP_RP_OSX_RES" $TMP_RP_OSX_RECLEV)"
		fi
	fi
	echo "$TMP_RP_OSX_RES"
}

# @param string $1 Path
#
# @return string Absolute path
function realpath_poly() {
	command -v realpath >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		realpath "$1"
	else
		realpath_osx "$1"
	fi
}

VAR_MYNAME="$(basename "$0")"
VAR_MYDIR="$(realpath_poly "$0")"
VAR_MYDIR="$(dirname "$VAR_MYDIR")"

# ----------------------------------------------------------

cd "$VAR_MYDIR" || exit 1

. "config-mkinstall.sh" || exit 1

. "includes/inc-fnc-db.sh" || exit 1

. "includes/inc-fnc-docker.sh" || exit 1

. "includes/inc-fnc-mkinstall.sh" || exit 1

# ----------------------------------------------------------

mkinst_checkVars || exit 1

# ----------------------------------------------------------

function printUsageAndExit() {
	echo "Usage: $VAR_MYNAME <COMMAND> [ARG]" >/dev/stderr
	echo >/dev/stderr
	echo "Commands:" >/dev/stderr
	echo "  build <BUILD_TARGET>|help [--no-remove-steps]" >/dev/stderr
	echo "    Build one or all Docker Images" >/dev/stderr
	echo "    --no-remove-steps:" >/dev/stderr
	echo "      don't remove the mdb-stepX images after the final image has been build" >/dev/stderr
	echo "  run <BUILD_TARGET>|help" >/dev/stderr
	echo "    Run a Docker Container in interactive mode" >/dev/stderr
	echo "  daemon <BUILD_TARGET>|help" >/dev/stderr
	echo "    Run a Docker Container in daemon mode" >/dev/stderr
	echo "  stopdaemon <BUILD_TARGET>|help" >/dev/stderr
	echo "    Stop a Docker Container that is running in daemon mode" >/dev/stderr
	echo "  removeDockerNet" >/dev/stderr
	echo "    Remove the Docker Network used for the build process" >/dev/stderr
	echo "  clean" >/dev/stderr
	echo "    Remove all Docker Images that may have been built" >/dev/stderr
	echo "    and the Docker Network used for the build process" >/dev/stderr
	exit 1
}

OPT_CMD=""
OPT_CMD_ARG1=""
OPT_CMD_ARG2=""

for TMP_ARG in "$@"; do
	[ "$TMP_ARG" = "-h" -o "$TMP_ARG" = "--help" ] && printUsageAndExit
done

if [ $# -eq 0 -o $# -gt 3 ] || [ $# -eq 1 -a "$1" = "help" ]; then
	printUsageAndExit
fi

if [ "$1" = "build" -o "$1" = "run" -o "$1" = "daemon" -o "$1" = "stopdaemon" ]; then
	OPT_CMD="$1"
	if [ "$1" = "build" ] && [ $# -lt 2 -o $# -gt 3 ]; then
		printUsageAndExit
	elif [ "$1" = "build" ] && [ $# -eq 3 -a "$3" != "--no-remove-steps" ]; then
		printUsageAndExit
	elif [ "$1" != "build" ] && [ $# -ne 2 ]; then
		printUsageAndExit
	fi
	if [ "$2" = "help" ]; then
		echo "Build targets:"
		echo "  all"
		for TMP_BT in $CFG_MKINST_BUILD_TARGETS; do
			echo "  $TMP_BT"
		done
		exit 0
	fi
	TMP_FND=false
	for TMP_BT in $CFG_MKINST_BUILD_TARGETS; do
		if [ "$2" = "all" -o "$TMP_BT" = "$2" ]; then
			TMP_FND=true
			break
		fi
	done
	if [ "$TMP_FND" = "false" ]; then
		echo "$VAR_MYNAME: Error: unknown build target" >/dev/stderr
		exit 1
	fi
	OPT_CMD_ARG1="$2"
	if [ "$1" = "build" ] && [ $# -eq 3 -a "$3" = "--no-remove-steps" ]; then
		OPT_CMD_ARG2="$3"
	fi
elif [ "$1" = "removeDockerNet" -o "$1" = "clean" ]; then
	OPT_CMD="$1"
	if [ $# -ne 1 ]; then
		printUsageAndExit
	fi
else
	echo "$VAR_MYNAME: Error: unknown command" >/dev/stderr
	printUsageAndExit
fi

# ----------------------------------------------------------

VAR_TEMPFILE_PREFIX="$VAR_MYDIR/$CFG_MKINST_PATH_BUILDTEMP/tmp.mkinstall.$$-"

VAR_EXITCODE=0

VAR_CREATED_DOCKERNET=false

VAR_TRAPPED_INT=false

VAR_DB_FNCS_DC_MDB="${CFG_MKINST_DOCK_IMG_STEP1}-$(echo -n "$CFG_MKINST_DOCK_IMG_RELEASE_VERS" | tr -d ".")-btcnt"
VAR_DB_FNCS_DC_MARIADB="$CFG_MKINST_MARIADB_DOCKERCONTAINER"

VAR_DB_FNCS_MARIADB_ROOT_PASS="$CFG_MKINST_MARIADB_ROOT_PASS"

# ----------------------------------------------------------

function _mkinst_trapCallback_int() {
	echo "$VAR_MYNAME: Trapped CTRL-C. Deleting temp files..." >/dev/stderr
	[ -n "$VAR_TEMPFILE_PREFIX" ] && rm "$VAR_TEMPFILE_PREFIX"* 2>/dev/null
	VAR_TRAPPED_INT=true
}

# trap ctrl-c (INTERRUPT signal)
trap _mkinst_trapCallback_int INT

# ----------------------------------------------------------

function _mkinst_removeBuildTimeContainers() {
	local TMP_RUNVER="$(echo -n "$CFG_MKINST_DOCK_IMG_RELEASE_VERS" | tr -d ".")"

	mkinst_removeOneDockerContainer "$VAR_DB_FNCS_DC_MDB"
	mkinst_removeOneDockerContainer "${CFG_MKINST_DOCK_IMG_STEP2}-${TMP_RUNVER}-cnt"
	mkinst_removeOneDockerContainer "${CFG_MKINST_DOCK_IMG_STEP3}-${TMP_RUNVER}-cnt"
	mkinst_removeOneDockerContainer "${CFG_MKINST_DOCK_IMG_STEP6}-${TMP_RUNVER}-btcnt"
	mkinst_removeOneDockerContainer "$VAR_DB_FNCS_DC_MARIADB"
	return 0
}

# ----------------------------------------------------------

TMP_SCR=""
if [ "$1" = "build" -o "$1" = "run" -o "$1" = "daemon" -o "$1" = "stopdaemon" ]; then
	if [ "$OPT_CMD_ARG1" = "all" ]; then
		TMP_SCR="-"
	elif [ "$OPT_CMD_ARG1" = "$CFG_MKINST_DOCK_IMG_NGINX" ]; then
		TMP_SCR="$CFG_MKINST_DOCK_IMG_NGINX_SRCDIR"
	elif [ "$OPT_CMD_ARG1" = "$CFG_MKINST_DOCK_IMG_MARIADB" ]; then
		TMP_SCR="$CFG_MKINST_DOCK_IMG_MARIADB_SRCDIR"
	elif [ "$OPT_CMD_ARG1" = "$CFG_MKINST_DOCK_IMG_STEP1" ]; then
		TMP_SCR="$CFG_MKINST_DOCK_IMG_STEP1_SRCDIR"
	elif [ "$OPT_CMD_ARG1" = "$CFG_MKINST_DOCK_IMG_STEP2" ]; then
		TMP_SCR="$CFG_MKINST_DOCK_IMG_STEP2_SRCDIR"
	elif [ "$OPT_CMD_ARG1" = "$CFG_MKINST_DOCK_IMG_STEP3" ]; then
		TMP_SCR="$CFG_MKINST_DOCK_IMG_STEP3_SRCDIR"
	elif [ "$OPT_CMD_ARG1" = "$CFG_MKINST_DOCK_IMG_STEP4" ]; then
		TMP_SCR="$CFG_MKINST_DOCK_IMG_STEP4_SRCDIR"
	elif [ "$OPT_CMD_ARG1" = "$CFG_MKINST_DOCK_IMG_STEP5" ]; then
		TMP_SCR="$CFG_MKINST_DOCK_IMG_STEP5_SRCDIR"
	elif [ "$OPT_CMD_ARG1" = "$CFG_MKINST_DOCK_IMG_STEP6" ]; then
		TMP_SCR="$CFG_MKINST_DOCK_IMG_STEP6_SRCDIR"
	else
		echo "$VAR_MYNAME: Error: unknown build target (#2)" >/dev/stderr
		exit 1
	fi
fi

if [ "$OPT_CMD" = "build" ]; then
	if [ "$OPT_CMD_ARG1" = "all" ]; then
		echo "$VAR_MYNAME: Building all targets..."
		for TMP_BT in $CFG_MKINST_BUILD_TARGETS; do
			mkinst_batchBuildOneImageIfNotExists "$TMP_BT" || exit 1
		done
		echo -e "\n$VAR_MYNAME: Done building all targets"
	else
		[ -d "$CFG_MKINST_PATH_BUILDTEMP" ] || {
			mkdir "$CFG_MKINST_PATH_BUILDTEMP" || {
				echo "$VAR_MYNAME: Error: Creating directory '$CFG_MKINST_PATH_BUILDTEMP' failed. Aborting." >/dev/stderr
				exit 1
			}
		}

		_mkinst_removeBuildTimeContainers
		mkinst_removeDockerImages "$OPT_CMD_ARG1" || exit 1

		. "$VAR_MYDIR/includes/inc-build-${TMP_SCR}.sh" || exit 1

		mkinst_createDockerNet || exit 1
		buildTarget
		VAR_EXITCODE=$?
	fi
elif [ "$OPT_CMD" = "run" ]; then
	[ "$OPT_CMD_ARG1" != "$CFG_MKINST_DOCK_IMG_MARIADB" ] && TMP_SCR="img_default"
	. "$VAR_MYDIR/includes/inc-run-${TMP_SCR}.sh" || exit 1

	mkinst_createDockerNet || exit 1
	runInteractiveContainer
	VAR_EXITCODE=$?
elif [ "$OPT_CMD" = "daemon" ]; then
	[ "$OPT_CMD_ARG1" != "$CFG_MKINST_DOCK_IMG_MARIADB" ] && TMP_SCR="img_default"
	. "$VAR_MYDIR/includes/inc-run-${TMP_SCR}.sh" || exit 1

	mkinst_createDockerNet || exit 1
	runDaemonContainer
	VAR_EXITCODE=$?
elif [ "$OPT_CMD" = "stopdaemon" ]; then
	[ "$OPT_CMD_ARG1" != "$CFG_MKINST_DOCK_IMG_MARIADB" ] && TMP_SCR="img_default"
	. "$VAR_MYDIR/includes/inc-run-${TMP_SCR}.sh" || exit 1

	stopDaemonContainer
elif [ "$OPT_CMD" = "removeDockerNet" ]; then
	mkinst_removeDockerNet
elif [ "$OPT_CMD" = "clean" ]; then
	echo "$VAR_MYNAME: Cleaning up..."

	mkinst_removeDockerImages "$CFG_MKINST_DOCK_IMG_NGINX" || exit 1
	mkinst_removeDockerNet
	[ -n "$CFG_MKINST_PATH_BUILDTEMP" -a \
			-d "$CFG_MKINST_PATH_BUILDTEMP" ] &&
		rm -r "$CFG_MKINST_PATH_BUILDTEMP"/* 2>/dev/null
else
	echo "$VAR_MYNAME: Error: unknown command (#2)" >/dev/stderr
	exit 1
fi

#
if [ "$OPT_CMD" != "daemon" -a "$OPT_CMD" != "removeDockerNet" ]; then
	_mkinst_removeBuildTimeContainers
	[ "$VAR_CREATED_DOCKERNET" = "true" ] && mkinst_removeDockerNet
fi

#
[ $VAR_EXITCODE -ne 0 ] && {
	docker container prune
	docker image prune
	docker volume prune
	docker network prune
}

exit $VAR_EXITCODE
