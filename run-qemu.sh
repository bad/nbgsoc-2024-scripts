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
isoimage=${pfx}/NetBSD-10.0_RC5-amd64.iso
hostfwdssh=",hostfwd=tcp:127.1:2222-:22"
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
usage: $0 [-n] [-v | --verbose] [--iso-image file] [[-m|--mem] size] [--ssh] [--fsdev dir]... [--] [ qemu-options]
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
	    dir=$1; shift
	    [ ! -d "$dir" ] && err 1 "directory $dir doesn't exist"
	    fsdev="$fsdev -fsdev local,id=${dir},security_model=none,readonly=on,path=${dir} -device virtio-9p-pci,fsdev=${dir},mount_tag=${dir}"
	    ;;
	*)
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
    -display none -serial mon:stdio"

if [ ! -f ${vmrootfile} ]; then
    run qemu-img create -f qcow2 ${vmrootfile} ${vmrootsz} ||
	err 2 "error creating ${vmrootfile}: $!"
fi

run $qemucmd "$@"
