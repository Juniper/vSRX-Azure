#!/usr/bin/python
import sys
import json
import yaml
from optparse import OptionParser

parser = OptionParser(usage="usage: %prog [options] <src param file> <dest param file>", add_help_option=False)
parser.add_option("-h", "--help", action="help", help="show this help message")
parser.add_option("-i", "--image",
          action="store", dest="image", default=None, type="string",
          help="image base name")
parser.add_option("-p", "--publickey",
          action="store", dest="publickey", default=None, type="string",
          help="ssh public key string")
parser.add_option("-c", "--customdata",
          action="store", dest="customdata", default=None, type="string",
          help="custom data content")
parser.add_option("-r", "--rawcustomdata",
          action="store", dest="rawcustomdata", default=None, type="string",
          help="custom data raw content")
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

    if options.customdata:
        custom_data = ''
        with open(options.customdata, 'r') as f:
           cloudinit_data = json.load(f) 

        custom_data = yaml.dump(yaml.load(json.dumps(cloudinit_data, sort_keys=False, indent=4), Loader=yaml.FullLoader))
        custom_data = '#cloud-config\n' + custom_data
        print custom_data 
        data['parameters']['customData'] = {'value': custom_data}

    if options.rawcustomdata:
        custom_data_list=[]
        with open(options.rawcustomdata, 'r') as f:
            line=f.readline()
            while line:
                custom_data_list.append(line)
                line=f.readline()

        custom_data=''.join(x for x in custom_data_list)
        print custom_data 
        data['parameters']['customData'] = {'value': custom_data}

except:
    sys.stderr.write('cannot change parameter value\n')

with open(dst_file, 'w') as outfile:
    json.dump(data, outfile, indent=4)
