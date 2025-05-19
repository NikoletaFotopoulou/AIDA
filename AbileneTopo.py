from mininet.topo import Topo

class AbileneTopo(Topo):
    
    def build(self, **_opts): 
        
        s0 = self.addSwitch('s0')  # New York
        s1 = self.addSwitch('s1')  # Chicago
        s2 = self.addSwitch('s2')  # Washington DC
        s3 = self.addSwitch('s3')  # Seattle
        s4 = self.addSwitch('s4')  # Sunnyvale
        s5 = self.addSwitch('s5')  # Los Angeles
        s6 = self.addSwitch('s6')  # Denver
        s7 = self.addSwitch('s7')  # Kansas City
        s8 = self.addSwitch('s8')  # Houston
        s9 = self.addSwitch('s9')  # Atlanta
        s10 = self.addSwitch('s10') # Indianapolis

        switches = [s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10]
        
        h0 = self.addHost('h0')
        h1 = self.addHost('h1')
        h2 = self.addHost('h2')
        h3 = self.addHost('h3')
        h4 = self.addHost('h4')
        h5 = self.addHost('h5')
        h6 = self.addHost('h6')
        h7 = self.addHost('h7')
        h8 = self.addHost('h8')
        h9 = self.addHost('h9')
        h10 = self.addHost('h10')
        
        hosts = [h0, h1, h2, h3, h4, h5, h6, h7, h8, h9, h10]

        #Host to Switch
        for i in range(len(hosts)):
            self.addLink(hosts[i], switches[i], delay='1ms')

        #Switch to Switch
        self.addLink(s0, s1, delay='2ms')   # NY - Chicago
        self.addLink(s0, s2, delay='2ms')   # NY - DC
        self.addLink(s1, s10, delay='2ms')  # Chicago - Indianapolis
        self.addLink(s2, s9, delay='2ms')   # DC - Atlanta
        self.addLink(s3, s4, delay='2ms')   # Seattle - Sunnyvale
        self.addLink(s3, s6, delay='2ms')   # Seattle - Denver
        self.addLink(s4, s5, delay='2ms')   # Sunnyvale - LA
        self.addLink(s4, s6, delay='2ms')   # Sunnyvale - Denver
        self.addLink(s5, s8, delay='2ms')   # LA - Houston
        self.addLink(s6, s7, delay='2ms')   # Denver - Kansas City
        self.addLink(s7, s8, delay='2ms')   # Kansas City - Houston
        self.addLink(s7, s10, delay='2ms')  # Kansas City - Indianapolis
        self.addLink(s8, s9, delay='2ms')   # Houston - Atlanta
        self.addLink(s9, s10, delay='2ms')  # Atlanta - Indianapolis

topos = {'abilenetopo': (lambda: AbileneTopo())}
