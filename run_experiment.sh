#!/bin/bash

# Clean old Mininet settings
sudo mn -c

# Run Mininet with your topology and remote controller
sudo mn --custom ablene_topology.py --topo abilenetopo --controller=remote --link tc &

# Wait for the network to be ready
sleep 5

# Set up flow from h0 to h5 (Initial Path: s0-s1-s10-s7-s8-s5)
sudo ovs-ofctl add-flow s0 in_port=1,actions=output:2
sudo ovs-ofctl add-flow s1 in_port=1,actions=output:2
sudo ovs-ofctl add-flow s10 in_port=1,actions=output:2
sudo ovs-ofctl add-flow s7 in_port=1,actions=output:2
sudo ovs-ofctl add-flow s8 in_port=1,actions=output:2
sudo ovs-ofctl add-flow s5 in_port=2,actions=output:1

# Start capturing packets on h5
xterm -e "sudo tcpdump -i h5-eth0 -w result.pcap" &

# Start ping from h0 to h5
xterm -e "ping 10.0.0.6 -i 0.2 -c 300 > ping_results.txt" &

# Wait for 30 seconds
sleep 30

# Delete old flows and insert new path (New Path: s0-s2-s9-s8-s5)
sudo ovs-ofctl del-flows s0
sudo ovs-ofctl del-flows s1
sudo ovs-ofctl del-flows s10
sudo ovs-ofctl del-flows s7
sudo ovs-ofctl del-flows s8
sudo ovs-ofctl del-flows s5

sudo ovs-ofctl add-flow s0 in_port=1,actions=output:3
sudo ovs-ofctl add-flow s2 in_port=1,actions=output:2
sudo ovs-ofctl add-flow s9 in_port=1,actions=output:2
sudo ovs-ofctl add-flow s8 in_port=1,actions=output:2
sudo ovs-ofctl add-flow s5 in_port=2,actions=output:1

# Let it run until 60 seconds total
sleep 30

# Kill tcpdump
sudo pkill tcpdump

# Clean Mininet
sudo mn -c

echo "Experiment done. Check result.pcap and ping_results.txt."
