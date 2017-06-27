#!/usr/bin/python
import sys
import json

src_file = sys.argv[1]
dst_file = sys.argv[2]
disk_basename = sys.argv[3]
with open(src_file) as data_file:    
    data = json.load(data_file)
try:
    data['parameters']['vsrx-disk'] = {'value': disk_basename}
except:
    sys.stderr.write('cannot change parameter value\n')

with open(dst_file, 'w') as outfile:
    json.dump(data, outfile)
