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

with open('prepid_list.txt') as f:
    prepid_list = f.readlines()

pool = multiprocessing.Pool(processes=8)
for prepid in prepid_list:
    pool.apply_async(launch, args=(f'./launch_prepid.sh {prepid} 50', f'{prepid}/main.err', f'{prepid}/main.log'))
print("Starting tasks...")
pool.close()
pool.join()