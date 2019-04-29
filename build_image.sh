#! /bin/bash

#
# by TS, Apr 2019
#

# Outputs CPU architecture string
#
# @return int EXITCODE
function mklive_getCpuArch() {
	case "$(uname -m)" in
		x86_64*)
			echo -n "x86_64"
			;;
		aarch64)
			echo -n "arm_64"
			;;
		armv7*)
			echo -n "arm_32"
			;;
		*)
			echo "$VAR_MYNAME: Error: Unknown CPU architecture '$(uname -m)'" >/dev/stderr
			return 1
			;;
	esac
	return 0
}

mklive_getCpuArch >/dev/null || exit 1

# ----------------------------------------------------------

LVAR_IMAGE_NAME="mdb-mkinstall-$(mklive_getCpuArch)"
LVAR_IMAGE_VER="1.13"

docker build \
	-t "$LVAR_IMAGE_NAME":"$LVAR_IMAGE_VER" \
	.
