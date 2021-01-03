#!/bin/bash 

### settings to modify
RELEASE=CMSSW_10_6_19
ODIR=validation
# maximum number of files to compare (making sure we are comparing the same state) 
NFILES=100 
# name of sub directories in $ODIR containing the samples to compare 
TAGONE=orig
TAGTWO=mult
### done with settings 

### setup environment
source /cvmfs/cms.cern.ch/cmsset_default.sh
pushd ..

if [ -r ${RELEASE}/src ] ; then
  echo release ${RELEASE} already exists
else
  scram p CMSSW ${RELEASE}
fi
cd ${RELEASE}/src
eval `scram runtime -sh`

### check out dqm packages 
if [ ! -r Utilities/RelMon ]; then  
    git cms-init
    git cms-addpkg Utilities/RelMon
    scram b -j6
fi 

cd -
popd

### make python fragment for harvesting 
cmsDriver.py step3  --python_file harvest.py --no_exec \
    --conditions 106X_mc2017_realistic_v6 --filein file:SUBINFILE \
    -s HARVESTING:genHarvesting --harvesting AtJobEnd \
    --filetype DQM --era Run2_2017 --mc  -n 1000000 


### replace with proper input of first output directory 
INPUTONE="*(" 
idx=0
for FILE in `ls ${ODIR}/${TAGONE}/*.root` ; do 
    idx=$((idx+1))
    if [ "$idx" -gt "$NFILES" ] ; then 
	break 
    fi
    INPUTONE+=`echo \'file:${FILE}\',` ;  
done  
INPUTONE+=" )"

sed -i -e "s#'file:SUBINFILE'#${INPUTONE}#g" harvest.py
cmsRun harvest.py
mv DQM_V0001_R000999999__Global__CMSSW_X_Y_Z__RECO.root DQM_V0001_R000999999__Global__${CMSSW_VERSION}_${TAGONE}__RECO.root 


### replace with proper input of second output directory 
INPUTTWO="*(" 
idx=0
for FILE in `ls ${ODIR}/${TAGTWO}/*.root` ; do 
    idx=$((idx+1))
    if [ "$idx" -gt "$NFILES" ] ; then 
	break 
    fi
    INPUTTWO+=`echo \'file:${FILE}\',` ;  
done  
INPUTTWO+=" )"

sed -i -e "s#${INPUTONE}#${INPUTTWO}#g" harvest.py 
cmsRun harvest.py 

echo " agrohsje  after harvesting two" 

mv DQM_V0001_R000999999__Global__CMSSW_X_Y_Z__RECO.root DQM_V0001_R000999999__Global__${CMSSW_VERSION}_${TAGTWO}__RECO.root 


### make webpage 
compare_using_files.py DQM_V0001_R000999999__Global__${CMSSW_VERSION}_${TAGONE}__RECO.root DQM_V0001_R000999999__Global__${CMSSW_VERSION}_${TAGTWO}__RECO.root \
    -p -C -R -d  Generator \
    -o validation_${TAGONE}_vs_${TAGTWO} --standalone \
    -s Chi2 -t 0.00001 


### clean up 
rm harvest.py 
# rm DQM*.root 