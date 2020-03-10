#!/bin/sh

prog_name="$0"
prog_dir="`dirname $0`"
location="westus"
tmp_parameter_file="/tmp/$$.azure.param.json"
tmp_template_file="/tmp/$$.azure.template.json"
template_file="$prog_dir/templates/vsrx-gateway/vsrx.json"
parameter_file="$prog_dir/templates/vsrx-gateway/vsrx.parameters.json"
customdata_raw=""
customdata_file=""
customdata=""

usage()
{
    cat <<eof
Usage: $prog_name [options]
Deploy vSRX in Azure cloud
Command options:
    -g <resource-group>    Resource group name
    -l <location>          Deploy location
    -i <source-image>      Source image which copied to local storage account
    -p <ssh-public-key>    SSH public key file of login user
    -f <template-file>     Azure template file
    -e <parameter-file>    Azure parameter file
    -c <customData-file>   File including the custom data in json fomat
    -r <customeData-raw>   File including the raw custom data
    -h --help              Get help information
eof
}

error()
{
    echo "Error: $1" > /dev/stderr
    rm -f "$tmp_parameter_file" "$tmp_template_file"
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
        -p)
        ssh_public_key="$2"
        [ ! -f "$2" ] && error "ssh public key file $2 does not exist"
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
        -c)
        customdata_file="$2"
        shift
        ;;
        -r)
        customdata_raw="$2"
        shift
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
    resource_group="vsrx"
    echo "Use default resource group name 'vsrx'"
fi

if [ ! -f "$template_file" ]
then
    error "template file $template_file does not exist"
fi

if [ ! -f "$parameter_file" ]
then
    error "parameter file $parameter_file doest not exist"
fi

if [ "$customdata_file" ]
then
    test "$customdata_raw" && error "customdata file and raw file cannot be used at the same time"
    test -f "$customdata_file" || error "custom data file $customdata_file does not exist"
    # Get the absolute path of the customdata file
    customdata_file=`readlink -f ${customdata_file}`
    gen_param_cmd_param+=' -c '"$customdata_file"
    gen_template_cmd_param+=' -c'
fi

if [ "$customdata_raw" ]
then
    test "$customdata_file" && error "customdata file and raw file cannot be used at the same time"
    test -f "$customdata_raw" || error "custom data raw file $customdata_raw does not exist"
    # Get the absolute path of the customdata file
    customdata_raw=`readlink -f ${customdata_raw}`
    gen_param_cmd_param+=' -r '"$customdata_raw"
    gen_template_cmd_param+=' -c'
fi


vsrx_name="`$prog_dir/utils/decode_param_file.py ${parameter_file} 'vsrx-name'`"
if [ -z "$vsrx_name" ]
then
     error "no parameter vsrx-name defined in $parameter_file"
fi

storage_account="`$prog_dir/utils/decode_param_file.py ${parameter_file} 'storageAccountName'`"
if [ -z "$storage_account" ]
then
     error "no parameter storageAccountName defined in $parameter_file"
fi

container_name="`$prog_dir/utils/decode_param_file.py ${parameter_file} 'storageContainerName'`"
if [ -z "$container_name" ]
then
     error "no parameter storageContainerName defined in $parameter_file"
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

account_str=`azure storage account list | egrep "\s$storage_account\s" | egrep "\s$resource_group\s*$"`
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

    gen_param_cmd_param+=' -i '"$image_base_name"
    gen_template_cmd_param+=' -i'
fi

if [ ! -z "$ssh_public_key" ]; then
    gen_param_cmd_param+=' -p '"$ssh_public_key"
    gen_template_cmd_param+=' -p'
fi

deploy_parameters="$parameter_file"
deploy_template="$template_file"
if [ ! -z "$gen_template_cmd_param" ]; then
    deploy_parameters="$tmp_parameter_file"
    deploy_template="$tmp_template_file"
    $prog_dir/utils/gen_param_file.py $gen_param_cmd_param "$parameter_file" "$tmp_parameter_file"
    $prog_dir/utils/gen_template_file.py $gen_template_cmd_param "$template_file" "$tmp_template_file" 
fi

azure group template validate -f "$deploy_template" -e "$deploy_parameters" -g "$resource_group"
if [ $? -ne 0 ]
then
    error "can't pass template file check"
fi

azure group deployment create -f "$deploy_template" -e "$deploy_parameters" -g "$resource_group" -n deployvsrx
if [ $? -ne 0 ]
then
    error "can't deploy with template file"
fi

rm -f "$tmp_parameter_file" "$tmp_template_file"
exit 0

