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

export SCRAM_ARCH=slc7_amd64_gcc700

source /cvmfs/cms.cern.ch/cmsset_default.sh
if [ -r CMSSW_10_6_19/src ] ; then
  echo release CMSSW_10_6_19 already exists
else
  scram p CMSSW CMSSW_10_6_19
fi
cd CMSSW_10_6_19/src
eval `scram runtime -sh`

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
cmsDriver.py Configuration/GenProduction/python/${PREPID}-fragment.py --python_filename ${PREPID}_1_cfg.py --eventcontent LHE --customise Configuration/DataProcessing/Utils.addMonitoring --datatier LHE --fileout file:${PREPID}.root --conditions 106X_mc2017_realistic_v6 --beamspot Realistic25ns13TeVEarly2017Collision --customise_commands process.source.numberEventsInLuminosityBlock="cms.untracked.uint32(100)" --step LHE --geometry DB:Extended --era Run2_2017 --no_exec --mc --nThreads 4 -n $EVENTS

# Prepare multithread cfg
../utils/check_cfg.py -i ${PREPID}_1_cfg.py

# Run over MT routines
for SUBF in orig mult conc; do
  if ls -d */ | grep -q $SUBF/ ; then
    cd $SUBF
    cmsRun -e -j ../${PREPID}_report-${SUBF}.xml ${PREPID}_1_cfg.py > ../cmsRun-${SUBF}.log 2>&1
    cd ..
  fi
done