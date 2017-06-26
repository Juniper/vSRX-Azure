#!/bin/sh

prog_name="$0"
location="westus"
tmp_parameter_file="/tmp/$$.azure.param.json"
deploy_nat_vm=1
template_file="./templates/vsrx-with-nat-vm/vsrx.json"
parameter_file="./templates/vsrx-with-nat-vm/vsrx.parameters.json"

usage()
{
    cat <<eof
Usage: $prog_name [options]
Deploy vSRX in Azure cloud
Command options:
    -g <resource-group>    Resource group name
    -l <location>          Deploy location
    -i <source-image>      Source image which copied to local storage account
    -f <template-file>     Azure template file
    -e <parameter-file>    Azure parameter file
    -h --help              Get help information
eof
}

error()
{
    echo "Error: $1" > /dev/stderr
    rm -f "$tmp_parameter_file"
    exit 1
}

while [ $# -gt 0 ]
do
    case $1 in
        -g)
        resource_group="$2"
        shift
        ;;
        -l)
        location="$2"
        shift
        ;;
        -i)
        source_image="$2"
        shift
        ;;
        -f)
        template_file="$2"
        shift
        ;;
        -e)
        parameter_file="$2"
        shift
        ;;
        --no-nat-vm)
        deploy_nat_vm=0
        ;;
        *)
        usage
        exit 0
        ;;
    esac
    shift
done

if [ -z "$resource_group" ]
then
    error "resource group is not defined"
fi

if [ ! -f "$template_file" ]
then
    error "template file $template_file doest not exist"
fi

if [ ! -f "$parameter_file" ]
then
    error "parameter file $parameter_file doest not exist"
fi

vsrx_name="`./utils/decode_param_file.py ${parameter_file} 'vsrx-name'`"
if [ -z "$vsrx_name" ]
then
     error "no parameter vsrx-name defined in $parameter_file"
fi

storage_account="`./utils/decode_param_file.py ${parameter_file} 'storageAccountName'`"
if [ -z "$storage_account" ]
then
     error "no parameter storageAccountName defined in $parameter_file"
fi

container_name="`./utils/decode_param_file.py ${parameter_file} 'storageContainerName'`"
if [ -z "$container_name" ]
then
     error "no parameter storageContainerName defined in $parameter_file"
fi

predefined_vsrx_disk="`./utils/decode_param_file.py ${parameter_file} 'vsrx-disk'`"
if [ -z "$source_image" -a -z "$predefined_vsrx_disk" ]
then
    error "no source image or vsrx-disk specified"
fi

azure config mode arm

group_str=`azure group list | egrep "\s$resource_group\s"`
if [ -z "$group_str" ]
then
    azure group create "$resource_group" "$location"
    if [ $? -ne 0 ]
    then
        error "can't create resource group"
    fi
else
    echo "Group $resource_group already exists"
fi

account_str=`azure storage account list | egrep "\s$storage_account\s" | egrep "\s$resource_group\s"`
if [ -z "$account_str" ]
then
    azure storage account create --sku-name LRS -l "$location" --kind Storage -g "$resource_group" "$storage_account"
    if [ $? -ne 0 ]
    then
        error "can't create storage account"
    fi
else
    echo "Storage account already exists"
fi

connection_str=`azure storage account connectionstring show "$storage_account" -g "$resource_group" | grep data | awk '{print $3}'`
if [ -z "$connection_str" ]
then
    error "can't get connection string"
fi

export AZURE_STORAGE_CONNECTION_STRING="$connection_str"

container_str=`azure storage container list | egrep "\s$container_name\s" | awk '{print $2}'`
if [ "$container_str" != "$container_name" ]
then
    azure storage container create "$container_name"
    if [ $? -ne 0 ]
    then
        error "can't create storage container"
    fi
else
    echo "Container already exists"
fi

deploy_parameters="$parameter_file"
if [ ! -z "$source_image" ]
then
    azure storage blob copy start "$source_image" "$container_name"
    if [ $? -ne 0 ]
    then
        error "can't copy source image to local storage"
    fi
    image_base_name=`basename "$source_image"`
    echo "Wait for image copy finished..."
    while :
    do
        status_str=`azure storage blob copy show "$container_name" "$image_base_name"`
        pending_str=`echo "$status_str" | grep pending`
        if [ -z "$pending_str" ]
        then
           break
        fi
        echo "$status_str"
        sleep 20
    done
    echo "Image copy done"
    ./utils/gen_param_file.py "$parameter_file" "$tmp_parameter_file" "$image_base_name"
    deploy_parameters="$tmp_parameter_file"
fi

azure group template validate -f "$template_file" -e "$deploy_parameters" -g "$resource_group"
if [ $? -ne 0 ]
then
    error "can't pass template file check"
fi

azure group deployment create -f "$template_file" -e "$deploy_parameters" -g "$resource_group" -n deployvsrx
if [ $? -ne 0 ]
then
    error "can't deploy with template file"
fi

if [ $deploy_nat_vm -ne 0 ]
then
    # vm-nat-vsrx-vpn6-eth0.westus.cloudapp.azure.com
    nat_vm_host="vm-nat-${vsrx_name}-eth0.${location}.cloudapp.azure.com"
    max_sec_wait=120
    sec_wait=0
    echo "Start to configure NAT VM, waiting for VM up, this may take several minutes..."
    echo "NAT VM public ip: $nat_vm_host"
    while [ $sec_wait -le $max_sec_wait ]
    do
        ping_str="`ping -c1 $nat_vm_host | grep 'ttl='`"
        if [ ! -z "$ping_str" ]
        then
            echo "Configuring NAT VM ..."
            sleep 3
            echo "./configure-nat-vm.py -e $parameter_file $nat_vm_host"
            ./configure-nat-vm.py -e "$parameter_file" "$nat_vm_host"
            if [ $? -ne 0 ]
            then
                error "fail to configure NAT VM"
            fi
            echo "Done"
            break
        fi
        sec_wait=`expr $sec_wait + 10`
        sleep 10
    done
    if [ $sec_wait -gt $max_sec_wait ]
    then
        error "NAT VM can't boot up"
    fi
fi

rm -f "$tmp_parameter_file"
exit 0

