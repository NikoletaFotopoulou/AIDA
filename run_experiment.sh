#!/bin/bash

# Kill any previous Mininet instances
sudo mn -c

# Start Mininet in the background
sudo mn --custom AbileneTopo.py --topo abilenetopo --controller=remote --mac --switch ovsk --link tc --test none &
sleep 5  # Give Mininet time to start

echo "Installing initial flows..."

# Initial route: h0 -> h5 via s0-s1-s10-s7-s8-s5
sudo ovs-ofctl add-flow s0 in_port=1,actions=output:2
sudo ovs-ofctl add-flow s1 in_port=1,actions=output:2
sudo ovs-ofctl add-flow s10 in_port=1,actions=output:2
sudo ovs-ofctl add-flow s7 in_port=1,actions=output:2
sudo ovs-ofctl add-flow s8 in_port=1,actions=output:2
sudo ovs-ofctl add-flow s5 in_port=1,actions=output:2

# Start packet capture on h5
xterm -e "tcpdump -i h5-eth0 -w result.pcap" &

# Start ping from h0 to h5
xterm -e "ping -i 0.2 -c 300 10.0.0.6 > ping_results.txt" &

# Wait 30 seconds, then change the route
sleep 30
echo "Switching to new route..."

# Delete previous rules (just a sample; adjust ports if needed)
sudo ovs-ofctl del-flows s0
sudo ovs-ofctl del-flows s1
sudo ovs-ofctl del-flows s10
sudo ovs-ofctl del-flows s7
sudo ovs-ofctl del-flows s8
sudo ovs-ofctl del-flows s5

# New route: h0 -> h5 via s0-s2-s9-s8-s5
sudo ovs-ofctl add-flow s0 in_port=1,actions=output:3
sudo ovs-ofctl add-flow s2 in_port=1,actions=output:2
sudo ovs-ofctl add-flow s9 in_port=1,actions=output:2
sudo ovs-ofctl add-flow s8 in_port=1,actions=output:3
sudo ovs-ofctl add-flow s5 in_port=1,actions=output:2

# Wait for ping to finish
sleep 35

# Clean up
sudo pkill tcpdump
sudo mn -c
