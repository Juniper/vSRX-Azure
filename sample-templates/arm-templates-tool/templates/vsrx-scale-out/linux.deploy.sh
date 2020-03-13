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

while [ $# -gt 0 ]
do
    case $1 in
        -w|--web)
        web_cloud_init
        ;;
        -h|--help)
        usage
        exit 0
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
    exit 1
fi

# Create NICs
az network nic create \
    --resource-group $GROUP_NAME \
    --name myNicWest \
    --vnet-name myVnet \
    --subnet WEST \
    --network-security-group myNSG \

az network nic create \
    --resource-group $GROUP_NAME \
    --name myNicEast \
    --vnet-name myVnet \
    --subnet EAST \
    --network-security-group myNSG \

# Create backend servers
 az vm create \
   --resource-group $GROUP_NAME \
   --name myVMwest\
   --nics myNicWest\
   --image UbuntuLTS \
   --admin-username demo --admin-password Demo123456@@ \
   --generate-ssh-keys \
   $AZURE_CMD_PARAM --no-wait

 az vm create \
   --resource-group $GROUP_NAME \
   --name myVMeast\
   --nics myNicEast\
   --image UbuntuLTS \
   --admin-username demo --admin-password Demo123456@@ \
   --generate-ssh-keys \
   $AZURE_CMD_PARAM --no-wait

if [ -f $CLOUD_INIT_FILE ]; then
    rm -f $CLOUD_INIT_FILE
fi
