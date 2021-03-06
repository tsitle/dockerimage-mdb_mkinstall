#!/bin/bash

#
# by TS, Mar 2019
#

# @return int EXITCODE
function buildTarget() {
	local TMP_DI="$(mkinst_getDockerImageNameAndVersionStringForBuildTarget "$OPT_CMD_ARG1")"

	local TMP_DI_EXPORT_FN="$(echo -n "$TMP_DI" | tr ":" "-").tgz"

	[ -f "$CFG_MKINST_PATH_BUILDOUTPUT/$TMP_DI_EXPORT_FN" ] && rm "$CFG_MKINST_PATH_BUILDOUTPUT/$TMP_DI_EXPORT_FN"
	[ -d "$CFG_MKINST_PATH_BUILDOUTPUT" ] || {
		mkdir "$CFG_MKINST_PATH_BUILDOUTPUT" || {
			echo "$VAR_MYNAME: Error: Creating directory '$CFG_MKINST_PATH_BUILDOUTPUT' failed. Aborting." >/dev/stderr
			return 1
		}
	}

	echo -e "$VAR_MYNAME: Building Docker Image '$TMP_DI'...\n"

	cd "$CFG_MKINST_PATH_BUILDCTX" || return 1

	docker build \
			--build-arg CF_CPUARCH_S6_OVERLAY="$(mkinst_getCpuArch s6_overlay)" \
			--build-arg CF_CPUARCH_DEB_DIST="$(mkinst_getCpuArch debian_dist)" \
			--build-arg CF_CPUARCH_QEMU="$(mkinst_getCpuArch qemu)" \
			-t "$TMP_DI" \
			-f "$(mkinst_getBuildPathForBuildTarget "$OPT_CMD_ARG1")/Dockerfile" \
			.
	local TMP_RES=$?
	[ $TMP_RES -ne 0 ] && echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr

	cd "$VAR_MYDIR" || return 1

	if [ $TMP_RES -eq 0 ]; then
		echo -e "\n$VAR_MYNAME: Exporting Docker Image to '$CFG_MKINST_PATH_BUILDOUTPUT/$TMP_DI_EXPORT_FN'..."
		docker save "$TMP_DI" | gzip -c > "$VAR_MYDIR/$CFG_MKINST_PATH_BUILDOUTPUT/$TMP_DI_EXPORT_FN"
		TMP_RES=$?
		[ $TMP_RES -ne 0 ] && echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr
	fi

	return $TMP_RES
}
