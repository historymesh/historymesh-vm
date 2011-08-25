#!/usr/bin/env python
from __future__ import print_function
import sys
import os
from os.path import split
from ConfigParser import ConfigParser
from subprocess import check_call
from functools import partial


print_stderr = partial(print, file=sys.stderr)

directory, filename = split(sys.argv[1])

if directory:
    print_stderr('Changing to %s' % directory)
    os.chdir(directory)

cp = ConfigParser()
good_reads = cp.read(filename)
if good_reads != [filename]:
    print_stderr('Failed to open %s' % filename)
    sys.exit(1)

for generated_file in cp.sections():
    with open(generated_file, mode='w') as file_out:
        command = cp.get(generated_file, 'command')
        print_stderr('Running command %r' % command)
        check_call(command, env=os.environ, shell=True, stdout=file_out)
    print_stderr('Generated %s' % generated_file, file=sys.stderr)
