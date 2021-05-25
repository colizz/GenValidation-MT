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

if [ -n "$3" ]; then
    export NTHREADS=$3
else
    export NTHREADS=4
fi

# lmode1: nthread=1, LHE
# lmode2: nthread=4, conc LHE
# lmode3: nthread=4, mult LHE
# +++
# gmode0: none
# gmode1: nthread=1, GEN
# gmode2: nthread=4, conc GEN
# test: (check lhe format e.g. weights) 1+0, 2+0; (check ConcP8Hadrionzer) 1+1, 1+2; ExGenFilter

if [[ "$PREPID" == *"UL16"* ]]; then
  conditions=106X_mcRun2_asymptotic_v13
  beamspot=Realistic25ns13TeV2016Collision
  era=Run2_2016
elif [[ "$PREPID" == *"UL17"* ]]; then
  conditions=106X_mc2017_realistic_v6
  beamspot=Realistic25ns13TeVEarly2017Collision
  era=Run2_2017
else
  echo "Not UL16/17"
  exit -1
fi

mkdir $PREPID
cd $PREPID

export SCRAM_ARCH=slc7_amd64_gcc700
export RELEASE=CMSSW_10_6_24
source /cvmfs/cms.cern.ch/cmsset_default.sh
if [ -r $RELEASE/src ] ; then
  echo release $RELEASE already exists
else
  scram p CMSSW $RELEASE
fi
cd $RELEASE/src
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

###### LHE ########
# cmsDriver command
cmsDriver.py Configuration/GenProduction/python/${PREPID}-fragment.py --python_filename ${PREPID}_lheorig_cfg.py --eventcontent LHE --customise Configuration/DataProcessing/Utils.addMonitoring --datatier LHE --fileout file:${PREPID}_inLHE.root --conditions $conditions --beamspot $beamspot --step LHE --geometry DB:Extended --era $era --no_exec --mc --nThreads $NTHREADS -n $EVENTS

# Prepare multithread cfg
cp ${PREPID}_lheorig_cfg.py ${PREPID}_lheconc_cfg.py
../utils/prepare_mult_cfg.py -i ${PREPID}_lheconc_cfg.py --mg-gp-conc

# Launch cmsRun
for TAG in lheorig lheconc; do
  mkdir $TAG; cd $TAG; cmsRun -e -j ../${TAG}.xml ../${PREPID}_${TAG}_cfg.py > ../cmsRun-${TAG}.log 2>&1
  rm -rf lheevent thread?
  cd ..
done

###### GEN ########
# cmsDriver command 
# (note that we read ../lheorig/${PREPID}_inLHE.root)
cmsDriver.py Configuration/GenProduction/python/${PREPID}-fragment.py --python_filename ${PREPID}_genorig_cfg.py --eventcontent RAWSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier GEN --filein file:../lheorig/${PREPID}_inLHE.root --fileout file:${PREPID}.root --conditions $conditions --beamspot $beamspot --step GEN --geometry DB:Extended --era $era --no_exec --mc --nThreads $NTHREADS -n -1

# Prepare multithread cfg
cp ${PREPID}_genorig_cfg.py ${PREPID}_genconc_cfg.py
../utils/prepare_mult_cfg.py -i ${PREPID}_genconc_cfg.py --pythia-conc

# Launch cmsRun
for TAG in genorig genconc; do
  mkdir $TAG; cd $TAG; cmsRun -e -j ../${TAG}.xml ../${PREPID}_${TAG}_cfg.py > ../cmsRun-${TAG}.log 2>&1
  cd ..
done

###### NANOGEN ########
for TAG in genorig genconc; do
  cd $TAG
  cmsDriver.py --python_filename nanogen_cfg.py --eventcontent NANOAODSIM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier NANOAODSIM --filein file:${PREPID}.root --fileout file:${PREPID}_NANOGEN.root --conditions $conditions --beamspot $beamspot --step NANOGEN --customise_commands "from PhysicsTools.NanoAOD.nanogen_cff import customizeNanoGEN; process = customizeNanoGEN(process)" --era $era,run2_nanoAOD_106Xv1 --no_exec --mc --nThreads $NTHREADS -n -1
  cmsRun nanogen_cfg.py
  cd ..
done

###### VALIDATION ########
# cmsDriver command 
for TAG in genorig genconc; do
  cd $TAG
  cmsDriver.py --python_filename validation_cfg.py --eventcontent DQM --customise Configuration/DataProcessing/Utils.addMonitoring --datatier DQMIO --filein file:${PREPID}.root --fileout file:${PREPID}_inDQM.root --conditions $conditions --beamspot $beamspot --step VALIDATION:genvalid_all --geometry DB:Extended --era $era --no_exec --mc --nThreads $NTHREADS -n -1
  cmsRun validation_cfg.py
  cd ..
done

# Remove original gen file which is too large
rm -rf genorig/${PREPID}.root genconc/${PREPID}.root

# ============================================================================ #
# Check the cmsRun output exists
if [ ! -e genorig/${PREPID}_inDQM.root ] || [ ! -e genconc/${PREPID}_inDQM.root ]; then
  echo "cmsRun breaks!"
  exit 1
fi

# Create folder for validation
mkdir -p validation/genorig && mv genorig/${PREPID}_inDQM.root validation/genorig/DQM_genorig.root
mkdir -p validation/genconc && mv genconc/${PREPID}_inDQM.root validation/genconc/DQM_genconc.root

# Make validation html
../merge_mkhtml.sh CMSSW_10_6_19 validation genorig genconc
