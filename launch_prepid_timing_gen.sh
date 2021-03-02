#!/bin/bash

set -x

## Prepid for test
export PREPID=$1

export SCRAM_ARCH=slc7_amd64_gcc700

source /cvmfs/cms.cern.ch/cmsset_default.sh
if [ -r CMSSW_10_6_19/src ] ; then
  echo release CMSSW_10_6_19 already exists
else
  scram p CMSSW CMSSW_10_6_19
fi
cd CMSSW_10_6_19/src
eval `scram runtime -sh`
cd ../..

cd $PREPID

# cmsDriver command (GEN only)
cmsDriver.py Configuration/GenProduction/python/${PREPID}-fragment.py --python_filename ${PREPID}_gen_cfg.py --eventcontent RAWSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier GEN --filein file:${PREPID}.root --fileout file:${PREPID}_GEN.root --conditions 106X_mc2017_realistic_v6 --beamspot Realistic25ns13TeVEarly2017Collision --step GEN --geometry DB:Extended --era Run2_2017 --no_exec --mc --nThreads 4 -n -1

# Prepare multithread cfg
cp ${PREPID}_gen_cfg.py orig/${PREPID}_gen_cfg.py
cp ${PREPID}_gen_cfg.py conc/${PREPID}_gen_cfg.py
sed -i "s/Pythia8HadronizerFilter/Pythia8ConcurrentHadronizerFilter/g" conc/${PREPID}_gen_cfg.py

# Run over MT routines
for SUBF in orig conc; do
  if ls -d */ | grep -q $SUBF/ ; then
    cd $SUBF
    # cmsRun -e -j ../${PREPID}_gen_report-${SUBF}.xml ${PREPID}_gen_cfg.py > ../cmsRun_gen-${SUBF}.log 2>&1
    echo "run $SUBF"
    cd ..
  fi
done