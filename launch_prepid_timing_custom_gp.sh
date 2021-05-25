#!/bin/bash

set -x

## Prepid for test
export PREPID=$1

# Number of events to run
if [ -n "$2" ]; then
    export EVENTS=$2
else
    export EVENTS=1200
fi

if [ -n "$3" ]; then
    export NTHREADS=$3
else
    export NTHREADS=4
fi

export SCRAM_ARCH=slc7_amd64_gcc700

source /cvmfs/cms.cern.ch/cmsset_default.sh
if [ -r CMSSW_10_6_19/src ] ; then
  echo release CMSSW_10_6_19 already exists
else
  scram p CMSSW CMSSW_10_6_19
fi
cd CMSSW_10_6_19/src
eval `scram runtime -sh`

######
# git cms-addpkg GeneratorInterface/LHEInterface
# rm -f GeneratorInterface/LHEInterface/data/runcmsgrid_LO_support_multithread.patch
# curl https://coli.web.cern.ch/coli/tmp/.210307-084248_multithread_test/runcmsgrid_LO_support_multithread.patch -o GeneratorInterface/LHEInterface/data/runcmsgrid_LO_support_multithread.patch
tar xaf ../../GeneratorInterface.tar
######

# Download fragment from McM
curl -s -k https://cms-pdmv.cern.ch/mcm/public/restapi/requests/get_fragment/${PREPID} --retry 3 --create-dirs -o Configuration/GenProduction/python/${PREPID}-fragment.py
[ -s Configuration/GenProduction/python/${PREPID}-fragment.py ] || exit $?;

# Check if fragment contais gridpack path ant that it is in cvmfs
if grep -q "gridpacks" Configuration/GenProduction/python/${PREPID}-fragment.py; then
  if ! grep -q "/cvmfs/cms.cern.ch/phys_generator/gridpacks" Configuration/GenProduction/python/${PREPID}-fragment.py; then
    echo "Gridpack inside fragment is not in cvmfs."
    exit -1
  fi
fi

scram b -j4
cd ../..

# Now enter the prepid folder
if [ ! -d $PREPID ]; then
  mkdir $PREPID
fi
cd $PREPID

# cmsDriver command (LHE only)

# Prepare multithread cfg

# Run over MT routines
for SUBF in orig mult conc; do
  if ls -d */ | grep -q $SUBF/ ; then
    cd $SUBF
    top -b -d 2 > cpu.log &
    TOPID=$!
    cmsRun -e -j ../${PREPID}_report-${SUBF}.xml ${PREPID}_1_cfg.py > ../cmsRun-${SUBF}.log 2>&1
    kill -9 ${TOPID}
    rm -f *.root
    cd ..
  fi
done