### Creating an APP VM in trust-subnet

With the template and parameter json files, a virtual machine located in trust-subnet will be deployed. The APP VM could be managed through the public IP assigned to it.  
The template json file specifies all the parameters and resources of deploying an APP VM. We specify a CentOS 7 VM would be deployed in the template.  
The parameter json file provides all the value of mandatory parameters. User could modify the value in the parameter json file.

**The parameters including:**

-	storageAccountName: Name of storage account which will store the VHD file and intermediate files.
-	storageContainerName: Name of container which will store the VHD file of the VM.
-	vnet-name: Name of the virtual network the VM would connect.
-	vnet-mgt-subnet-name: Name of management subnet the eth0 of VM would connect.
-	vnet-trust-subnet-name: Name of trust subnet the eth1 of VM would connect.
-	vm-app-name: Name of the APP VM.
-	vm-app-addr-eth0: Name of public IP address object of eth0 on the APP VM.
-	vm-app-username: Username on the APP VM.
-	vm-app-password: Password of user.

After executing deploy-azure-vsrx.sh, which would create storage account and resource group, user may apply the json template and parameter file to deploy the APP VM directly.

**Steps of deploying the template with azure CLI:**

1.	azure login
2.	azure config mode arm
3.	azure group deployment create -f ./vm.json -e ./vm.parameters.json -g <resources_group_name> -n <deployment_name>
