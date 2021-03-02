#!/usr/bin/env python3

from prepare_mult_cfg import modify

import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-i', '--inputfile', help='Input cfg file')
args = parser.parse_args()

with open(args.inputfile) as f:
    lines = f.read()

import os, shutil, subprocess
import re
gp_path = re.findall('[\'\"](/cvmfs/cms\.cern\.ch/phys_generator/gridpacks/.*)[\'\"]', lines)[0]
print(gp_path)

# Decide the type of gridpack
if 'madgraph' in gp_path:
    if any([n in gp_path.lower() for n in ['nlo', 'fxfx']]):
        gp_type = 'mgnlo'
    elif 'mlm' in gp_path.lower():
        gp_type = 'mglo'
    else:
        if os.path.exists('_tmp'):
            shutil.rmtree('_tmp')
        os.makedirs('_tmp')
        subprocess.Popen(f'cd _tmp && tar xaf {gp_path}', shell=True).wait()
        if os.path.exists('_tmp/process/madevent/SubProcesses/MGVersion.txt'):
            gp_type = 'mglo'
        else:
            gp_type = 'mgnlo'
        shutil.rmtree('_tmp')
else:
    gp_type = 'nonmg'
print(f'Type of gridpack: {gp_type}')
with open('.gp_type', 'w') as fw:
    fw.write(gp_type)

# Setup folder for multithreading mode
for folder, mode in zip(['orig', 'conc', 'mult'], [(), ('mg_gp_conc'), ('mg_mult')]):
    if gp_type != 'mglo' and folder == 'mult':
        continue
    if os.path.exists(folder):
        print(f'Remove folder: {folder}')
        shutil.rmtree(folder)
    os.makedirs(folder)
    shutil.copy(args.inputfile, folder)
    modify(path=os.path.join(folder, args.inputfile), mode=mode)