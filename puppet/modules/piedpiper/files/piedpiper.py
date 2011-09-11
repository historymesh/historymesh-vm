#!/usr/bin/env python

from __future__ import print_function
import sys
import os
from os.path import dirname, abspath, join
from ConfigParser import ConfigParser
import subprocess
from functools import partial
import cgi

import cgitb; cgitb.enable()  # Enable tracebacks

CONFIG_DIR = dirname(dirname(abspath(__file__)))
CONFIG_FILE = 'pipe_runner.conf'
PATH_PREFIX = 'antler/'

print_stderr = partial(print, file=sys.stderr)


def get_content_type(path):
    if path.endswith('.css'):
        return 'text/css'
    if path.endswith('.js'):
        return 'application/javascript'
    return DEFAULT_TYPE


os.chdir(CONFIG_DIR)


# Read in the generated file names from the config
cp = ConfigParser()
good_reads = cp.read(CONFIG_FILE)
if good_reads != [CONFIG_FILE]:
    print_stderr('Failed to open %s' % CONFIG_FILE)
    sys.exit(1)

params = cgi.FieldStorage()

if 'path' not in params:
    print_stderr('Missing expected parameter "path": 400ing')
    print('Status: 400 Bad Request')
    print('Content-Type: text/plain')
    print()
    print('Missing expected parameter "path".')
    sys.exit(1)

file_path = join(PATH_PREFIX, params.getvalue('path'))


if file_path not in cp.sections():
    print_stderr('Path "%s" not found' % file_path)
    print('Status: 404 Not Found')
    print('Content-Type: text/plain')
    print()
    print('Path "%s" not found' % file_path)
    sys.exit(1)


generator_command = cp.get(file_path, 'command')
print_stderr('Running command %r' % generator_command)

# Leave stderr to go to this program's stderr

# WARNING: this will run any program given to it by the pipe_runner.conf file;
# even thought this will be running as the Apache user, this is a gaping
# security hole. If you even think about using this anywhere near production,
# I may have to come over there and nut you.
generator = subprocess.Popen(generator_command, stdout=subprocess.PIPE, shell=True)
generated_file, _ = generator.communicate()

if generator.returncode:
    print_stderr('Subprocess failed with code %d' % generator.returncode)
    sys.exit(1)

print('Content-Type: %s' % get_content_type(file_path))
print()
print(generated_file)
