INTRODUCTION
============

This package contains the tools and templates which help user deploy vSRX in Azure cloud as a security gateway.

   - deploy-azure-vsrx.sh
   - templates

   deploy-azure-vsrx.sh is the tool which helps user setup vSRX and virtual networks with a single command.

   templates directory is used to store standard Azure resource template files. Change the parameters in \*.parameters.json to customize your vSRX and virtual network parameters.



TOPOLOGY
--------

Below is a diagram describing how to deploy vSRX in Azure cloud. 

```
internet -----+-------------------------------------------vnet/mgt-subnet-------------------------------------------------+
              |                                                  |                                                        |
              |                                                 fxp0                                                      |
              |                                                  |                                                        |
              |                                         ge-0/0/0 |  ge-0/0/1                                    eth1     eth0
              +------------- vnet/unstrust-subnet <---------> vsrx-gw <----------> vnet/trust-subnet <----------> app-vm-in-backend


       vsrx-gw     : a VM used to host vSRX which running as a security gateway in this case
       vnet        : virtual network which has 3 subnet, mgt-subnet/untrust-subnet/trust-subnet
       mgt-subnet  : all mamanagment interfaces of those VMs will connect to management subnet. According to configuration in
                     vsrx.json, there will be public IPs allocated for those interfaces connected to mgt-subnet
       untrust-subnet  : a subnet used to connect vSRX revenue ports with Internet
       trust-subnet  : a subnet used to inter-connect VMs which are behind vsrx.
```

REQUIREMENTS
------------

-	[Install Azure CLI 1.0](https://docs.microsoft.com/en-us/azure/cli-install-nodejs)


COMMAND LINE OPTIONS AND EXAMPLE
--------------------------------

### Deploy vSRX and configure virtual networks with a single command

```
   Command line options:
   #./deploy-azure-vsrx.sh --help
   usage: ./deploy-azure-vsrx.sh [options]
   Deploy vSRX in Azure cloud
   Command options:
       -g <resource-group>    Resource group name
       -l <location>          Deploy location
       -i <source-image>      Source image which copied to local storage account
       -p <ssh-public-key>    SSH public key file of login user
       -f <template-file>     Azure template file
       -e <parameter-file>    Azure parameter file
       -h --help              Get help information
```

If -g is not specified, it will use "vsrx" by default. If -l, -f and -e are not specified, they will use "westus", template file "templates/vsrx-gateway/vsrx.json" and parameter file "templates/vsrx-gateway/vsrx.parameters.json" by default.

   Example of deploy vSRX:
```
   # ./deploy-azure-vsrx.sh -g juniper
```

   Example of deploy vSRX with user ssh public key:
```
   # ./deploy-azure-vsrx.sh -g juniper -p ~user/.ssh/id_rsa.pub
```

   Example of deploy vSRX with private vsrx image:
```
   # ./deploy-azure-vsrx.sh -g juniper -i https://jimmyzhai.blob.core.windows.net/vhds/media-srx-mr-20161108.vhd
```

### Create an APP VM in trust-subnet
   Example:
```
   # cd templates/app-vm/
   # azure group deployment create -f ./vm.json -e ./vm.parameters.json -g juniper -n appvm
```

