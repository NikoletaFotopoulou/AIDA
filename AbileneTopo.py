from mininet.topo import Topo
from mininet.link import TCLink # Import TCLink for delay and bw

class AbileneTopo(Topo):
    def __init__(self):
        # Initialize topology
        Topo.__init__(self)

        # Add nodes as hosts (routers)
        # Assigning short names for easier reference in paths
        nodes = {
            'ny': 'NewYork', 'ch': 'Chicago', 'dc': 'WashingtonDC',
            'sea': 'Seattle', 'sun': 'Sunnyvale', 'la': 'LosAngeles',
            'den': 'Denver', 'kc': 'KansasCity', 'hou': 'Houston',
            'atl': 'Atlanta', 'ind': 'Indianapolis'
        }
        
        self.node_objs = {}
        for short_name, long_name in nodes.items():
            # Treat these as switches since they route, but Mininet hosts can run programs
            # For OpenFlow, they need to be switches. If they are hosts, they connect TO switches.
            # Let's make them switches, and attach a single host to each "router switch" if we need end-to-end apps.
            # For simplicity in this router-level topology, we'll use addSwitch and then run commands ON these "switches"
            # as if they were hosts. This is a common Mininet pattern for router topologies.
            # OR, stick to addHost and ensure they are controlled by OpenFlow.
            # Sticking to addHost as per original for now, will use ovs-ofctl on them.
            self.node_objs[short_name] = self.addHost(short_name)

        ny, ch, dc, sea, sun, la, den, kc, hou, atl, ind = (
            self.node_objs['ny'], self.node_objs['ch'], self.node_objs['dc'],
            self.node_objs['sea'], self.node_objs['sun'], self.node_objs['la'],
            self.node_objs['den'], self.node_objs['kc'], self.node_objs['hou'],
            self.node_objs['atl'], self.node_objs['ind']
        )

        # Add links: bw in Mbps, delay in ms
        # Using random delays between 1ms and 2ms for variety
        # Mininet TCLink delay format is like '1ms', '2ms'
        # Note: bw=10 means 10 Mbps for TCLink by default. If you meant 10Gbps, use bw=10000
        # The original had bw=10, implying 10Gbps for OC-192. For Mininet TCLink, explicit unit is good.
        # Let's assume bw=10000 (10Gbps) for OC-192.
        gbps = 10000 
        self.addLink(ny, ch, bw=gbps, delay='1.2ms')
        self.addLink(ny, dc, bw=gbps, delay='1.5ms')
        self.addLink(ch, ind, bw=gbps, delay='1.0ms')
        self.addLink(dc, atl, bw=gbps, delay='1.8ms')
        self.addLink(sea, sun, bw=gbps, delay='1.1ms')
        self.addLink(sea, den, bw=gbps, delay='2.0ms')
        self.addLink(sun, la, bw=gbps, delay='1.3ms')
        self.addLink(sun, den, bw=gbps, delay='1.6ms')
        self.addLink(la, hou, bw=gbps, delay='1.9ms')
        self.addLink(den, kc, bw=gbps, delay='1.4ms')
        self.addLink(kc, hou, bw=gbps, delay='1.7ms')
        self.addLink(kc, ind, bw=gbps, delay='1.2ms')
        self.addLink(hou, atl, bw=gbps, delay='1.5ms')
        self.addLink(atl, ind, bw=gbps, delay='1.0ms')

topos = { 'abilenetopo': ( lambda: AbileneTopo() ) }
