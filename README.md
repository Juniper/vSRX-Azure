INTRODUCTION
============

This package contains some tools and templates which helps user deploy vSRX in Azure cloud as a VPN gateway.

-	deploy-azure-vsrx.sh
-	configure-nat-vm.py
-	templates

deploy-azure-vsrx.sh is a tool which helps user setup vSRX/NAT VM/Virtual network with s single command. It will also invoke configure-nat-vm.py to configure NAT-VM automatically.

configure-nat-vm.py is a tool which configures NAT VM automatically. NAT VM configuaration is in nat_vm.conf. This command will be invoked when deploy vSRX with deploy-azure-vsrx.sh so user don't need to configure NAT VM manually.

templates directory is used to store standard Azure resource templates. Change the parameters in \*.parameters.json to customize your vSRX and virtual network parameters.

TOPOLOGY with NAT VM
--------------------

Below is a diagram describing how to deploy vSRX in Azure cloud with front-end NAT VM.

With the limitation of Azure cloud implementation, a VM can only assoicate one public IP now. There is already a public IP address allocated for fxp0. If vSRX need to receive traffic from internet , it needs a front-end NAT VM receives packets from Internet with destination NAT and then forward packets to vSRX interface.

```
internet 
      +
      |
      |                        (mgt-subnet)
      +-----------------------------vnet-----------------------------------------+
      |                              |                                           |
      |                             fxp0                                         |
      |                             |                                            |
     eth0   eth1           ge-0/0/0 |  ge-0/0/1                         eth1    eth0
     vm-nat <-----> vnet <-------> vsrx-vpn-gw <---------> vnet <---------> app-vm-in-vpn
                (untrust-subnet)                        (trust-subnet)

vsrx-vpn-gw : a VM used to host vSRX which running as a VPN gateway in this case
vm-nat      : a VM used to host D-NAT service
vnet        : virtual network which has 3 subnet, mgt-subnet/untrust-subnet/trust-subnet
mgt-subnet  : all mamanagment interfaces of those VMs will connect to management subnet. According to configuration in
vsrx.json, there will be public IPs allocated for those interfaces connected to mgt-subnet
untrust-subnet  : a subnet used to connect vsrx-vpn-gw and vm-nat
trust-subnet  : a subnet used to inter-connect VMs which are inside VPN. Traffic in this subnet is clear-text.
```

REQUIREMENTS
------------

-	[Install Azure CLI](https://docs.microsoft.com/en-us/azure/xplat-cli-install)
-	Install python module paramiko  

```
 # pip install paramiko
```

COMMAND LINE OPTIONS AND EXAMPLE
--------------------------------

### Deploy vSRX/NAT VM/virtual network with a single command

```
Command line options: #./deploy-azure-vsrx.sh --help
usage: ./deploy-azure-vsrx.sh [options]
Deploy vSRX in Azure cloud
Command options:
    -g <resource-group>   Resource group name
    -l <location>         Deploy location
    -i <source-image>     Source image which copied to local storage account
    -f <template-file>    Azure template file
    -e <parameter-file>   Azure parameter file
    --no-nat-vm           Deploy vSRX without frontend NAT VM
    -h --help             Get help information
```

Example of deploy vSRX with a front-end NAT VM:

```
# ./deploy-azure-vsrx.sh -g juniper -i  https://jnprvsrx.blob.core.windows.net/vsrx/media-vsrx-vmdisk-151X49D80.vhd
```

Example of deploy vSRX WITHOUT a front-end NAT VM:

```
# ./deploy-azure-vsrx.sh --no-nat-vm -l westcentralus -g juniper -i https://jnprvsrx.blob.core.windows.net/vsrx/media-vsrx-vmdisk-151X49D80.vhd
```

### Configure NAT VM

You can skip this if NAT VM is configured automatically by deploy-azure-vsrx.sh

```
Command line options:
# ./configure-nat-vm.py -h
Usage: configure-nat-vm.py <host-name>

Options:
    --version     show program's version number and exit
    -h, --help    show this help message and exit
    -e PARAMETERS_FILE, --parameters-file=PARAMETERS_FILE Azure parameters file
    -c NAT_CONFIG_FILE, --config-file=NAT_CONFIG_FILE NAT rules configuration file
    -p SSH_PORT, --port=SSH_PORT Port number
    -u SSH_USERNAME, --username=SSH_USERNAME SSH login user name 
    -P SSH_PASSWORD, --password=SSH_PASSWORD SSH login password

Example: # ./configure-nat-vm.py vm-nat-vsrx-vpn-eth0.westus.cloudapp.azure.com
```

### Create an APP VM in trust-subnet

```
Example:
# cd templates/app-vm-in-vpn/ # azure group deployment create -f ./vm.json -e ./vm.parameters.json -g juniper -n appvm
```
