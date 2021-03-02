#!/usr/bin/env python3

import subprocess
import multiprocessing
import os

import argparse
parser = argparse.ArgumentParser()
parser.add_argument('--shuffle', action='store_true', help='Shuffle the sample list')
parser.add_argument('--exclude-nlo', action='store_true', help='Exclude NLO samples')
parser.add_argument('--lhe-timing', action='store_true', help='Do timing test in LHE step')
args = parser.parse_args()

def launch(cmd, errfile, logfile):
    '''Launch single prepid test'''
    print(cmd)
    prepid = cmd.split(' ')[1]
    if not os.path.exists(prepid):
        os.makedirs(prepid)
    with open(errfile, 'w') as ferr, open(logfile, 'w') as flog:
        p = subprocess.Popen(cmd, shell=True, universal_newlines=True, stderr=ferr, stdout=flog) 
        p.wait()
        return p

with open('prepid_list_random.txt' if args.shuffle else 'prepid_list.txt') as f:
    lines = f.readlines()

pool = multiprocessing.Pool(processes=15)
for line in lines:
    prepid, name = line.split()
    if args.exclude_nlo and any([n in name for n in ['nlo', 'NLO', 'fxfx', 'FXFX']]):
        print('  - skip', prepid, name)
        continue
    if args.lhe_timing:
        pool.apply_async(launch, args=(f'./launch_prepid_timing.sh {prepid}', f'{prepid}/main.err', f'{prepid}/main.log'))
    else:
        pool.apply_async(launch, args=(f'./launch_prepid.sh {prepid}', f'{prepid}/main.err', f'{prepid}/main.log'))

print("Starting tasks...")
pool.close()
pool.join()
print("All tasks completed...")
