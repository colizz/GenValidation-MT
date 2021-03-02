#!/usr/bin/env python3

def modify(path, mode):
    if not isinstance(mode, (list, tuple)):
        mode = [mode]
    assert all([t in ['mg_mult', 'mg_gp_conc', 'pythia_conc'] for t in mode])

    with open(path) as f:
        lines = f.readlines()

    for i, line in enumerate(lines):
        if 'pythia_conc' in mode and 'Pythia8HadronizerFilter' in line:
            lines[i] = lines[i].replace('Pythia8HadronizerFilter', 'Pythia8ConcurrentHadronizerFilter')
        if 'mg_mult' in mode and 'run_generic_tarball_cvmfs.sh' in line:
            lines[i] = lines[i].replace('run_generic_tarball_cvmfs.sh', 'run_generic_tarball_cvmfs_madgraphLO_multithread.sh')
        if 'mg_gp_conc' in mode and 'run_generic_tarball_cvmfs.sh' in line:
            lines[i] = '    generateConcurrently = cms.untracked.bool(True),\n' + lines[i]

    with open(path, 'w') as fw:
        fw.write(''.join(lines))

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('-i', '--inputfile', help='Input cfg file')
    parser.add_argument('--mg-mult', action='store_true', help='Apply MadGraph internal multithread')
    parser.add_argument('--mg-gp-conc', action='store_true', help='Apply concurrent run for MadGraph gridpack')
    parser.add_argument('--pythia-conc', action='store_true', help='Apply concurrent run for Pythia')
    args = parser.parse_args()

    mode = [t for t in ['mg_mult', 'mg_gp_conc', 'pythia_conc'] if getattr(args, t)==True]
    modify(path=args.inputfile, mode=mode)