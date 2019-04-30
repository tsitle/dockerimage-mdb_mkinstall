#!/bin/bash

#
# by TS, Mar 2019
#

# @return int EXITCODE
function runInteractiveContainer() {
	mkinst_runDockerContainer_interactive "$OPT_CMD_ARG1"
}

# @return int EXITCODE
function runDaemonContainer() {
	local TMP_DC="$(mkinst_getDockerContainerNameStringForBuildTarget "${OPT_CMD_ARG1}")"

	mkinst_runDockerContainer_daemon "$OPT_CMD_ARG1" "$TMP_DC"
}

# @return int EXITCODE
function stopDaemonContainer() {
	local TMP_DC="$(mkinst_getDockerContainerNameStringForBuildTarget "${OPT_CMD_ARG1}")"

	mkinst_removeOneDockerContainer "$TMP_DC"
}
