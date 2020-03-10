#!/bin/sh
# Generate vsrx configuration for east-west use case

parameter_file="./templates/vsrx-scale-out/vsrx.scale.parameters.json"

LB_PROBE_IP=168.63.129.16
ILB_INTERFACE=ge-0/0/0
WEST_SUBNET=`./utils/decode_param_file.py ${parameter_file} vnet-west-subnet-prefix`
EAST_SUBNET=`./utils/decode_param_file.py ${parameter_file} vnet-east-subnet-prefix`
SOUTH_SUBNET=`./utils/decode_param_file.py ${parameter_file} vnet-south-subnet-prefix`
ILB_AZURE_GATEWAY=${SOUTH_SUBNET//0\/*/1}

cat <<EOF
#cloud-config

write_files:
    - content: |
        configure
        set interfaces $ILB_INTERFACE unit 0 family inet dhcp
        set routing-instances ilb instance-type virtual-router
        set routing-instances ilb routing-options static route $LB_PROBE_IP/32 next-hop $ILB_AZURE_GATEWAY
        set routing-instances ilb routing-options static route $WEST_SUBNET next-hop $ILB_AZURE_GATEWAY
        set routing-instances ilb routing-options static route $EAST_SUBNET next-hop $ILB_AZURE_GATEWAY
        set routing-instances ilb interface $ILB_INTERFACE.0
        set security zones security-zone trust host-inbound-traffic system-services all
        set security zones security-zone trust host-inbound-traffic protocols all
        set security zones security-zone trust interfaces ${ILB_INTERFACE}.0 
        set security policies default-policy permit-all
        commit
      path: /var/tmp/vsrx_scale_out_config

runcmd:
    - cli < /var/tmp/vsrx_scale_out_config

EOF
