### Creating a vSRX and a VM for NAT in topology with NAT VM

User may create a vSRX and a VM as in the topology with NAT VM with the template and the parameter json files.  
The template json file specifies all the parameters and resources of deploying a vSRX and a virtual machine used for NAT.  
The paramter json file provides all the value of mandatory parameters about the vSRX and the VM for NAT. User could modify the value in the parameter json file.

**The parameters including:**

-	storageAccountName: Name of storage account which will store the resources needed.
-	storageContainerName: Name of container which stores the VHD file.
-	vsrx-name: Name of vSRX.
-	vsrx-addr-ge-0-0-0: Private IP address of ge-0/0/0 on vSRX.
-	vsrx-addr-ge-0-0-1: Private IP address of ge-0/0/1 on vSRX.
-	vsrx-username: Username on vSRX.
-	vsrx-password: Password of above user on vSRX.
-	vsrx-disk: Name of vSRX VHD file to be depolyed in the storage container. This value will be ignored when deploy-azure-vsrx.sh script assigns source image location with "-i" option.
-	vnet-prefix: Network prefix of virtual network.
-	vnet-mgt-subnet-basename: Name of management subnet of virtual network.
-	vnet-mgt-subnet-prefix: Network prefix of management subnet.
-	vnet-trust-subnet-basename: Name of trust subnet of virtual network.
-	vnet-trust-subnet-prefix: Network prefix of trust subnet.
-	vnet-untrust-subnet-basename: Name of untrust subnet of virtual network.
-	vnet-untrust-subnet-prefix: Network prefix of untrust subnet.
-	vm-nat-addr-eth1: Private IP address of eth1 on the NAT VM connecting to the untrust subnet.
-	vm-nat-username: User name on the NAT VM.
-	vm-nat-password: Password of the above user.

Similarly, user may execute deploy-azure-vsrx.sh without specify "--no-nat-vm" option, and the template would be applied by default.

An example of deploying a complete topoloty with NAT VM:

```
1. azure login
2. ./deploy-azure-vsrx.sh -g juniper -l westus -i https://jnprvsrx.blob.core.windows.net/vsrx/media-vsrx-vmdisk-151X49D80.vhd
3. cd templates/app-vm-in-vpn/
4. azure group deployment create -f ./vm.json -e ./vm.parameters.json -g juniper -n appvm
```
