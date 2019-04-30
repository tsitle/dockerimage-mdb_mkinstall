#!/usr/bin/env bash

#
# by TS, Mar 2019
#

set -e

# USE the trap if you need to also do manual cleanup after the service is stopped,
#     or need to start multiple services in the one container
trap "echo TRAPed signal" HUP INT QUIT TERM

#

exec "$@"
