from mininet.topo import Topo
from mininet.link import TCLink # Import TCLink

class AbileneTopo(Topo):
    "Simplified Abilene Network Topology for manual OpenFlow control."

    def build(self, **_opts):
        # Node ID mapping (from your GML) for reference:
        # 0: New York (s0, h0)
        # 1: Chicago (s1, h1)
        # ... (rest of your mapping)

        s0 = self.addSwitch('s0')
        s1 = self.addSwitch('s1')
        s2 = self.addSwitch('s2')
        s3 = self.addSwitch('s3')
        s4 = self.addSwitch('s4')
        s5 = self.addSwitch('s5')
        s6 = self.addSwitch('s6')
        s7 = self.addSwitch('s7')
        s8 = self.addSwitch('s8')
        s9 = self.addSwitch('s9')
        s10 = self.addSwitch('s10')

        switches = [s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10]

        h0 = self.addHost('h0', ip='10.0.0.1/24', mac='00:00:00:00:00:01')
        h1 = self.addHost('h1', ip='10.0.0.2/24', mac='00:00:00:00:00:02')
        h2 = self.addHost('h2', ip='10.0.0.3/24', mac='00:00:00:00:00:03')
        h3 = self.addHost('h3', ip='10.0.0.4/24', mac='00:00:00:00:00:04')
        h4 = self.addHost('h4', ip='10.0.0.5/24', mac='00:00:00:00:00:05')
        h5 = self.addHost('h5', ip='10.0.0.6/24', mac='00:00:00:00:00:06')
        h6 = self.addHost('h6', ip='10.0.0.7/24', mac='00:00:00:00:00:07')
        h7 = self.addHost('h7', ip='10.0.0.8/24', mac='00:00:00:00:00:08')
        h8 = self.addHost('h8', ip='10.0.0.9/24', mac='00:00:00:00:00:09')
        h9 = self.addHost('h9', ip='10.0.0.10/24', mac='00:00:00:00:00:0A')
        h10 = self.addHost('h10', ip='10.0.0.11/24', mac='00:00:00:00:00:0B')

        hosts = [h0, h1, h2, h3, h4, h5, h6, h7, h8, h9, h10]

        # Define link parameters (example: 10 Mbps bandwidth for inter-switch links)
        # Host links can be faster, e.g., 100 Mbps
        host_link_opts = dict(delay='1ms', bw=100)
        switch_link_opts = dict(delay='2ms', bw=10) # Set BW to 10 Mbps for inter-switch links

        # Add Links: Host to Switch
        for i in range(len(hosts)):
            self.addLink(hosts[i], switches[i], **host_link_opts)

        # Add Links: Switch to Switch
        self.addLink(s0, s1, **switch_link_opts)   # NY - Chicago
        self.addLink(s0, s2, **switch_link_opts)   # NY - DC
        self.addLink(s1, s10, **switch_link_opts)  # Chicago - Indianapolis
        self.addLink(s2, s9, **switch_link_opts)   # DC - Atlanta
        self.addLink(s3, s4, **switch_link_opts)   # Seattle - Sunnyvale
        self.addLink(s3, s6, **switch_link_opts)   # Seattle - Denver
        self.addLink(s4, s5, **switch_link_opts)   # Sunnyvale - LA
        self.addLink(s4, s6, **switch_link_opts)   # Sunnyvale - Denver
        self.addLink(s5, s8, **switch_link_opts)   # LA - Houston
        self.addLink(s6, s7, **switch_link_opts)   # Denver - Kansas City
        self.addLink(s7, s8, **switch_link_opts)   # Kansas City - Houston
        self.addLink(s7, s10, **switch_link_opts)  # Kansas City - Indianapolis
        self.addLink(s8, s9, **switch_link_opts)   # Houston - Atlanta
        self.addLink(s9, s10, **switch_link_opts)  # Atlanta - Indianapolis

topos = {'abilenetopo': (lambda: AbileneTopo())}
