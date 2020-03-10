#!/usr/bin/python
import sys
import json
from optparse import OptionParser

parser = OptionParser(usage="usage: %prog [options] <src template file> <dest template file>", add_help_option=False)
parser.add_option("-h", "--help", action="help", help="show this help message")
parser.add_option("-i", "--image", action="store_true",
                  dest="image_flag", default=False, help="Use private image")
parser.add_option("-p", "--publickey", action="store_true",
                  dest="publickey_flag", default=False, help="Use public key")
parser.add_option("-c", "--customdata",action="store_true", 
		  dest="customdata_flag", default=False, help="custom data")
(options, args) = parser.parse_args()

if len(args) < 2:
    print "Please specify src and dst template file"
    sys.exit(1)

src_file = args[0]
dst_file = args[1]

def vsrx_update_profile(vsrx, vsrx_in_vmss = False):
    if vsrx_in_vmss:
        properties = vsrx['properties']['virtualMachineProfile']
    else:
        properties = vsrx['properties']

    if options.image_flag:
        vsrx.pop('plan', None)
        properties['storageProfile'].pop('imageReference', None)
        properties['storageProfile']['osDisk']['image'] = { "uri": "[variables('vsrxVM').baseDisk]" }

    if options.publickey_flag:
        publickey_json = '''
                  {
                    "publicKeys": [
                      {
                        "path": "[concat('/home/', parameters('vsrx-username'), '/.ssh/authorized_keys')]",
                        "keyData": "[parameters('vsrx-sshkey')]"
                      }
                    ]
                  }
        '''
        properties['osProfile'].pop('adminPassword', None)
        properties['osProfile']['linuxConfiguration']['disablePasswordAuthentication'] = 'true'
        properties['osProfile']['linuxConfiguration']['ssh'] = json.loads(publickey_json)

    if options.customdata_flag:
        properties['osProfile']['customData'] = "[base64(parameters('customData'))]"


with open(src_file) as data_file:    
    data = json.load(data_file)
try:
    vm = filter(lambda x: x['type'] == 'Microsoft.Compute/virtualMachines' and 
                          x['tags'] == "VSRX", data['resources'])
    for vsrx in vm:
        vsrx_update_profile(vsrx)

    vm = filter(lambda x: x['type'] == 'Microsoft.Compute/virtualMachineScaleSets',
                          x['tags'] == "VSRX", data['resources'])
    for vsrx in vm:
        vsrx_update_profile(vsrx, True)

except:
    sys.stderr.write('cannot change template file\n')

with open(dst_file, 'w') as outfile:
    json.dump(data, outfile, indent=4)
