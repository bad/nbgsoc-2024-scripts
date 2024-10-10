#!/bin/sh
#
# run-qemu.sh -- run the netbsd vm with qemu.
#
set -eu

dryrun=
verbose=false
memsz=2g
numcpu=2
pfx=vm
vmrootsz=10g
vmrootfile=${pfx}/netbsd-10.0
isoimage=${pfx}/NetBSD-10.0-amd64.iso
hostfwdssh=",hostfwd=tcp:127.1:2222-:22"
console="-display none -serial mon:stdio"
fsdev=""

case `uname -s` in
    Linux)
	accel=kvm
	;;
    Darwin)
	accel=hvf
	;;
    NetBSD)
	accel=nvmm
	;;
    *)
	err 2 "unkown operating system. can't choose accellerator"
	;;
esac


usage() {
    cat 1>&2 <<EOF
usage: $0 [-n] [-v | --verbose] [-c [nographic|curses|serial]] [--root-image file] [--root-size sz] [--iso-image file] [[-m|--mem] size] [--ssh] [--fsdev dir[,ro|rw]]... [--] [ qemu-options]
EOF
    exit 3
}

err() {
    code=$1; shift
    echo "$@" 1>&2
    exit ${code}
}

run() {
    ${verbose} && echo "$@" 1>&2
    ${dryrun} "$@"
}

# parse args
while [ $# -ge 1 ]; do
    case "$1" in
	--)
	    shift; break	# no more options
	    ;;
	-n)
	    dryrun=echo; shift
	    ;;
	-v | --verbose)
	    verbose=true; shift;
	    ;;
	-c)
	    shift
	    [ $# -ge 1 ] || err 2 "-c requires an argument (nographic|curses|serial)"
	    case $1 in
		nographic)
		    console="-nographic"
		    ;;
		curses)
		    console="-display curses"
		    ;;
		serial)
		    console="-display none -serial mon:stdio"
		    ;;
		*)
		    err 2 "unknown console option '$1'"
		    ;;
	    esac
	    shift
	    ;;
	--root-image)
	    shift
	    [ $# -ge 1 ] || err 2 "--root-image requires a file name argument"
	    vmrootfile=$1; shift
	    ;;
	--root-size)
	    shift
	    [ $# -ge 1 ] || err 2 "--root-size requires a size argument"
	    vmrootsz=$1; shift
	    ;;
	--iso-image)
	    shift
	    [ $# -ge 1 ] || err 2 "--iso-image requires a file name argument"
	    isoimage="$1"; shift
	    ;;
	-m | --mem)
	    shift
	    [ $# -ge 1 ] || err 2 "-m | --mem requires a size argument"
	    memsz=$1; shift
	    ;;
	--ssh)
	    shift
	    fwdssh=true
	    ;;
	--fsdev)
	    shift
	    [ $# -ge 1 ] || err 2 "-m | --fsdev requires a directory name"

	    roflag=$(expr "$1" : '.*,\(r[ow]\)$' || true)
	    case ${roflag:-rw} in # default to read-write as qemu does
		ro) roflag=",readonly=on";;
		rw) roflag=;;
	    esac

	    dir=$(echo "$1"| sed -e 's/,.*//') # strip everything from ',' on
	    [ ! -d "$dir" ] && err 1 "directory $dir doesn't exist"

	    shift

	    tag=$(basename "$dir")
	    fsdev="$fsdev -fsdev local,id=${tag},security_model=none,path=${dir}${roflag} -device virtio-9p-pci,fsdev=${tag},mount_tag=${tag}"
	    ;;
	*)
	    echo "unkown option: $1" 1>&2
	    usage
	    ;;
    esac
done

qemucmd="qemu-system-x86_64 -M q35 -cpu host -accel $accel
    -smp ${numcpu} -m ${memsz}
    -device virtio-rng,rng=rng0
    -object rng-random,id=rng0,filename=/dev/urandom
    -nic user,model=virtio-net-pci${fwdssh:+$hostfwdssh}
    -drive if=ide,index=0,id=wd0,media=disk,file=${vmrootfile}
    -cdrom ${isoimage}
    ${fsdev}
    ${console}"

if [ ! -f ${vmrootfile} ]; then
    run qemu-img create -f qcow2 ${vmrootfile} ${vmrootsz} ||
	err 2 "error creating ${vmrootfile}: $!"
fi

run $qemucmd "$@"
