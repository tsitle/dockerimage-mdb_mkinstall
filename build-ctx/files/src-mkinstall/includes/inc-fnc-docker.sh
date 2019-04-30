#!/bin/bash

#
# by TS, Jan 2019
#

# @returns string Whitespace-separated list of all Docker Containers
function dck__getDockerContainerAll() {
	# get last word (delimiter is whitespace)
	docker container ls -a | grep -v "^CONTAINER" | sed 's/.* //'
}

# @returns string Whitespace-separated list with running Docker Containers only
function dck__getDockerContainerRunning() {
	# get last word (delimiter is whitespace)
	docker container ls | grep -v "^CONTAINER" | sed 's/.* //'
}

# @param string $1 Docker Container name
#
# @returns int If Docker Container exists 0, otherwise 1
function dck_getDoesDockerContainerAlreadyExist() {
	for TMP_DFNCS_DCONT in `dck__getDockerContainerAll`; do
		if [ "$TMP_DFNCS_DCONT" = "$1" ]; then
			return 0
		fi
	done
	return 1
}

# @param string $1 Docker Container name
#
# @returns int If Docker Container is running 0, otherwise 1
function dck_getDoesDockerContainerIsRunning() {
	for TMP_DFNCS_DCONT in `dck__getDockerContainerRunning`; do
		if [ "$TMP_DFNCS_DCONT" = "$1" ]; then
			return 0
		fi
	done
	return 1
}

# @param string $1 Docker Image name
# @param string $2 optional: Docker Image version
#
# @returns int If Docker Image exists 0, otherwise 1
function dck_getDoesDockerImageExist() {
	local TMP_DFNCS_SEARCH="$1"
	[ -n "$2" ] && TMP_DFNCS_SEARCH="$TMP_DFNCS_SEARCH:$2"
	local TMP_AWK="$(echo -n "$1" | sed -e 's/\//\\\//g')"
	local TMP_IMGID="$(docker image ls "$TMP_DFNCS_SEARCH" | awk '/^'$TMP_AWK' / { print $3 }')"
	[ -n "$TMP_IMGID" ] && return 0 || return 1
}

# Outputs the Docker Image ID
#
# @param string $1 Docker Image name
# @param string $2 optional: Docker Image version
#
# @returns void
function dck_getDockerImageId() {
	local TMP_DFNCS_SEARCH="$1"
	[ -n "$2" ] && TMP_DFNCS_SEARCH="$TMP_DFNCS_SEARCH:$2"
	local TMP_AWK="$(echo -n "$1" | sed -e 's/\//\\\//g')"
	local TMP_IMGID="$(docker image ls "$TMP_DFNCS_SEARCH" | awk '/^'$TMP_AWK' / { print $3 }')"
	echo -n "$TMP_IMGID"
}

# @param string $1 Docker Image name
# @param string $2 optional: Docker Image version
#
# @returns int If Docker Image could be removed 0, if Docker Image did not exist 1, otherwise 2
function dck_removeDockerImage() {
	local TMP_IMGID="$(dck_getDockerImageId "$1" "$2")"
	if [ -n "$TMP_IMGID" ]; then
		local TMP_WC="$(docker image ls | grep " $TMP_IMGID " | wc -l)"
		local TMP_RES=2
		if [ "$TMP_WC" != "1" ]; then
			docker image rm "${1}$(test -n "$2" && echo -n ":$2")"
			TMP_RES=$?
		else
			docker image rm "$TMP_IMGID"
			TMP_RES=$?
		fi
		[ $TMP_RES -ne 0 ] && TMP_RES=2
		return $TMP_RES
	else
		return 1
	fi
}
