#!/bin/bash

# ----------------------------------------------------------

CFG_MKINST_DOCK_IMG_RELEASE_VERS="${CF_MKINST_DOCK_IMG_RELEASE_VERS:-latest}"

CFG_MKINST_MODOBOA_VERSION="1.13.1"
CFG_MKINST_MODOBOA_INSTALLER_VERSION="190414"

# ----------------------------------------------------------

CFG_MKINST_PATH_BUILDTEMP="build-temp"

CFG_MKINST_PATH_BUILDOUTPUT="build-output"

CFG_MKINST_PATH_BUILDCTX="build-ctx"

# ----------------------------------------------------------

# for the building process only:
CFG_MKINST_DOCK_NET_NAME="mkinstallmdb"

# for the building process only:
# the first 3 numbers of the network address (e.g. 100.50.25)
# IP range for private networks: 172.16.0.0 - 172.31.255.255
CFG_MKINST_DOCK_NET_PREFIX="${CF_MKINST_DOCK_NET_PREFIX:-172.29.19}"

# ----------------------------------------------------------

# for the building process only:
# !! only in CFG_MKINST_TIMEZONE are '/'s allowed
CFG_MKINST_TIMEZONE="Europe/Berlin"

# ----------------------------------------------------------

# this DB root password has no impact on security.
# it is being used only during the build process
CFG_MKINST_MARIADB_ROOT_PASS="abcd"

# only for debugging purposes
CFG_MKINST_MARIADB_SERVER_PORT_ON_HOST="${CF_MKINST_MARIADB_SERVER_PORT_ON_HOST:-3376}"

# for the building process only:
CFG_MKINST_MARIADB_DOCKERCONTAINER="mdb-mariadb-$(echo -n "$CFG_MKINST_DOCK_IMG_RELEASE_VERS" | tr -d ".")-cnt"

# for the building process only:
CFG_MKINST_MARIADB_MNTPOINT="${CF_MKINST_MARIADB_MNTPOINT:-dockerMountpointMariaDb}"

CFG_MKINST_MARIADB_MODO_FN_TEMPL="modo-<MODOBOA_VERSION>-db_modoboa.sql"
CFG_MKINST_MARIADB_AMAV_FN_TEMPL="modo-<MODOBOA_VERSION>-db_amavis.sql"
CFG_MKINST_MARIADB_SPAM_FN_TEMPL="modo-<MODOBOA_VERSION>-db_spamassassin.sql"

# for the building process only:
CFG_MKINST_MARIADB_INSTALLER_DBUSER="docker_modo_installer"

# for the building process only:
CFG_MKINST_MARIADB_MODOBOA_DBS_PREFIX="docker_buildmodo_"

# for the building process only:
CFG_MKINST_MARIADB_ACCESS_ALLOWED_SOURCE_NETWORK="%"

# ----------------------------------------------------------

CFG_MKINST_CUSTOMIZE_MODO_LCONF_PY_SCRIPT_FN="customize_modo_lconf.py"

# ----------------------------------------------------------
# ----------------------------------------------------------
# ----------------------------------------------------------

# may be "true" or "false":
CFG_MKINST_DEBUG_DONT_EXPORT_FINAL_IMG=${CF_MKINST_DEBUG_DONT_EXPORT_FINAL_IMG:-false}

# may be "true" or "false":
CFG_MKINST_DEBUG_PWGENFNC=${CF_MKINST_DEBUG_PWGENFNC:-false}

# may be "true" or "false":
CFG_MKINST_DEBUG_DISABLE_CLAMAV=${CF_MKINST_DEBUG_DISABLE_CLAMAV:-false}

# may be "true" or "false":
CFG_MKINST_DEBUG_DISABLE_OPENDKIM=${CF_MKINST_DEBUG_DISABLE_OPENDKIM:-false}

# ----------------------------------------------------------
# ----------------------------------------------------------
# ----------------------------------------------------------

CFG_MKINST_DOCK_IMG_NGINX="mdb-nginx"
CFG_MKINST_DOCK_IMG_NGINX_SRCDIR="img-a-nginx"

# ----------------------------------------------------------

CFG_MKINST_DOCK_IMG_MARIADB="mdb-mariadb"
CFG_MKINST_DOCK_IMG_MARIADB_SRCDIR="img-b-mariadb"

# ----------------------------------------------------------

CFG_MKINST_DOCK_IMG_STEP1="mdb-step1"
CFG_MKINST_DOCK_IMG_STEP1_SRCDIR="img-c-step1"

# ----------------------------------------------------------

CFG_MKINST_DOCK_IMG_STEP2="mdb-step2"
CFG_MKINST_DOCK_IMG_STEP2_SRCDIR="img-d-step2"

# ----------------------------------------------------------

CFG_MKINST_DOCK_IMG_STEP3="mdb-step3"
CFG_MKINST_DOCK_IMG_STEP3_SRCDIR="img-e-step3"

# ----------------------------------------------------------

CFG_MKINST_DOCK_IMG_STEP4="mdb-step4"
CFG_MKINST_DOCK_IMG_STEP4_SRCDIR="img-f-step4"

# ----------------------------------------------------------

CFG_MKINST_DOCK_IMG_STEP5="mdb-step5"
CFG_MKINST_DOCK_IMG_STEP5_SRCDIR="img-g-step5"

# ----------------------------------------------------------

CFG_MKINST_DOCK_IMG_STEP6="mdb-install"
CFG_MKINST_DOCK_IMG_STEP6_SRCDIR="img-h-step6"

# ----------------------------------------------------------

CFG_MKINST_BUILD_TARGETS=""
CFG_MKINST_BUILD_TARGETS="$CFG_MKINST_BUILD_TARGETS $CFG_MKINST_DOCK_IMG_NGINX"
CFG_MKINST_BUILD_TARGETS="$CFG_MKINST_BUILD_TARGETS $CFG_MKINST_DOCK_IMG_MARIADB"
CFG_MKINST_BUILD_TARGETS="$CFG_MKINST_BUILD_TARGETS $CFG_MKINST_DOCK_IMG_STEP1"
CFG_MKINST_BUILD_TARGETS="$CFG_MKINST_BUILD_TARGETS $CFG_MKINST_DOCK_IMG_STEP2"
CFG_MKINST_BUILD_TARGETS="$CFG_MKINST_BUILD_TARGETS $CFG_MKINST_DOCK_IMG_STEP3"
CFG_MKINST_BUILD_TARGETS="$CFG_MKINST_BUILD_TARGETS $CFG_MKINST_DOCK_IMG_STEP4"
CFG_MKINST_BUILD_TARGETS="$CFG_MKINST_BUILD_TARGETS $CFG_MKINST_DOCK_IMG_STEP5"
CFG_MKINST_BUILD_TARGETS="$CFG_MKINST_BUILD_TARGETS $CFG_MKINST_DOCK_IMG_STEP6"
