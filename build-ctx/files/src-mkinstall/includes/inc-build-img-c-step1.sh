#!/bin/bash

#
# by TS, Mar 2019
#

# @return int EXITCODE
function buildTarget() {
	local TMP_DI="$(mkinst_getDockerImageNameAndVersionStringForBuildTarget "$OPT_CMD_ARG1")"

	echo -e "$VAR_MYNAME: Building Docker Image '$TMP_DI'...\n"

	cd "$CFG_MKINST_PATH_BUILDCTX" || return 1

	docker build \
			--build-arg CF_CPUARCH_DEB_ROOTFS="$(mkinst_getCpuArch debian_rootfs)" \
			-t "$TMP_DI" \
			-f "$(mkinst_getBuildPathForBuildTarget "$OPT_CMD_ARG1")/Dockerfile" \
			.
	local TMP_RES=$?
	[ $TMP_RES -ne 0 ] && echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr

	cd "$VAR_MYDIR" || return 1

	return $TMP_RES
}
