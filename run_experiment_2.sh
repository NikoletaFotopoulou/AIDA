#!/bin/bash

# Set up initial flows (s3-s6-s7-s8)
sudo ovs-ofctl add-flow s3 in_port=1,actions=output:3
sudo ovs-ofctl add-flow s6 in_port=2,actions=output:4
sudo ovs-ofctl add-flow s7 in_port=2,actions=output:3
sudo ovs-ofctl add-flow s8 in_port=3,actions=output:1

sudo ovs-ofctl add-flow s8 in_port=1,actions=output:3
sudo ovs-ofctl add-flow s7 in_port=3,actions=output:2
sudo ovs-ofctl add-flow s6 in_port=4,actions=output:2
sudo ovs-ofctl add-flow s3 in_port=3,actions=output:1

# Wait 30 seconds
sleep 30

# Switch path (s3-s4-s5-s8)
sudo ovs-ofctl del-flows s0
sudo ovs-ofctl del-flows s1
sudo ovs-ofctl del-flows s10
sudo ovs-ofctl del-flows s7
sudo ovs-ofctl del-flows s8
sudo ovs-ofctl del-flows s5

sudo ovs-ofctl add-flow s3 in_port=1,actions=output:2
sudo ovs-ofctl add-flow s4 in_port=2,actions=output:3
sudo ovs-ofctl add-flow s5 in_port=2,actions=output:3
sudo ovs-ofctl add-flow s8 in_port=2,actions=output:1

sudo ovs-ofctl add-flow s8 in_port=1,actions=output:2
sudo ovs-ofctl add-flow s5 in_port=3,actions=output:2
sudo ovs-ofctl add-flow s4 in_port=3,actions=output:2
sudo ovs-ofctl add-flow s3 in_port=2,actions=output:1

# Wait until 60 seconds
sleep 30

echo "Experiment done"
