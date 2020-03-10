#!/bin/sh
# Generate vsrx configuration for sourth-north use case

parameter_file="./templates/vsrx-scale-out/vsrx.scale.parameters.json"

# Temp fake IP, replace it with real pLB public IP after booting up
PLB_PUBLIC_IP=1.1.1.1
LB_PROBE_IP=168.63.129.16

PLB_INTERFACE=ge-0/0/1
ILB_INTERFACE=ge-0/0/0
WEST_SUBNET=`./utils/decode_param_file.py ${parameter_file} vnet-west-subnet-prefix`
EAST_SUBNET=`./utils/decode_param_file.py ${parameter_file} vnet-east-subnet-prefix`
NORTH_SUBNET=`./utils/decode_param_file.py ${parameter_file} vnet-north-subnet-prefix`
SOUTH_SUBNET=`./utils/decode_param_file.py ${parameter_file} vnet-south-subnet-prefix`
ILB_AZURE_GATEWAY=${SOUTH_SUBNET//0\/*/1}
PLB_AZURE_GATEWAY=${NORTH_SUBNET//0\/*/1}

# In general, the first IP is assigned .4 in a subnet
WEST_WEB_SERVER=${WEST_SUBNET//0\/*/4}

cat <<EOF
#cloud-config

write_files:
    - content: |
        configure
        set interfaces $ILB_INTERFACE unit 0 family inet dhcp
        set interfaces $PLB_INTERFACE unit 0 family inet dhcp
        set interfaces lo0 unit 0 family inet address $PLB_PUBLIC_IP/32
        
        set policy-options policy-statement toAzure term 1 from instance ilb
        set policy-options policy-statement toAzure term 1 from route-filter $WEST_SUBNET exact
        set policy-options policy-statement toAzure term 1 from route-filter $EAST_SUBNET exact
        set policy-options policy-statement toAzure term 1 then accept
        set policy-options policy-statement toAzure term 2 then reject
        set policy-options policy-statement toInternet term 1 from instance plb
        set policy-options policy-statement toInternet term 1 from route-filter 0.0.0.0/0 exact
        set policy-options policy-statement toInternet term 1 then accept
        set policy-options policy-statement toInternet term 2 then reject
        set routing-instances ilb instance-type virtual-router
        set routing-instances ilb routing-options static route $LB_PROBE_IP/32 next-hop $ILB_AZURE_GATEWAY
        set routing-instances ilb routing-options static route $WEST_SUBNET next-hop $ILB_AZURE_GATEWAY
        set routing-instances ilb routing-options static route $EAST_SUBNET next-hop $ILB_AZURE_GATEWAY
        set routing-instances ilb routing-options instance-import toInternet
        set routing-instances ilb interface $ILB_INTERFACE.0
        set routing-instances plb instance-type virtual-router
        set routing-instances plb routing-options static route $LB_PROBE_IP/32 next-hop $PLB_AZURE_GATEWAY
        set routing-instances plb routing-options static route 0.0.0.0/0 next-hop $PLB_AZURE_GATEWAY
        set routing-instances plb routing-options instance-import toAzure
        set routing-instances plb interface $PLB_INTERFACE.0
        set routing-instances plb interface lo0.0
        
        set security zones security-zone trust tcp-rst
        set security zones security-zone trust host-inbound-traffic system-services all
        set security zones security-zone trust interfaces $ILB_INTERFACE.0
        set security zones security-zone untrust screen untrust-screen
        set security zones security-zone untrust host-inbound-traffic system-services all
        set security zones security-zone untrust interfaces $PLB_INTERFACE.0
        set security zones security-zone untrust interfaces lo0.0
        set security policies default-policy permit-all
        
        set security address-book global address azure_plb_pip $PLB_PUBLIC_IP/32
        set security address-book global address azure_west $WEST_SUBNET
        set security address-book global address azure_east $EAST_SUBNET
        
        set security nat source rule-set source_rs1 from routing-instance plb
        set security nat source rule-set source_rs1 to routing-instance ilb
        set security nat source rule-set source_rs1 rule r1 match source-address 0.0.0.0/0
        set security nat source rule-set source_rs1 rule r1 then source-nat interface
        set security nat source rule-set source_rs2 from routing-instance ilb
        set security nat source rule-set source_rs2 to routing-instance plb
        set security nat source rule-set source_rs2 rule r2 match source-address-name azure_west
        set security nat source rule-set source_rs2 rule r2 match source-address-name azure_east
        set security nat source rule-set source_rs2 rule r2 then source-nat interface
        set security nat destination pool azure_west_web address $WEST_WEB_SERVER/32
        set security nat destination rule-set destination_rs1 from routing-instance plb
        set security nat destination rule-set destination_rs1 rule r1 match destination-address-name azure_plb_pip
        set security nat destination rule-set destination_rs1 rule r1 match destination-port 80
        set security nat destination rule-set destination_rs1 rule r1 match destination-port 443
        set security nat destination rule-set destination_rs1 rule r1 match protocol tcp
        set security nat destination rule-set destination_rs1 rule r1 then destination-nat pool azure_west_web
        commit
      path: /var/tmp/vsrx_scale_out_config

runcmd:
    - cli < /var/tmp/vsrx_scale_out_config

EOF

