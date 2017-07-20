#!/usr/bin/python
import sys
import json
from optparse import OptionParser

parser = OptionParser(usage="usage: %prog [options] <src param file> <dest param file>", add_help_option=False)
parser.add_option("-h", "--help", action="help", help="show this help message")
parser.add_option("-i", "--image",
          action="store", dest="image", default=None, type="string",
          help="image base name")
parser.add_option("-p", "--publickey",
          action="store", dest="publickey", default=None, type="string",
          help="ssh public key string")
(options, args) = parser.parse_args()

if len(args) < 2:
    print "Please specify src and dst param file"
    sys.exit(1)

src_file = args[0]
dst_file = args[1]

with open(src_file) as data_file:    
    data = json.load(data_file)
try:
    if options.image:
        data['parameters']['vsrx-disk'] = {'value': options.image}

    if options.publickey:
        data['parameters']['vsrx-sshkey'] = {'value': open(options.publickey).read().rstrip()}
except:
    sys.stderr.write('cannot change parameter value\n')

with open(dst_file, 'w') as outfile:
    json.dump(data, outfile, indent=4)
