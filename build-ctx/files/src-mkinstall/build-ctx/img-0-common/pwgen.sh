#!/bin/bash

#
# by TS, Mar 2019
#

#
# depends on openssl|shasum|md5sum|base64|cksum
#            tr, cut, date, uname
#

################################################################################
# Password Generator Function

# Outputs a generated random password
#
# @param int $1 optional: MAX_LENGTH
# @param bool $2 optional: DO_DEBUG
#
# @return void
function pwgen_generatePassword() {
	local LENMAX="${1}"
	[ -z "$LENMAX" ] && LENMAX=64 || LENMAX=$LENMAX
	[ $LENMAX -gt 64 ] && LENMAX=64

	local DO_DEBUG=false
	[ -n "$2" -a "$2" = "true" ] && DO_DEBUG=true

	local RES=""
	if [ -n "$(which openssl)" ]; then
		# pretty good password...
		RES="$([ "$DO_DEBUG" = "true" ] && echo -n M1)"
		RES="${RES}$(openssl rand -base64 100 2>/dev/null | tr -d "/+=0OoIl\n" | cut -c1-64 | tr -d "\n")"
		RES="${RES}$([ "$DO_DEBUG" = "true" ] && echo -n 1M)"
	elif [ -n "$(which shasum)" -a -c "/dev/urandom" ]; then
		# decent password...
		RES="$([ "$DO_DEBUG" = "true" ] && echo -n M2)"
		local TMP_ARG_IF="if=/dev/urandom"
		RES="${RES}$(dd $TMP_ARG_IF bs=1k count=1 2>/dev/null | shasum -a 512 2>/dev/null | tr -d "\n -0Il" | cut -c1-64 | tr -d "\n")"
		RES="${RES}$([ "$DO_DEBUG" = "true" ] && echo -n 2M)"
	elif [ -n "$(which md5sum)" -a -c "/dev/urandom" ]; then
		# decent password...
		local TMP_ARG_IF="if=/dev/urandom"
		local XRES="$(dd $TMP_ARG_IF bs=1k count=1 2>/dev/null | md5sum 2>/dev/null | tr -d "\n -0Il" | cut -c1-64 | tr -d "\n")"
		local YRES="$(dd $TMP_ARG_IF bs=1k count=1 2>/dev/null | md5sum 2>/dev/null | tr -d "\n -0Il" | cut -c1-64 | tr -d "\n")"
		local ZRES="$(dd $TMP_ARG_IF bs=1k count=1 2>/dev/null | md5sum 2>/dev/null | tr -d "\n -0Il" | cut -c1-64 | tr -d "\n")"
		RES="$([ "$DO_DEBUG" = "true" ] && echo -n M3)"
		RES="${RES}${XRES}${YRES}${ZRES}"
		RES="${RES}$([ "$DO_DEBUG" = "true" ] && echo -n 3M)"
	elif [ -n "$(which base64)" -a -c "/dev/urandom" ]; then
		# decent password...
		RES="$([ "$DO_DEBUG" = "true" ] && echo -n M4)"
		local TMP_ARG_IF="if=/dev/urandom"
		RES="${RES}$(dd $TMP_ARG_IF bs=1k count=1 2>/dev/null | base64 | tr -d "/+=0OoIl\n" | cut -c1-64 | tr -d "\n")"
		RES="${RES}$([ "$DO_DEBUG" = "true" ] && echo -n 4M)"
	elif [ -n "$(which base64)" -a -n "$(which cksum)" ]; then
		# very very weak password...
		local XRES="$({ date 2>/dev/null; uname -a; sleep 1; date 2>/dev/null; sleep 1; } | base64)"
		XRES="$(echo -n "$XRES" | cksum | cut -f1 -d\  | base64 | base64 | base64 | tr -d "\n" | cut -c3- | base64)"
		XRES="$(echo -n "$XRES" | tr -d "/+=0OoIl\n" | tr -d "äöüÖÄÜß" | cut -c1-64 | tr -d "\n")"
		local ZRES="$({ date "+%S" 2>/dev/null; date 2>/dev/null; sleep 1; } | tr -d "äöüÖÄÜß" | tr -d " ./:" | cut -c1-64 | tr "ABCDEFGHIJKLMNOPQRSTUVWXYZ" "61028394391638471520462816" | tr -d "\n")"
		ZRES="$(echo -n "$ZRES" | tr "abcdefghijklmnopqrstuvwxyz" "HSJFDWELVOYNXNHIZETJAMFBDE" | tr -d "\n")"
		ZRES="$(echo -n "$ZRES" | tr "O0IFMADRE5" "hfrpmswcxt" | tr -d "\n")"
		RES="$([ "$DO_DEBUG" = "true" ] && echo -n M5)"
		RES="${RES}${XRES}${ZRES}"
		RES="${RES}$([ "$DO_DEBUG" = "true" ] && echo -n 5M)"
	elif [ -n "$(which cksum)" ]; then
		# very very weak password...
		local XRES="$({ date 2>/dev/null; uname -a; sleep 1; date 2>/dev/null; sleep 1; } | cksum | cut -f1 -d\ )"
		XRES="$(echo -n "$XRES" | tr -d "/+=OoIl\n" | tr -d "äöüÖÄÜß" | cut -c1-64 | tr "02468" "xBAec" | tr -d "\n")"
		local YRES="$({ date 2>/dev/null; uname -a; sleep 1; date 2>/dev/null; sleep 1; } | cksum | cut -f1 -d\ )"
		YRES="$(echo -n "$YRES" | tr -d "/+=OoIl\n" | tr -d "äöüÖÄÜß" | cut -c1-64 | tr "01357" "zDdfb" | tr -d "\n")"
		local ZRES="$({ date "+%S" 2>/dev/null; date 2>/dev/null; sleep 1; } | tr -d "äöüÖÄÜß" | tr -d " ./:" | cut -c1-64 | tr "ABCDEFGHIJKLMNOPQRSTUVWXYZ" "61028394391638471520462816" | tr -d "\n")"
		ZRES="$(echo -n "$ZRES" | tr "abcdefghijklmnopqrstuvwxyz" "HSJFDWELVOYNXNHIZETJAMFBDE" | tr -d "\n")"
		ZRES="$(echo -n "$ZRES" | tr "O0IFMADRE5" "hfrpmswcxt" | tr -d "\n")"
		local VRES="$({ date "+%S" 2>/dev/null; date 2>/dev/null; sleep 1; } | tr -d "äöüÖÄÜß" | tr -d " ./:" | cut -c1-64 | tr "ABCDEFGHIJKLMNOPQRSTUVWXYZ" "61028394391638471520462816" | tr -d "\n")"
		VRES="$(echo -n "$VRES" | tr "abcdefghijklmnopqrstuvwxyz" "HSJFDWELVOYNXNHIZETJAMFBDE" | tr -d "\n")"
		VRES="$(echo -n "$VRES" | tr "O0IFMADRE5" "hfrpmswcxt" | tr -d "\n")"
		RES="$([ "$DO_DEBUG" = "true" ] && echo -n M6)"
		RES="${RES}${XRES}${YRES}${ZRES}${VRES}"
		RES="${RES}$([ "$DO_DEBUG" = "true" ] && echo -n 6M)"
	else
		# very very weak password...
		local XRES="$({ date "+%S" 2>/dev/null; date 2>/dev/null; } | tr -d "äöüÖÄÜß" | tr -d " ./:" | cut -c1-64 | tr "ABCDEFGHIJKLMNOPQRSTUVWXYZ" "61028394391638471520462816" | tr -d "\n")"
		XRES="$(echo -n "$XRES" | tr "abcdefghijklmnopqrstuvwxyz" "HSJFDWELVOYNXNHIZETJAMFBDE" | tr -d "\n")"
		XRES="$(echo -n "$XRES" | tr "O0IFMADRE5" "hfrpmswcxt" | tr -d "\n")"
		sleep 1
		local YRES="$({ date "+%S" 2>/dev/null; date 2>/dev/null; } | tr -d "äöüÖÄÜß" | tr -d " ./:" | cut -c1-64 | tr "ABCDEFGHIJKLMNOPQRSTUVWXYZ" "92872643759019276472939202" | tr -d "\n")"
		YRES="$(echo -n "$YRES" | tr "abcdefghijklmnopqrstuvwxyz" "MDOELDPSKQUEZRXMCBAIORKSDJ" | tr -d "\n")"
		YRES="$(echo -n "$YRES" | tr "O0IFMADRE5" "rqwpcmygsa" | tr -d "\n")"
		sleep 1
		local ZRES="$({ date "+%S" 2>/dev/null; date 2>/dev/null; } | tr -d "äöüÖÄÜß" | tr -d " ./:" | cut -c1-64 | tr "ABCDEFGHIJKLMNOPQRSTUVWXYZ" "92872643759019276472939202" | tr -d "\n")"
		ZRES="$(echo -n "$ZRES" | tr "abcdefghijklmnopqrstuvwxyz" "MDOELDPSKQUEZRXMCBAIORKSDJ" | tr -d "\n")"
		ZRES="$(echo -n "$ZRES" | tr "O0IFMADRE5" "rqwpcmygsa" | tr -d "\n")"
		sleep 1
		RES="$([ "$DO_DEBUG" = "true" ] && echo -n M7)"
		RES="${RES}${XRES}${YRES}${ZRES}"
		RES="${RES}$([ "$DO_DEBUG" = "true" ] && echo -n 7M)"
	fi
	[ "$DO_DEBUG" = "true" ] && echo -e "\nPW [maxlen=$LENMAX] before trimming: '$RES'\n" >/dev/stderr
	echo -n "$RES" | cut -c1-$LENMAX | tr -d "\n"
}

pwgen_generatePassword "$1" "$2"
