#!/usr/bin/env python3

import requests
import itertools
import warnings
warnings.filterwarnings('ignore')

group = ['B2G', 'BPH', 'BTV', 'EGM', 'EXO', 'HIG', 'JME', 'PPD', 'SMP', 'SUS', 'TAU', 'TOP', 'TRK']
store_list = {g: [] for g in group}
name_last = ''
for gro, ul, yy in itertools.product(group, ['19', '20'], ['16', '17']):
    for i in range(1, 10000):
        prepid = f'{gro}-RunIISummer{ul}UL{yy}wmLHEGEN-{str(i).zfill(5)}'
        r = requests.get(f'https://cms-pdmv.cern.ch/mcm/public/restapi/requests/output/{prepid}', verify=False).json() # insecure...
        if prepid not in r.keys():
            ## reach the end of prepid request
            break
        try:
            name = r[prepid][0].split('/')[1]
            if name[:6] != name_last[:6]:
                ## ensure the two adjacent requests are not similar ones
                store_list[gro].append((prepid, name))
                print('satisfied: ', prepid, name)
            name_last = name
        except:
            continue

write_list = [
    prepid+' '+name+'\n' for gro in group for prepid, name in store_list[gro] 
]

with open('prepid_list.txt', 'w') as fw:
    fw.write(''.join(write_list))

import random
write_list_orig = write_list.copy()
random.shuffle(write_list)
with open('prepid_list_random.txt', 'w') as fw:
    fw.write(''.join(write_list))