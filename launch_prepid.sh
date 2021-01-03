#!/bin/bash

set -x

## Prepid for test
export PREPID=$1

# Number of events to run
if [ -n "$2" ]; then
    export EVENTS=$2
else
    export EVENTS=5000
fi

cd $PREPID

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

# cmsDriver command
cmsDriver.py Configuration/GenProduction/python/${PREPID}-fragment.py --python_filename ${PREPID}_1_cfg.py --eventcontent RAWSIM,LHE,DQM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier GEN,LHE,DQMIO --fileout file:${PREPID}.root --conditions 106X_mc2017_realistic_v6 --beamspot Realistic25ns13TeVEarly2017Collision --customise_commands process.source.numberEventsInLuminosityBlock="cms.untracked.uint32(100)" --step LHE,GEN,VALIDATION:genvalid_all --geometry DB:Extended --era Run2_2017 --no_exec --mc --nThreads 4 -n $EVENTS

# Prepare multithread cfg
cp ${PREPID}_1_cfg.py ${PREPID}_1_cfg-mt.py
../prepare_mult_cfg.py -i ${PREPID}_1_cfg-mt.py --mg-mult --pythia-conc
diff ${PREPID}_1_cfg.py ${PREPID}_1_cfg-mt.py > cfg.diff

# Run generated config
{ mkdir orig && cd orig && cmsRun -e -j ../${PREPID}_report.xml    ../${PREPID}_1_cfg.py    > cmsRun.log 2>&1; } &
{ mkdir mult && cd mult && cmsRun -e -j ../${PREPID}_report-mt.xml ../${PREPID}_1_cfg-mt.py > cmsRun.log 2>&1; } &
wait

# ============================================================================ #
# Check the cmsRun output exists
if [ ! -e orig/${PREPID}_inDQM.root ] || [ ! -e mult/${PREPID}_inDQM.root ]; then
    echo "cmsRun breaks!"
    exit 1
fi

# Create folder for validation
mkdir -p validation/orig && mv orig/${PREPID}_inDQM.root validation/orig/DQM_orig.root
mkdir -p validation/mult && mv mult/${PREPID}_inDQM.root validation/mult/DQM_mult.root

# Make validation html
../merge_mkhtml.sh
