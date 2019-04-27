#!/bin/bash

#
# by TS, Mar 2019
#

# @return int EXITCODE
function buildTarget() {
	cd "$(mkinst_getBuildPathForBuildTarget "$OPT_CMD_ARG1")" || return 1

	local TMP_DI="$(mkinst_getDockerImageNameAndVersionStringForBuildTarget "$OPT_CMD_ARG1")"

	echo -e "$VAR_MYNAME: Building Docker Image '$TMP_DI'...\n"

	docker build \
			-t "$TMP_DI" \
			-f Dockerfile.template \
			.
	local TMP_RES=$?
	[ $TMP_RES -ne 0 ] && echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr
	return $TMP_RES
}
