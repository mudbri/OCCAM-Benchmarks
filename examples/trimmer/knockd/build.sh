#!/usr/bin/env bash

# Make sure we exit if there is a failure
set -e

function usage() {
    echo "Usage: $0 [--with-musllvm] [--disable-inlining] [--ipdse] [--use-crabopt] [--use-pointer-analysis] [--inter-spec VAL] [--intra-spec VAL] [--enable-config-prime] [--help]"
    echo "       VAL=none|aggressive|nonrec-aggressive|onlyonce"
}

#default values
INTER_SPEC="none"
INTRA_SPEC="onlyonce"
OPT_OPTIONS=""
USE_MUSLLVM="false"
##----------------------------------------------------------------##
## This path to be changed accordingly if USE_MUSLLVM is enabled.
##----------------------------------------------------------------##
MUSLLVM_DIR="/homes/jorge/Repos/OCCAM-10/examples/linux/musllvm"

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
    declare -a bitcode=("knockd.bc" "${MUSLLVM_DIR}/libc.a.bc" "${MUSLLVM_DIR}/libc.a")
else
    declare -a bitcode=("knockd.bc")
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
            echo "Error: $bc not found. Try \"make\"."
	fi
        exit 1
    fi
done


MANIFEST=knockd.manifest

if [ $USE_MUSLLVM == "true" ];
then
    echo "Linking knockd.bc with libc.a.bc."
    llvm-link knockd.bc ${MUSLLVM_DIR}/libc.a.bc -o knockd-with-musllvm.bc
    cat > ${MANIFEST} <<EOF    
{"binary": "knockd_occamized", 
"native_libs":[],
"name": "knockd", 
"static_args": ["-i","eth0"],
"modules": [], 
"ldflags": ["-lpcap","-O3"], 
"main": "knockd.bc"}
EOF
else
    cat > ${MANIFEST} <<EOF    
{"binary": "knockd_occamized", 
"native_libs":[],
"name": "knockd", 
"static_args": ["-i","eth0"],
"modules": [], 
"ldflags": ["-lpcap","-O3"], 
"main": "knockd.bc"}
EOF
fi    
    

export OCCAM_LOGLEVEL=INFO
export OCCAM_LOGFILE=${PWD}/slash/occam.log

rm -rf slash

# OCCAM
SLASH_OPTS="--inter-spec-policy=${INTER_SPEC} --intra-spec-policy=${INTRA_SPEC}   --stats $OPT_OPTIONS"
echo "============================================================"
echo "Running with options ${SLASH_OPTS}"
echo "============================================================"
slash ${SLASH_OPTS} --work-dir=slash ${MANIFEST}

status=$?
if [ $status -eq 0 ]
then
    cp slash/knockd_occamized ./
    # cp knockd-2.28/src/knockd ./knockd-orig
    strip knockd_occamized -o knockd_occamized_stripped
else
    echo "Something failed while running slash"
fi    
