#!/usr/bin/env python3

import subprocess
import multiprocessing
import os

def launch(cmd, errfile, logfile):
    '''Launch single prepid test'''
    print(cmd)
    prepid = cmd.split(' ')[1]
    os.makedirs(prepid)
    with open(errfile, 'w') as ferr, open(logfile, 'w') as flog:
        p = subprocess.Popen(cmd, shell=True, universal_newlines=True, stderr=ferr, stdout=flog) 
        p.wait()
        return p

with open('prepid_list_random.txt') as f:
    lines = f.readlines()

pool = multiprocessing.Pool(processes=16)
for line in lines:
    prepid, name = line.split()
    if any([n in name for n in ['nlo', 'NLO', 'fxfx', 'FXFX']]):
        print('  - skip', prepid, name)
        continue
    pool.apply_async(launch, args=(f'./launch_prepid.sh {prepid}', f'{prepid}/main.err', f'{prepid}/main.log'))

print("Starting tasks...")
pool.close()
pool.join()
print("All tasks completed...")
