#!/bin/bash

#
# by TS, Mar 2019
#

# @return int EXITCODE
function buildTarget() {
	cd "$(mkinst_getBuildPathForBuildTarget "$OPT_CMD_ARG1")" || return 1

	#
	local TMP_DI_PARENT="$(mkinst_getDockerImageNameAndVersionStringForBuildTargetParent "$OPT_CMD_ARG1")"
	local TMP_IMG_N_V_ARR=(${TMP_DI_PARENT//:/ })
	cp "Dockerfile.template" "Dockerfile.tmp" || return 1
	mkinst_replaceVarInFile "Dockerfile.tmp" "IMGNAME" "${TMP_IMG_N_V_ARR[0]}" || return 1
	mkinst_replaceVarInFile "Dockerfile.tmp" "IMGVERS" "${TMP_IMG_N_V_ARR[1]}" || return 1

	#
	local TMP_DI="$(mkinst_getDockerImageNameAndVersionStringForBuildTarget "$OPT_CMD_ARG1")"

	echo -e "$VAR_MYNAME: Building Docker Image '$TMP_DI'...\n"

	docker build \
			-t "$TMP_DI" \
			-f Dockerfile.tmp \
			.
	local TMP_RES=$?
	rm Dockerfile.tmp
	[ $TMP_RES -ne 0 ] && echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr
	return $TMP_RES
}
