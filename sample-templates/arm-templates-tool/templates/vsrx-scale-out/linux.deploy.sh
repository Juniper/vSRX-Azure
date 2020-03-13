#!/bin/sh

GROUP_NAME=
AZURE_CMD_PARAM=
CLOUD_INIT_FILE=/tmp/web-cloud-init-$$.txt

usage()
{
    cat <<eof
Usage: $0 [-w|--web] [-h|--help] <azure resource group name>
Deploy Linux server in Azure cloud
Command options:
    -w --web     Install a web server after deployment
    -h --help    Get help information
eof
}

web_cloud_init()
{
    cat <<eof > $CLOUD_INIT_FILE
#cloud-config
package_upgrade: true
packages:
  - nginx
  - nodejs
  - npm
write_files:
  - owner: www-data:www-data
  - path: /etc/nginx/sites-available/default
    content: |
      server {
        listen 80;
        location / {
          proxy_pass http://localhost:3000;
          proxy_http_version 1.1;
          proxy_set_header Upgrade \$http_upgrade;
          proxy_set_header Connection keep-alive;
          proxy_set_header Host \$host;
          proxy_cache_bypass \$http_upgrade;
        }
      }
  - owner: azureuser:azureuser
  - path: /home/azureuser/myapp/index.js
    content: |
      var express = require('express')
      var app = express()
      var os = require('os');
      app.get('/', function (req, res) {
        res.send('Hello World from host ' + os.hostname() + '!')
      })
      app.listen(3000, function () {
        console.log('Hello world app listening on port 3000!')
      })
runcmd:
  - service nginx restart
  - cd "/home/azureuser/myapp"
  - npm init
  - npm install express -y
  - nodejs index.js
eof

AZURE_CMD_PARAM+=" --custom-data $CLOUD_INIT_FILE" 
}

quit()
{
    if [ -f $CLOUD_INIT_FILE ]; then
        rm -f $CLOUD_INIT_FILE
    fi
    exit $1
}

while [ $# -gt 0 ]
do
    case $1 in
        -w|--web)
        web_cloud_init
        ;;
        -h|--help)
        usage
        quit 0
        ;;
        *)
        break
        ;;
    esac
    shift
done

if [ $# -gt 0 ]; then
    GROUP_NAME=$1
else
    usage
    quit 1
fi

LOCATION=`azure group list | grep -w $GROUP_NAME | awk '{printf $3}'`
if [ -z $LOCATION ]; then
    echo "Azure resource group $GROUP_NAME not found!"
    quit 1
fi

ACCOUNT=`azure storage account list | grep -w $GROUP_NAME | awk '{print $2}'`

# Create NICs
azure network nic create \
    --resource-group $GROUP_NAME \
    --location $LOCATION \
    --name myNicWest \
    --subnet-vnet-name myVnet \
    --subnet-name WEST \
    --network-security-group-name myNSG \

azure network nic create \
    --resource-group $GROUP_NAME \
    --location $LOCATION \
    --name myNicEast \
    --subnet-vnet-name myVnet \
    --subnet-name EAST \
    --network-security-group-name myNSG \

# Create backend servers
azure vm create \
   --resource-group $GROUP_NAME \
   --location $LOCATION \
   --name myVMwest\
   --nic-name myNicWest\
   --storage-account-name $ACCOUNT \
   --os-type Linux --image-urn Canonical:UbuntuServer:18.04-LTS:latest \
   --disable-boot-diagnostics \
   --admin-username demo --admin-password Demo123456@@ \
   --generate-ssh-keys \
   $AZURE_CMD_PARAM

azure vm create \
   --resource-group $GROUP_NAME \
   --location $LOCATION \
   --name myVMeast\
   --nic-name myNicEast\
   --storage-account-name $ACCOUNT \
   --os-type Linux --image-urn Canonical:UbuntuServer:18.04-LTS:latest \
   --disable-boot-diagnostics \
   --admin-username demo --admin-password Demo123456@@ \
   --generate-ssh-keys \
   $AZURE_CMD_PARAM

quit 0
