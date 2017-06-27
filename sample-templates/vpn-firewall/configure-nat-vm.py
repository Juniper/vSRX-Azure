#!/usr/bin/python

import sys
import os
import re
import time
from optparse import OptionParser
import paramiko
import json
from random import randint

def ssh_connect(host, port, user, pwd):
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh.connect(host, port=port, username = user, password = pwd, \
            look_for_keys=False, allow_agent=False)
    except paramiko.SSHException:
        sys.stderr.write("SSH connection error")
        sys.exit(1)
    else:
        return ssh

def ssh_close(ssh):
    ssh.close()

usage = "Usage: configure-nat-vm.py <host-name>"
parser = OptionParser(usage = usage, version = "%prog 1.0")
parser.add_option("-e", "--parameters-file",
                  action="store", type = "string", dest = "parameters_file",
                  help = "Azure parameters file")
parser.add_option("-c", "--config-file",
                  action="store", type = "string", dest = "nat_config_file",
                  help = "NAT rules configuration file")
parser.add_option("-p", "--port",
                  action = "store", type = "int", dest = "ssh_port",
                  help = "Port number")
parser.add_option("-u", "--username",
                  action="store", type = "string", dest = "ssh_username",
                  help = "SSH login user name")
parser.add_option("-P", "--password",
                  action="store", type = "string", dest = "ssh_password",
                  help = "SSH login password")
(options, args) = parser.parse_args()

parameters_file = './templates/vsrx-with-nat-vm/vsrx.parameters.json'
nat_config_file = './nat_vm.conf'
ssh_port = 22
ssh_username = None
ssh_password = None

if options.parameters_file is not None:
    parameters_file = options.parameters_file

if options.nat_config_file is not None:
    nat_config_file = options.nat_config_file

if options.ssh_port is not None:
    ssh_port = options.ssh_port

if options.ssh_password is not None:
    ssh_password = options.ssh_password

if options.ssh_username is not None:
    ssh_username = options.ssh_username

if not os.path.isfile(parameters_file):
    sys.stderr.write('Parameters file does not exist\n')
    sys.exit(1)

if not os.path.isfile(nat_config_file):
    sys.stderr.write('NAT conf file does not exist\n')
    sys.exit(1)

with open(parameters_file) as data_file:
    azure_parameters = json.load(data_file)

if ssh_username is None:
    try:
        ssh_username = azure_parameters['parameters']['vm-nat-username']['value']
    except:
        sys.stderr.write('Cannot get vm-nat-username value from parameters file\n')
        sys.exit(1)

if ssh_password is None:
    try:
        ssh_password = azure_parameters['parameters']['vm-nat-password']['value']
    except:
        sys.stderr.write('Cannot get vm-nat-password value from parameters file\n')
        sys.exit(1)

try:
    vsrx_addr_ge_0_0_0 = azure_parameters['parameters']['vsrx-addr-ge-0-0-0']['value']
except:
    sys.stderr.write('Cannot get vsrx-addr-ge-0-0-0 value from parameters file\n')
    sys.exit(1)

try:
    vnet_nat_subnet_prefix = azure_parameters['parameters']['vnet-untrust-subnet-prefix']['value']
except:
    sys.stderr.write('Cannot get vnet-nat-subnet-prefix value from parameters file\n')
    sys.exit(1)

if len(args) < 1:
    sys.stderr.write('Need to specify remote hostname\n')
    sys.exit(1)
else:
    ssh_host = args[0]

nat_config_file_fd = open(nat_config_file, 'r')
tmp_nat_file = '/tmp/nat_vm_configure.%d' % randint(0,65535)
tmp_nat_file_fd = open(tmp_nat_file, 'w')
cmd_lines = nat_config_file_fd.readlines()
cmd_str = ''
for line in cmd_lines:
    cmd_str += line
cmd_str = re.sub('<vsrx-ge-0-0-0-ip>', vsrx_addr_ge_0_0_0, cmd_str) 
cmd_str = re.sub('<nat-subnet-prefix>', vnet_nat_subnet_prefix, cmd_str)
cmd_str = re.sub('<password>', ssh_password, cmd_str)
ssh_conn = ssh_connect(ssh_host, ssh_port, ssh_username, ssh_password)
sftp = ssh_conn.open_sftp()
tmp_nat_file_fd = open(tmp_nat_file, 'w')
tmp_nat_file_fd.write(cmd_str)
tmp_nat_file_fd.close()
sftp.put(tmp_nat_file, "configure_nat_vm.sh")
os.unlink(tmp_nat_file)
remote_shell = ssh_conn.invoke_shell()
cmd = 'echo "%s" | sudo -S sh ./configure_nat_vm.sh\n' % ssh_password
remote_shell.send(cmd)
time.sleep(5)
ssh_close(ssh_conn)
sys.exit(0)

