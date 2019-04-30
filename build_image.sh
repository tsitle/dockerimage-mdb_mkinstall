#! /bin/bash

#
# by TS, Apr 2019
#

# Outputs CPU architecture string
#
# @param string $1 debian_rootfs|debian_dist
#
# @return int EXITCODE
function _getCpuArch() {
	case "$(uname -m)" in
		x86_64*)
			echo -n "amd64"
			;;
		aarch64*)
			if [ "$1" = "debian_rootfs" ]; then
				echo -n "arm64v8"
			elif [ "$1" = "debian_dist" ]; then
				echo -n "arm64"
			else
				echo "$VAR_MYNAME: Error: invalid arg '$1'" >/dev/stderr
				return 1
			fi
			;;
		armv7*)
			if [ "$1" = "debian_rootfs" ]; then
				echo -n "arm32v7"
			elif [ "$1" = "debian_dist" ]; then
				echo -n "armhf"
			else
				echo "$VAR_MYNAME: Error: invalid arg '$1'" >/dev/stderr
				return 1
			fi
			;;
		*)
			echo "$VAR_MYNAME: Error: Unknown CPU architecture '$(uname -m)'" >/dev/stderr
			return 1
			;;
	esac
	return 0
}

_getCpuArch debian_dist >/dev/null || exit 1

# ----------------------------------------------------------

[ -d files/src-mkinstall/build-output ] && rm -r files/src-mkinstall/build-output
[ -d files/src-mkinstall/build-temp ] && rm -r files/src-mkinstall/build-temp

# ----------------------------------------------------------

LVAR_IMAGE_NAME="mdb-mkinstall-$(_getCpuArch debian_dist)"
LVAR_IMAGE_VER="1.13"

docker build \
	--build-arg CF_CPUARCH_DEB_ROOTFS="$(_getCpuArch debian_rootfs)" \
	--build-arg CF_CPUARCH_DEB_DIST="$(_getCpuArch debian_dist)" \
	-t "$LVAR_IMAGE_NAME":"$LVAR_IMAGE_VER" \
	.
