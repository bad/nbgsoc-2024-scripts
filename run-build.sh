#!/bin/sh
[ $# -lt 2 ] && { echo "usage: $0 machine args..." 1>2; exit 1; }
echo "$(basename $0)" "$@"
OBJ=${TD:-..}/obj
NCPU=$(( $(nproc) + 2 ))
MACHINE=$1; shift
exec ./build.sh -j${NCPU} -U -m ${MACHINE} -T ${OBJ}/tools \
	-O "${OBJ}/obj.${MACHINE}" -D "${OBJ}/destdir.${MACHINE}" \
	-R "${OBJ}/releasedir.${MACHINE}" "$@"
