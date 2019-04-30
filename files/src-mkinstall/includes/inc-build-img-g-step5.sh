#!/bin/bash

#
# by TS, Mar 2019
#

# @return int EXITCODE
function buildTarget() {
	local TMP_BUILDPATH_FOR_BT="$(mkinst_getBuildPathForBuildTarget "$OPT_CMD_ARG1")"

	cd "$VAR_MYDIR/$CFG_MKINST_PATH_BUILDCTX/$TMP_BUILDPATH_FOR_BT" || return 1

	#
	local TMP_DI_PARENT="$(mkinst_getDockerImageNameAndVersionStringForBuildTargetParent "$OPT_CMD_ARG1")"
	local TMP_IMG_N_V_ARR=(${TMP_DI_PARENT//:/ })
	cp "Dockerfile.template" "Dockerfile.tmp" || return 1
	mkinst_replaceVarInFile "Dockerfile.tmp" "IMGNAME" "${TMP_IMG_N_V_ARR[0]}" || return 1
	mkinst_replaceVarInFile "Dockerfile.tmp" "IMGVERS" "${TMP_IMG_N_V_ARR[1]}" || return 1

	#
	local TMP_DI="$(mkinst_getDockerImageNameAndVersionStringForBuildTarget "$OPT_CMD_ARG1")"

	echo -e "$VAR_MYNAME: Building Docker Image '$TMP_DI'...\n"

	cd "$VAR_MYDIR/$CFG_MKINST_PATH_BUILDCTX" || return 1

	docker build \
			-t "$TMP_DI" \
			-f "$TMP_BUILDPATH_FOR_BT/Dockerfile.tmp" \
			.
	local TMP_RES=$?
	[ $TMP_RES -ne 0 ] && echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr

	rm "$TMP_BUILDPATH_FOR_BT/Dockerfile.tmp"

	cd "$VAR_MYDIR" || return 1

	return $TMP_RES
}
