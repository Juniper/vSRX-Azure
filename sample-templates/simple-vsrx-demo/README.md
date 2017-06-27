This template launches a vSRX instance from the vSRX image available at the Azure Marketplace. It also launches other resources necessary to launch a vSRX (such as VNet, Route tables, etc). However if there are existing resources, then the template should be modified to skip creating those existing resources. Please keep in mind that the sole purpose of this template is to demonstrate how a custom template can be built to launch vSRX instances. The tolpolgy/dependency presented in this template is for the sole purpose of just providing an example and may vary due to customers' differing environments.

Ensure that the default values in the vsrx.parameters.json file match your desired values. Modify if otherwise.To deploy this template, run the below command from the Azure cli:

azure group deployment create --template-file vsrx.json --parameters-file vsrx.parameters.json --resource-group <resource-group-name> --name <deployment-name>
