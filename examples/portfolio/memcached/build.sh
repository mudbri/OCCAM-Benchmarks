#!/usr/bin/env bash

# Make sure we exit if there is a failure
set -e

function usage() {
    echo "Usage: $0 [--with-musllvm] [--disable-inlining] [--ipdse] [--use-crabopt] [--use-pointer-analysis] [--inter-spec VAL] [--intra-spec VAL] [--enable-config-prime] [--help]"
    echo "       VAL=none|aggressive|nonrec-aggressive|onlyonce (default)"
}

#default values
INTER_SPEC="onlyonce"
INTRA_SPEC="onlyonce"
OPT_OPTIONS=""
USE_MUSLLVM="false"

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    -inter-spec|--inter-spec)
	INTER_SPEC="$2"
	shift # past argument
	shift # past value
	;;
    -intra-spec|--intra-spec)
	INTRA_SPEC="$2"
	shift # past argument
	shift # past value
	;;
    -disable-inlining|--disable-inlining)
	OPT_OPTIONS="${OPT_OPTIONS} --disable-inlining"
	shift # past argument
	;;
    -enable-config-prime|--enable-config-prime)
	OPT_OPTIONS="${OPT_OPTIONS} --enable-config-prime"
	shift # past argument
	;;    
    -with-musllvm|--with-musllvm)
	USE_MUSLLVM="true" 
	shift # past argument
	;;    
    -ipdse|--ipdse)
	OPT_OPTIONS="${OPT_OPTIONS} --ipdse"
	shift # past argument
	;;
    -use-crabopt|--use-crabopt)
	OPT_OPTIONS="${OPT_OPTIONS} --use-crabopt"
	shift # past argument
	;;                    
    -use-pointer-analysis|--use-pointer-analysis)
	OPT_OPTIONS="${OPT_OPTIONS} --use-pointer-analysis"	
	shift # past argument
	;;        
    -help|--help)
	usage
	exit 0
	;;
    *)    # unknown option
	POSITIONAL+=("$1") # save it in an array for later
	shift # past argument
	;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

#check that the require dependencies are built
if [ $USE_MUSLLVM == "true" ];
then
    declare -a bitcode=("memcached.bc" "libevent.a.bc" "libc.a.bc" "libc.a")
else
    declare -a bitcode=("memcached.bc" "libevent.a.bc")
fi    

for bc in "${bitcode[@]}"
do
    if [ -a  "$bc" ]
    then
        echo "Found $bc"
    else
	if [ "$bc" == "libc.a.bc" ];
	then
	    echo "Error: $bc not found. You need to compile musllvm and copy $bc to ${PWD}."
	else
            echo "Error: $bc not found. Try \"make -f Makefile_libevent; make\"."
	fi
        exit 1
    fi
done

MANIFEST=memcached.manifest

if [ $USE_MUSLLVM == "true" ];
then
    cat > ${MANIFEST} <<EOF
{ "main" : "memcached.bc"
, "binary"  : "memcached_occamized"
, "modules"    : ["libevent.a.bc","libc.a.bc"]
, "native_libs" : ["libc.a"]
, "ldflags" : [ "-O2", "-lpthread"]
, "name"    : "memcached"
, "static_args" : ["-m", "1024", "-I", "1k", "-l", "127.0.0.1:11211"]
}
EOF
else 
    cat > ${MANIFEST} <<EOF
{ "main" : "memcached.bc"
, "binary"  : "memcached_occamized"
, "modules"    : ["libevent.a.bc"]
, "native_libs" : ["-lpthread"  ]
, "ldflags" : [ "-O2" ]
, "name"    : "memcached"
, "static_args" : ["-m", "1024", "-I", "1k", "-l", "127.0.0.1:11211"]
}
EOF
fi

export OCCAM_LOGLEVEL=INFO
export OCCAM_LOGFILE=${PWD}/slash/occam.log

rm -rf slash

SLASH_OPTS="--inter-spec-policy=${INTER_SPEC} --intra-spec-policy=${INTRA_SPEC} --no-strip --stats $OPT_OPTIONS"
echo "============================================================"
if [ $USE_MUSLLVM == "true" ];
then
    echo "Running memcacched with libevent library and musllvm"
else
    echo "Running memcacched with libevent library"    
fi    
echo "slash options ${SLASH_OPTS}"
echo "============================================================"
slash ${SLASH_OPTS} --work-dir=slash ${MANIFEST}
status=$?
if [ $status -eq 0 ]
then
    ## runbench (if gadgets enabled) needs _orig and _slashed versions
    cp slash/memcached_occamized ./
    cp install/memcached/bin/memcached memcached_orig
else
    echo "Something failed while running slash"
fi    
