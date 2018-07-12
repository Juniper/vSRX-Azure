import itertools
import mimetools
import mimetypes
from cStringIO import StringIO
import urllib
import urllib2
import os
import json
import paramiko
import logging
import time
import ipaddress

log = logging.getLogger()
log.setLevel(logging.INFO)
log_file_path = "/var/log/vpn.log"
logging.basicConfig(level = logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s', filename = log_file_path, filemode = 'w')


class SshConnector(object):
    """Handles vSRX SSH sessions."""

    def __init__(self):
        self.c = paramiko.SSHClient()
        self.ssh = None
        return
    
    def connect_vsrx(self, vsrx_ip, vsrx_username, vsrx_password):
        self.c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        self.c.connect(hostname = vsrx_ip, username = vsrx_username, password = vsrx_password)
        self.ssh = self.c.invoke_shell()
        time.sleep(5)
        return

    def get_ssh_client(self):
        return self.ssh

    def prompt(self):
        buff = ''
        while not (buff.endswith('% ') or buff.endswith('> ') or buff.endswith('# ')):
            resp = self.ssh.recv(9999)
            buff += resp
            #log.info("response: %s",resp)
        return buff

    def end_vsrx_session(self):
        self.ssh.close()
        return


class VsrxConfigurator(object):
    """Handles vSRX SSH configurations."""

    def __init__(self, ssh_connector):
        self.ssh_connector = ssh_connector
        return
    
    def configure_vsrx_interfaces(self, untrust_ip, untrust_subnet, trust_ip, trust_subnet, local_address_space):
        subnet = (ipaddress.ip_network(unicode(untrust_subnet)))
        next_hop = subnet.network_address + 1
        config_text = []
        config_text.append('set interfaces ge-0/0/0 unit 0 family inet address {}/{}'.format(untrust_ip, untrust_subnet.split('/')[1]))
        config_text.append('set interfaces ge-0/0/1 unit 0 family inet address {}/{}'.format(trust_ip, trust_subnet.split('/')[1]))
        config_text.append('set interfaces st0 unit 0 family inet address 169.254.1.1/30')
        config_text.append('set routing-instances ge-routing instance-type virtual-router')
        config_text.append('set routing-instances ge-routing interface ge-0/0/0.0')
        config_text.append('set routing-instances ge-routing interface ge-0/0/1.0')
        config_text.append('set routing-instances ge-routing interface st0.0')
        config_text.append('set routing-instances ge-routing routing-options static route 0.0.0.0/0 next-hop {}'.format(next_hop))
        config_text.append('set routing-instances ge-routing routing-options static route {} next-hop st0.0'.format(local_address_space))
        self._pushConfig(config_text)
        return

    def configure_security_zones_policies(self):
        config_text = []
        config_text.append('set security policies from-zone trust to-zone trust policy default-permit match source-address any')
        config_text.append('set security policies from-zone trust to-zone trust policy default-permit match destination-address any')
        config_text.append('set security policies from-zone trust to-zone trust policy default-permit match application any')
        config_text.append('set security policies from-zone trust to-zone trust policy default-permit then permit')
        config_text.append('set security policies from-zone trust to-zone untrust policy default-permit match source-address any')
        config_text.append('set security policies from-zone trust to-zone untrust policy default-permit match destination-address any')
        config_text.append('set security policies from-zone trust to-zone untrust policy default-permit match application any')
        config_text.append('set security policies from-zone trust to-zone untrust policy default-permit then permit')
        config_text.append('set security policies from-zone untrust to-zone trust policy default-permit match source-address any')
        config_text.append('set security policies from-zone untrust to-zone trust policy default-permit match destination-address any')
        config_text.append('set security policies from-zone untrust to-zone trust policy default-permit match application any')
        config_text.append('set security policies from-zone untrust to-zone trust policy default-permit then permit')
        config_text.append('set security zones security-zone trust host-inbound-traffic system-services https')
        config_text.append('set security zones security-zone trust host-inbound-traffic system-services ssh')
        config_text.append('set security zones security-zone untrust host-inbound-traffic system-services ike')
        config_text.append('set security zones security-zone trust host-inbound-traffic system-services ping')
        config_text.append('set security zones security-zone untrust interfaces ge-0/0/0.0')
        config_text.append('set security zones security-zone untrust interfaces st0.0')
        config_text.append('set security zones security-zone trust interfaces ge-0/0/1.0')
        self._pushConfig(config_text)
        return


    def create_vpn_tunnel_to_vng(self, vng_ip, psk):
        config_text = []
        config_text.append('set security ike proposal IKE_Azure_Proposal authentication-method pre-shared-keys')
        config_text.append('set security ike proposal IKE_Azure_Proposal dh-group group2')
        config_text.append('set security ike proposal IKE_Azure_Proposal authentication-algorithm sha1')
        config_text.append('set security ike proposal IKE_Azure_Proposal encryption-algorithm aes-256-cbc')
        config_text.append('set security ike proposal IKE_Azure_Proposal lifetime-seconds 10800')
        config_text.append('set security ike policy IKE_Azure_Policy proposals IKE_Azure_Proposal')
        config_text.append('set security ike policy IKE_Azure_Policy pre-shared-key ascii-text {}'.format(psk))
        config_text.append('set security ike gateway IKE_Azure_Gateway ike-policy IKE_Azure_Policy')
        config_text.append('set security ike gateway IKE_Azure_Gateway address {}'.format(vng_ip))
        config_text.append('set security ike gateway IKE_Azure_Gateway external-interface ge-0/0/0.0')
        config_text.append('set security ike gateway IKE_Azure_Gateway version v2-only')
        config_text.append('set security ipsec proposal IPsec_Azure_Proposal protocol esp')
        config_text.append('set security ipsec proposal IPsec_Azure_Proposal authentication-algorithm hmac-sha1-96')
        config_text.append('set security ipsec proposal IPsec_Azure_Proposal encryption-algorithm aes-256-cbc')
        config_text.append('set security ipsec proposal IPsec_Azure_Proposal lifetime-seconds 3600')
        config_text.append('set security ipsec policy IPsec_Azure_Policy proposals IPsec_Azure_Proposal')
        config_text.append('set security ipsec vpn IPsec_Azure_VPN bind-interface st0.0')
        config_text.append('set security ipsec vpn IPsec_Azure_VPN ike gateway IKE_Azure_Gateway')
        config_text.append('set security ipsec vpn IPsec_Azure_VPN ike ipsec-policy IPsec_Azure_Policy')
        config_text.append('set security ipsec vpn IPsec_Azure_VPN establish-tunnels immediately')
        self._pushConfig(config_text)
        return

    def _pushConfig(self, config):
        self.ssh_connector.ssh.send('edit\n')
        log.info("%s", self.ssh_connector.prompt())
        stime = time.time()
        for line in config:
            if line == "WAIT":
                log.debug("Waiting 30 seconds...")
                time.sleep(30)
            else:
                self.ssh_connector.ssh.send(line+'\n')
                log.info("%s", self.ssh_connector.prompt())
    
        log.info("Committing---")
        self.ssh_connector.ssh.send('commit\n')
        time.sleep(30)
        self.ssh_connector.ssh.send('exit\n')
        log.debug("   --- %s seconds ---", (time.time() - stime))
        self.ssh_connector.ssh.send('exit\n')
        log.info("Update complete!")
        return



class AzureClient(object):
    """Creates an Azure REST Client."""

    def __init__(self, subId, rgname):
        self.subId = subId
        self.rgname = rgname
        self.bearer_token = None
        return
    
    '''def acquire_bearer_token(self):
        msiEndpoint = 'http://localhost:50342/oauth2/token?resource=https%3A%2F%2Fmanagement.azure.com%2F'
        request = urllib2.Request(msiEndpoint)
        request.add_header('Metadata', 'true')
        request.get_method = lambda: 'GET'
        refused = True
        while(refused):
            try:
                authResponse = json.loads(urllib2.urlopen(request).read())
                refused = False
            except:
                print "Connection refused!!"
                time.sleep(10)

        self.bearer_token = authResponse['access_token']'''

    def acquire_bearer_token(self):
        msiEndpoint = 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/'
        request = urllib2.Request(msiEndpoint)
        request.add_header('Metadata', 'true')
        request.get_method = lambda: 'GET'
        refused = True
        while(refused):
            try:
                authResponse = json.loads(urllib2.urlopen(request).read())
                refused = False
            except:
                print "Connection refused!!"
                time.sleep(10)

        self.bearer_token = authResponse['access_token']

    def get_vng_public_ip(self, vng_name):
        url = 'https://management.azure.com/subscriptions/{}/resourceGroups/{}/providers/Microsoft.Network/virtualNetworkGateways/{}?api-version=2018-02-01'.format(self.subId, self.rgname, vng_name)
        request = urllib2.Request(url)
        token = "Bearer " + self.bearer_token
        request.add_header('Authorization', token)
        request.get_method = lambda: 'GET'
        apiResponse = json.loads(urllib2.urlopen(request).read())
        public_ip_name = apiResponse['properties']['ipConfigurations'][0]['properties']['publicIPAddress']['id'].split('/')[-1]
        return self._get_public_ip_address(public_ip_name)

    def _get_public_ip_address(self, public_ip_name):
        url = 'https://management.azure.com/subscriptions/{}/resourceGroups/{}/providers/Microsoft.Network/publicIPAddresses/{}?api-version=2018-02-01'.format(self.subId, self.rgname, public_ip_name)
        request = urllib2.Request(url)
        token = "Bearer " + self.bearer_token
        request.add_header('Authorization', token)
        request.get_method = lambda: 'GET'
        apiResponse = json.loads(urllib2.urlopen(request).read())
        return apiResponse['properties']['ipAddress']



if __name__ == '__main__':

    # Retrieve all the params passed by the ARM template to the staging VM
    params = {}
    with open('/opt/data.txt','r') as f:
        words = f.read().split()
        for word in words:
            (key, val) = word.split(':')
            params[key] = val.rstrip()
    
    with open('/opt/data2.txt','w') as f:
        for value in params.values():
            f.write(value + '!!   ')

    # Add a static route to the remote network
    subnet = (ipaddress.ip_network(unicode(params['address_space'])))
    dgw = subnet.network_address + 1
    os.system('route add -net {} gw {} dev eth1'.format(params['remote_address_space'], dgw))

    # Get the public IP address of the Azure VNG
    azure_client = AzureClient(params['subid'], params['rgname'])
    azure_client.acquire_bearer_token()
    forbidden = True
    while(forbidden):
        try:
            vng_public_ip = azure_client.get_vng_public_ip(params['vngname'])
            forbidden = False
        except Exception as e:
            print (e)
            time.sleep(10)
    print('\nThe VNG public IP address is: {}\n'.format(vng_public_ip))
    log.info('The VNG public IP address is: {}'.format(vng_public_ip))


    # Create an SSH object and connect to the vSRX
    print("Configuring the vSRX instance...")
    print("\n")
    try:
        vsrxSshConnector = SshConnector()
        vsrxSshConnector.connect_vsrx(params['vsrx-ip'], params['vsrx-username'], params['vsrx-password'])
    except:
        log.error("Failed to apply the configuration to the vSRX {}").format(params['vsrx-ip'])
        vsrxSshConnector.end_vsrx_session()

    
    vsrxConfigurator = VsrxConfigurator(vsrxSshConnector)

    # Configure vSRX interfaces and routing instance
    vsrxConfigurator.configure_vsrx_interfaces(params['untrust_IP'], params['untrust_subnet'], params['trust_IP'], params['trust_subnet'], params['remote_address_space'])
    vsrxSshConnector.end_vsrx_session()
    print("###############################################")
    print("Completed configuration of the vSRX interfaces!")
    log.info("Completed configuration of the vSRX interfaces!")
    time.sleep(5)

    # Configure vSRX security zones and policies
    try:
        vsrxSshConnector.connect_vsrx(params['vsrx-ip'], params['vsrx-username'], params['vsrx-password'])
    except:
        log.error("Failed to apply the configuration to the vSRX {}").format(params['vsrx-ip'])
        vsrxSshConnector.end_vsrx_session()
    vsrxConfigurator.configure_security_zones_policies()
    vsrxSshConnector.end_vsrx_session()
    print("################################################")
    print("Completed security zones/policies configuration!")
    log.info("Completed security zones/policies configuration!")
    time.sleep(5)

    # Create IPSec tunnel between vSRX and Azure VNG
    try:
        vsrxSshConnector.connect_vsrx(params['vsrx-ip'], params['vsrx-username'], params['vsrx-password'])
    except:
        log.error("Failed to apply the configuration to the vSRX {}").format(params['vsrx-ip'])
        vsrxSshConnector.end_vsrx_session()
    vsrxConfigurator.create_vpn_tunnel_to_vng(vng_public_ip, params['shared_key'])
    vsrxSshConnector.end_vsrx_session()
    print("#################################################################################")
    print("\n")
    print("Successfully created VPN tunnel between vSRX and Azure Virtual Network Gateway!!!")
    print("\n")
    log.info("Successfully created VPN tunnel between vSRX and Azure Virtual Network Gateway!!!")

