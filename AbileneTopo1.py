from mininet.net import Mininet
from mininet.node import OVSKernelSwitch, Host # No RemoteController
from mininet.cli import CLI
from mininet.log import setLogLevel, info
from mininet.link import TCLink
from mininet.topo import Topo # Import Topo

# Graph data (same as before)
NODE_DATA = [
    {"id": 0, "label": "NewYork"}, {"id": 1, "label": "Chicago"},
    {"id": 2, "label": "WashingtonDC"}, {"id": 3, "label": "Seattle"},
    {"id": 4, "label": "Sunnyvale"}, {"id": 5, "label": "LosAngeles"},
    {"id": 6, "label": "Denver"}, {"id": 7, "label": "KansasCity"},
    {"id": 8, "label": "Houston"}, {"id": 9, "label": "Atlanta"},
    {"id": 10, "label": "Indianapolis"}
]

EDGE_DATA = [
    {"source": 0, "target": 1}, {"source": 0, "target": 2},
    {"source": 1, "target": 10}, {"source": 2, "target": 9},
    {"source": 3, "target": 4}, {"source": 3, "target": 6},
    {"source": 4, "target": 5}, {"source": 4, "target": 6},
    {"source": 5, "target": 8}, {"source": 6, "target": 7},
    {"source": 7, "target": 8}, {"source": 7, "target": 10},
    {"source": 8, "target": 9}, {"source": 9, "target": 10}
]

OC192_BW = 10000
HOST_LINK_BW = 1000

class AbileneTopoManual(Topo):
    "Abilene Network Topology for manual flow insertion"

    def build(self, **_opts):
        switches = {}
        hosts = {}

        # 1. Add Switches
        for node_info in NODE_DATA:
            gml_id = node_info['id']
            label = node_info['label'].replace(" ", "")
            switch_name = f's{gml_id}'
            switches[gml_id] = self.addSwitch(switch_name, protocols='OpenFlow13') # Specify OF version
            info(f"*** Adding switch: {switch_name} (for GML node {label})\n")

            # Add one Host per Switch
            host_name = f'h{gml_id}'
            host_ip = f'10.0.{gml_id}.1/24' # Consistent IP addressing
            hosts[gml_id] = self.addHost(host_name, ip=host_ip, mac=f'00:00:00:00:00:{gml_id:02x}')
            info(f"*** Adding host: {host_name} with IP {host_ip}\n")
            self.addLink(hosts[gml_id], switches[gml_id], bw=HOST_LINK_BW)

        # 2. Add inter-switch Links
        for edge_info in EDGE_DATA:
            s1_gml_id = edge_info['source']
            s2_gml_id = edge_info['target']
            s1 = switches[s1_gml_id]
            s2 = switches[s2_gml_id]
            self.addLink(s1, s2, bw=OC192_BW)

def run_abilene_manual():
    topo = AbileneTopoManual()
    net = Mininet(
        topo=topo,
        switch=OVSKernelSwitch,
        controller=None,  # !!! CRITICAL: No external or default controller !!!
        link=TCLink,
        autoSetMacs=False, # We set MACs in the topo now
        autoStaticArp=False # We will handle ARP with flows
    )

    info('*** Starting network\n')
    net.start()

    # --- Helper to find port numbers ---
    # This is for your information; you'll use these in the CLI commands.
    info('*** Network Interface Information:\n')
    for switch in net.switches:
        info(f"Interfaces for {switch.name}:\n")
        for intf in switch.intfList():
            if intf.link: # Only show interfaces that are part of a link
                 # node1 can be a host or switch, node2 can be a host or switch
                node1 = intf.link.intf1.node
                node2 = intf.link.intf2.node
                # Determine which node is the "other end" of the link from this switch's perspective
                other_node = node2 if intf.node == node1 else node1
                info(f"  {intf.name} (Port {switch.ports[intf]}) connected to {other_node.name}\n")
            else:
                info(f"  {intf.name} (Port {switch.ports[intf]}) (loopback or unlinked)\n")
        info("\n")

    info('*** Target hosts for this exercise:\n')
    h0 = net.get('h0')
    h10 = net.get('h10')
    info(f"Sender: h0 (IP: {h0.IP()}, MAC: {h0.MAC()})\n")
    info(f"Receiver: h10 (IP: {h10.IP()}, MAC: {h10.MAC()})\n")

    info('*** Path 1 (s0 -> s1 -> s10)\n')
    info('*** Path 2 (s0 -> s2 -> s9 -> s10)\n')

    info('*** Running CLI. Follow the instructions for flow insertion and traffic.\n')
    CLI(net)

    info('*** Stopping network\n')
    net.stop()

if __name__ == '__main__':
    setLogLevel('info')
    run_abilene_manual()
