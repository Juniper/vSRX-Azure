#!/usr/bin/python
import sys
import json

param_file=sys.argv[1]
param_name=sys.argv[2]
with open(param_file) as data_file:    
    data = json.load(data_file)
try:
    value = data['parameters'][param_name]['value']
except:
    sys.stderr.write('cannot get parameter value\n')
else:
    print value
