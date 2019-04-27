#!/bin/bash

#
# by TS, Mar 2019
#

# @return int EXITCODE
function buildTarget() {
	local TMP_DI="$(mkinst_getDockerImageNameAndVersionStringForBuildTarget "$OPT_CMD_ARG1")"
	local TMP_DI_EXPORT_FN="$(echo -n "$TMP_DI" | tr ":" "-").tgz"

	[ -f "$CFG_MKINST_PATH_BUILDOUTPUT/$TMP_DI_EXPORT_FN" ] && rm "$CFG_MKINST_PATH_BUILDOUTPUT/$TMP_DI_EXPORT_FN"

	#
	cd "$(mkinst_getBuildPathForBuildTarget "$OPT_CMD_ARG1")" || return 1

	#
	local TMP_DI_PARENT="$(mkinst_getDockerImageNameAndVersionStringForBuildTargetParent "$OPT_CMD_ARG1")"
	local TMP_IMG_N_V_PAR_ARR=(${TMP_DI_PARENT//:/ })
	cp "Dockerfile.template" "Dockerfile.tmp" || return 1
	mkinst_replaceVarInFile "Dockerfile.tmp" "IMGNAME" "${TMP_IMG_N_V_PAR_ARR[0]}" || return 1
	mkinst_replaceVarInFile "Dockerfile.tmp" "IMGVERS" "${TMP_IMG_N_V_PAR_ARR[1]}" || return 1

	#
	echo -e "$VAR_MYNAME: Building Docker Image '$TMP_DI'...\n"

	docker build \
			-t "$TMP_DI" \
			-f Dockerfile.tmp \
			.
	local TMP_RES=$?
	rm Dockerfile.tmp
	[ $TMP_RES -ne 0 ] && echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr

	if [ $TMP_RES -eq 0 -a "$CFG_MKINST_DEBUG_DONT_EXPORT_FINAL_IMG" != "true" ]; then
		if [ "$CFG_MKINST_DEBUG_PWGENFNC" != "false" -o \
				"$CFG_MKINST_DEBUG_DISABLE_CLAMAV" != "false" -o \
				"$CFG_MKINST_DEBUG_DISABLE_OPENDKIM" != "false" ]; then
			echo -en "\n$VAR_MYNAME: Not exporting Docker Image because "
			[ "$CFG_MKINST_DEBUG_PWGENFNC" != "false" ] && echo -n "CFG_MKINST_DEBUG_PWGENFNC!=false "
			[ "$CFG_MKINST_DEBUG_DISABLE_CLAMAV" != "false" ] && echo -n "CFG_MKINST_DEBUG_DISABLE_CLAMAV!=false "
			[ "$CFG_MKINST_DEBUG_DISABLE_OPENDKIM" != "false" ] && echo -n "CFG_MKINST_DEBUG_DISABLE_OPENDKIM!=false "
			echo
		else
			echo -e "\n$VAR_MYNAME: Exporting Docker Image to '$CFG_MKINST_PATH_BUILDOUTPUT/$TMP_DI_EXPORT_FN'..."
			docker save "$TMP_DI" | gzip -c > "$VAR_MYDIR/$CFG_MKINST_PATH_BUILDOUTPUT/$TMP_DI_EXPORT_FN"
			TMP_RES=$?
			if [ $TMP_RES -eq 0 ]; then
				echo "$VAR_MYNAME: Done."
			else
				echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr
			fi

			if [ $TMP_RES -eq 0 -a "$VAR_TRAPPED_INT" != "true" ]; then
				# remove image and then import the image from file again to eliminate the dependency on the MDB-INSTALL image
				echo -e "$VAR_MYNAME: Removing Docker Image $TMP_DI...\n"
				local TMP_IMG_N_V_ARR=(${TMP_DI//:/ })
				dck_removeDockerImage "${TMP_IMG_N_V_ARR[0]}" "${TMP_IMG_N_V_ARR[1]}"
				TMP_RES=$?
			fi

			if [ $TMP_RES -eq 0 -a "$VAR_TRAPPED_INT" != "true" ]; then
				echo -e "\n$VAR_MYNAME: Importing Docker Image from '$CFG_MKINST_PATH_BUILDOUTPUT/$TMP_DI_EXPORT_FN'..."
				docker load --input "$VAR_MYDIR/$CFG_MKINST_PATH_BUILDOUTPUT/$TMP_DI_EXPORT_FN"
				TMP_RES=$?
				[ $TMP_RES -ne 0 ] && echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr
			fi

			if [ $TMP_RES -eq 0 -a "$VAR_TRAPPED_INT" != "true" ]; then
				if [ "$OPT_CMD_ARG2" != "--no-remove-steps" ]; then
					echo -e "\n$VAR_MYNAME: Removing parent Docker Images..."
					local TMP_REM_BT_PAR="$(mkinst_getBuildTargetParent "$OPT_CMD_ARG1")"
					while [ -n "$TMP_REM_BT_PAR" -a $TMP_RES -eq 0 ]; do
						local TMP_IMG_N_V_PAR="$(mkinst_getDockerImageNameAndVersionStringForBuildTarget "$TMP_REM_BT_PAR")"
						local TMP_IMG_N_V_PAR_ARR=(${TMP_IMG_N_V_PAR//:/ })
						echo -e "$VAR_MYNAME: Removing Docker Image ${TMP_IMG_N_V_PAR_ARR[0]}:${TMP_IMG_N_V_PAR_ARR[1]}...\n"
						dck_removeDockerImage "${TMP_IMG_N_V_PAR_ARR[0]}" "${TMP_IMG_N_V_PAR_ARR[1]}"
						TMP_RES=$?
						TMP_REM_BT_PAR="$(mkinst_getBuildTargetParent "$TMP_REM_BT_PAR")"
					done
					[ $TMP_RES -ne 0 ] && echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr
				fi
			fi
		fi
	fi

	return $TMP_RES
}
