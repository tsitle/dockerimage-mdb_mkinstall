#!/bin/bash

#
# by TS, Apr 2019
#

VAR_MYNAME="$(basename "$0")"
VAR_MYDIR="$(realpath "$0")"
VAR_MYDIR="$(dirname "$VAR_MYDIR")"

################################################################################

function printUsage() {
	echo "Usage: $VAR_MYNAME <FQDN> [internal]" >/dev/stderr
	echo "Examples: $VAR_MYNAME some.domain.org" >/dev/stderr
	echo "          $VAR_MYNAME some.domain.org internal" >/dev/stderr
	exit 1
}
[ $# -lt 1 -o $# -gt 2 -o -z "$1" ] && printUsage
[ $# -eq 2 -a "$2" != "internal" ] && printUsage

LCFG_SSL_KEYS_DIR="/etc/ssl/host-keys"
LCFG_SSL_CERTS_DIR="/etc/ssl/host-certs"
LCFG_SSL_CSRS_DIR="/etc/ssl/host-csrs"

[ $# -eq 2 -a "$2" = "internal" ] && {
	LCFG_SSL_KEYS_DIR="${LCFG_SSL_KEYS_DIR}-internal"
	LCFG_SSL_CERTS_DIR="${LCFG_SSL_CERTS_DIR}-internal"
	LCFG_SSL_CSRS_DIR="${LCFG_SSL_CSRS_DIR}-internal"
}

if [ ! -d "$LCFG_SSL_KEYS_DIR" ]; then
	mkdir "$LCFG_SSL_KEYS_DIR" || {
		echo "$VAR_MYNAME: Error: could not create directory '$LCFG_SSL_KEYS_DIR'. Aborting." >/dev/stderr
		exit 1
	}
fi
if [ ! -d "$LCFG_SSL_CERTS_DIR" ]; then
	mkdir "$LCFG_SSL_CERTS_DIR" || {
		echo "$VAR_MYNAME: Error: could not create directory '$LCFG_SSL_CERTS_DIR'. Aborting." >/dev/stderr
		exit 1
	}
fi

# ------------------------------------------------------------------------

[ "$CF_DEBUG_MDB_SCRIPTS" = "true" ] && echo "$VAR_MYNAME: Generate password for Private Key..."
TMP_PRIVKEY_PASS="$(/root/pwgen.sh)"
#echo "pass='$TMP_PRIVKEY_PASS'"
[ -z "$TMP_PRIVKEY_PASS" ] && {
	echo "$VAR_MYNAME: Error: Generating password for Private Key failed. Aborting." >/dev/stderr
	exit 1
}

TMP_HOST="$1"

TMP_PRIVKEY_PASSFILE="/tmp/passkey.tmp.$$"
TMP_PRIVKEY_FN="$LCFG_SSL_KEYS_DIR/private-$TMP_HOST.key"

TMP_CSR_FN="$LCFG_SSL_CSRS_DIR/server-$TMP_HOST.csr"

TMP_PUB_CERT_FN="$LCFG_SSL_CERTS_DIR/client-$TMP_HOST.crt"

# Generate configuration file
TMP_CONFIG_FILE="/tmp/config.tmp.$$"

cat > $TMP_CONFIG_FILE <<-EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
x509_extensions = v3_req
distinguished_name = dn

[dn]
C = ${CSR_SUBJECT_COUNTRY:-DE}
ST = ${CSR_SUBJECT_STATE:-SAX}
L = ${CSR_SUBJECT_LOCATION:-LE}
O = ${CSR_SUBJECT_ORGANIZ:-The IT Company}
OU = ${CSR_SUBJECT_ORGUNIT:-IT}
emailAddress = webmaster@$TMP_HOST
CN = $TMP_HOST

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = $TMP_HOST
EOF

# wildcard:
#   [alt_names]
#   DNS.1 = *.<DOMAIN>
#   DNS.2 = <DOMAIN>

# ------------------------------------------------------------------------

# This variant does NOT add the X509 subjectAltName and
# Mozilla Thunderbird does NOT accept the resulting certificate
function sslgen_variant1() {
	[ ! -d "$LCFG_SSL_CSRS_DIR" ] && {
		mkdir "$LCFG_SSL_CSRS_DIR" || {
			echo "$VAR_MYNAME: Error: Could not create directory '$LCFG_SSL_CSRS_DIR'. Aborting." >/dev/stderr
			exit 1
		}
	}

	echo -e "\n$VAR_MYNAME: Generate Private Key '$TMP_PRIVKEY_FN'..."
	## password protected RSA Private Key
	openssl genrsa \
			-aes256 \
			-passout pass:$TMP_PRIVKEY_PASS \
			-out "$TMP_PRIVKEY_PASSFILE" \
			2048 \
			>/dev/null 2>&1 || {
		echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr
		exit 1
	}
	## remove password protection
	openssl rsa \
			-passin pass:$TMP_PRIVKEY_PASS \
			-in "$TMP_PRIVKEY_PASSFILE" \
			-out "$TMP_PRIVKEY_FN" \
			>/dev/null 2>&1 || {
		echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr
		exit 1
	}

	rm "$TMP_PRIVKEY_PASSFILE"

	[ "$CF_DEBUG_MDB_SCRIPTS" = "true" ] && echo -e "\n$VAR_MYNAME: Generate Certificate Signing Request '$TMP_CSR_FN'..."
	openssl req \
			-nodes -sha256 \
			-new \
			-key "$TMP_PRIVKEY_FN" \
			-out "$TMP_CSR_FN" \
			-subj "/CN=$TMP_HOST" \
			>/dev/null 2>&1 || {
		echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr
		exit 1
	}

	echo -e "\n$VAR_MYNAME: Generate Public Certificate '$TMP_PUB_CERT_FN'..."
	openssl x509 \
			-req \
			-days $(( 365 * 20 )) \
			-in "$TMP_CSR_FN" \
			-signkey "$TMP_PRIVKEY_FN" \
			-out "$TMP_PUB_CERT_FN" \
			>/dev/null 2>&1 || {
		echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr
		exit 1
	}
}

# This variant DOES add the X509 subjectAltName and
# Mozilla Thunderbird DOES accept the resulting certificate
function sslgen_variant2() {
	echo -e "\n$VAR_MYNAME: Generate Private Key '$TMP_PRIVKEY_FN'..."
	echo -e "$VAR_MYNAME: and Public Certificate '$TMP_PUB_CERT_FN'..."
	openssl req \
			-new \
			-x509 \
			-newkey rsa:2048 \
			-sha256 -nodes \
			-keyout "$TMP_PRIVKEY_FN" \
			-days $(( 365 * 20 )) \
			-out "$TMP_PUB_CERT_FN" \
			-passin pass:$TMP_PRIVKEY_PASS \
			-config "$TMP_CONFIG_FILE" \
			>/dev/null 2>&1 || {
		echo "$VAR_MYNAME: Error: Failed. Aborting." >/dev/stderr
		exit 1
	}
}

sslgen_variant2

rm "$TMP_CONFIG_FILE"

if [ "$CF_DEBUG_MDB_SCRIPTS" = "true" ]; then
	echo
	openssl x509 -noout -fingerprint -text < "$TMP_PUB_CERT_FN"
fi
