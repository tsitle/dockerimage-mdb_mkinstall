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
	mkinst_runDockerContainer_daemon_dbServer
}

# @return int EXITCODE
function stopDaemonContainer() {
	mkinst_removeOneDockerContainer "$VAR_DB_FNCS_DC_MARIADB"
}
