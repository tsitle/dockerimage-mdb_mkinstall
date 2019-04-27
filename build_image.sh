#! /bin/bash

LVAR_IMAGE_NAME="mdb-mkinstall"
LVAR_IMAGE_VER="1.13"

docker build \
	-t "$LVAR_IMAGE_NAME":"$LVAR_IMAGE_VER" \
	.
