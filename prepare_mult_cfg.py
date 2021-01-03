#!/usr/bin/env python3

import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-i', '--inputfile', help='Input cfg file')
parser.add_argument('--mg-mult', action='store_true', help='Apply MadGraph internal multithread')
parser.add_argument('--mg-gp-conc', action='store_true', help='Apply concurrent run for MadGraph gridpack')
parser.add_argument('--pythia-conc', action='store_true', help='Apply concurrent run for Pythia')
args = parser.parse_args()

with open(args.inputfile) as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if args.pythia_conc and 'Pythia8HadronizerFilter' in line:
        lines[i] = lines[i].replace('Pythia8HadronizerFilter', 'Pythia8ConcurrentHadronizerFilter')
    if args.mg_mult and 'run_generic_tarball_cvmfs.sh' in line:
        lines[i] = lines[i].replace('run_generic_tarball_cvmfs.sh', 'run_generic_tarball_cvmfs_madgraphLO_multithread.sh')
    if args.mg_gp_conc and 'run_generic_tarball_cvmfs.sh' in line:
        lines[i] = '    generateConcurrently = cms.untracked.bool(True),\n' + lines[i]

with open(args.inputfile, 'w') as fw:
    fw.write(''.join(lines))