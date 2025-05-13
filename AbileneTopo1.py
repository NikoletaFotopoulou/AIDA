from mininet.topo import Topo

class AbileneTopo(Topo):
    "Simplified Abilene Network Topology for manual OpenFlow control."

    def build(self, **_opts): # Or __init__(self, **_opts) if your class examples strictly use that
        "Build Abilene topology."

        # If using __init__, you'd call: Topo.__init__(self, **_opts)

        # Node ID mapping (from your GML) for reference:
        # 0: New York
        # 1: Chicago
        # 2: Washington DC
        # 3: Seattle
        # 4: Sunnyvale
        # 5: Los Angeles
        # 6: Denver
        # 7: Kansas City
        # 8: Houston
        # 9: Atlanta
        # 10: Indianapolis

        # 1. Add Switches
        # We'll use s0, s1, ... for switch names, corresponding to GML IDs.
        s0 = self.addSwitch('s0', protocols='OpenFlow13')  # New York
        s1 = self.addSwitch('s1', protocols='OpenFlow13')  # Chicago
        s2 = self.addSwitch('s2', protocols='OpenFlow13')  # Washington DC
        s3 = self.addSwitch('s3', protocols='OpenFlow13')  # Seattle
        s4 = self.addSwitch('s4', protocols='OpenFlow13')  # Sunnyvale
        s5 = self.addSwitch('s5', protocols='OpenFlow13')  # Los Angeles
        s6 = self.addSwitch('s6', protocols='OpenFlow13')  # Denver
        s7 = self.addSwitch('s7', protocols='OpenFlow13')  # Kansas City
        s8 = self.addSwitch('s8', protocols='OpenFlow13')  # Houston
        s9 = self.addSwitch('s9', protocols='OpenFlow13')  # Atlanta
        s10 = self.addSwitch('s10', protocols='OpenFlow13') # Indianapolis

        # Store switches in a list for easier linking by GML ID
        switches = [s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10]

        # 2. Add Hosts
        # Adding one host per switch, named h0, h1, ...
        # Assigning predictable IPs and MACs is helpful for manual flow rules.
        h0 = self.addHost('h0', ip='10.0.0.1/24', mac='00:00:00:00:00:00')
        h1 = self.addHost('h1', ip='10.0.1.1/24', mac='00:00:00:00:00:01')
        h2 = self.addHost('h2', ip='10.0.2.1/24', mac='00:00:00:00:00:02')
        h3 = self.addHost('h3', ip='10.0.3.1/24', mac='00:00:00:00:00:03')
        h4 = self.addHost('h4', ip='10.0.4.1/24', mac='00:00:00:00:00:04')
        h5 = self.addHost('h5', ip='10.0.5.1/24', mac='00:00:00:00:00:05')
        h6 = self.addHost('h6', ip='10.0.6.1/24', mac='00:00:00:00:00:06')
        h7 = self.addHost('h7', ip='10.0.7.1/24', mac='00:00:00:00:00:07')
        h8 = self.addHost('h8', ip='10.0.8.1/24', mac='00:00:00:00:00:08')
        h9 = self.addHost('h9', ip='10.0.9.1/24', mac='00:00:00:00:00:09')
        h10 = self.addHost('h10', ip='10.0.10.1/24', mac='00:00:00:00:00:0A')

        # Store hosts in a list for easier linking
        hosts = [h0, h1, h2, h3, h4, h5, h6, h7, h8, h9, h10]

        # 3. Add Links: Host to Switch
        for i in range(len(hosts)):
            self.addLink(hosts[i], switches[i]) # e.g., h0 to s0, h1 to s1

        # 4. Add Links: Switch to Switch (Inter-switch links from GML)
        self.addLink(s0, s1)   # NY - Chicago
        self.addLink(s0, s2)   # NY - DC
        self.addLink(s1, s10)  # Chicago - Indianapolis
        self.addLink(s2, s9)   # DC - Atlanta
        self.addLink(s3, s4)   # Seattle - Sunnyvale
        self.addLink(s3, s6)   # Seattle - Denver
        self.addLink(s4, s5)   # Sunnyvale - LA
        self.addLink(s4, s6)   # Sunnyvale - Denver
        self.addLink(s5, s8)   # LA - Houston
        self.addLink(s6, s7)   # Denver - Kansas City
        self.addLink(s7, s8)   # Kansas City - Houston
        self.addLink(s7, s10)  # Kansas City - Indianapolis
        self.addLink(s8, s9)   # Houston - Atlanta
        self.addLink(s9, s10)  # Atlanta - Indianapolis

# This dictionary is necessary for Mininet to find your topology
topos = {'abilenetopo': (lambda: AbileneTopo())}
