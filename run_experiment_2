#!/bin/bash

# Wait for network to be ready (optional if manual start was recent)
sleep 5

# Set up initial flows (s0-s1-s10-s7-s8-s5)
sudo ovs-ofctl add-flow s0 in_port=1,actions=output:2
sudo ovs-ofctl add-flow s1 in_port=2,actions=output:3
sudo ovs-ofctl add-flow s10 in_port=2,actions=output:3
sudo ovs-ofctl add-flow s7 in_port=4,actions=output:3
sudo ovs-ofctl add-flow s8 in_port=3,actions=output:2
sudo ovs-ofctl add-flow s5 in_port=3,actions=output:1

sudo ovs-ofctl add-flow s5 in_port=1,actions=output:3
sudo ovs-ofctl add-flow s8 in_port=2,actions=output:3
sudo ovs-ofctl add-flow s7 in_port=3,actions=output:4
sudo ovs-ofctl add-flow s10 in_port=3,actions=output:2
sudo ovs-ofctl add-flow s1 in_port=3,actions=output:2
sudo ovs-ofctl add-flow s0 in_port=2,actions=output:1

# Wait 30 seconds
sleep 30

# Switch path (s0-s2-s9-s8-s5)
sudo ovs-ofctl del-flows s0
sudo ovs-ofctl del-flows s1
sudo ovs-ofctl del-flows s10
sudo ovs-ofctl del-flows s7
sudo ovs-ofctl del-flows s8
sudo ovs-ofctl del-flows s5

sudo ovs-ofctl add-flow s0 in_port=1,actions=output:3
sudo ovs-ofctl add-flow s2 in_port=2,actions=output:3
sudo ovs-ofctl add-flow s9 in_port=2,actions=output:3
sudo ovs-ofctl add-flow s8 in_port=4,actions=output:2
sudo ovs-ofctl add-flow s5 in_port=3,actions=output:1

sudo ovs-ofctl add-flow s5 in_port=1,actions=output:3
sudo ovs-ofctl add-flow s8 in_port=2,actions=output:4
sudo ovs-ofctl add-flow s9 in_port=3,actions=output:2
sudo ovs-ofctl add-flow s2 in_port=3,actions=output:2
sudo ovs-ofctl add-flow s0 in_port=3,actions=output:1

# Wait until 60 seconds
sleep 30

echo "Experiment done"
