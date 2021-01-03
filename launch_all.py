#!/usr/bin/env python3

import subprocess
import multiprocessing
import os

def launch(cmd, errfile, logfile):
    '''Launch single prepid test'''
    prepid = cmd.split(' ')[1]
    os.makedirs(prepid)
    with open(errfile, 'w') as ferr, open(logfile, 'w') as flog:
        p = subprocess.Popen(cmd, shell=True, universal_newlines=True, stderr=ferr, stdout=flog) 
        p.wait()
        return p

with open('prepid_list_random.txt') as f:
    lines = f.readlines()

pool = multiprocessing.Pool(processes=8)
for line in lines:
    print('processing: ', line.replace('\n',''))
    prepid = line.split()[0]
    pool.apply_async(launch, args=(f'./launch_prepid.sh {prepid}', f'{prepid}/main.err', f'{prepid}/main.log'))

print("Starting tasks...")
pool.close()
pool.join()
print("All tasks completed...")
