#!/bin/bash

set -e

# 1. Start Mininet with remote controller
echo "[*] Starting Mininet..."
sudo mn --custom AbileneTopo.py --topo abilenetopo --controller=remote --mac --link=tc --switch ovsk &

sleep 5

echo "[*] Setting initial flow rules..."

# Delete old flows
for i in {0..10}; do
  sudo ovs-ofctl del-flows s$i
done

# ----------- INITIAL ROUTE (0-30s) ------------
# Route: h0 → s0 → s1 → s10 → s9 → h9

# Assume:
#   h0 is on port 1 of s0
#   s0 to s1 is port 2
#   s1 to s10 is port 2
#   s10 to s9 is port 2
#   s9 to h9 is port 2

# s0
sudo ovs-ofctl add-flow s0 "in_port=1,actions=output:2"
sudo ovs-ofctl add-flow s0 "in_port=2,actions=output:1"

# s1
sudo ovs-ofctl add-flow s1 "in_port=1,actions=output:2"
sudo ovs-ofctl add-flow s1 "in_port=2,actions=output:1"

# s10
sudo ovs-ofctl add-flow s10 "in_port=1,actions=output:2"
sudo ovs-ofctl add-flow s10 "in_port=2,actions=output:1"

# s9
sudo ovs-ofctl add-flow s9 "in_port=1,actions=output:2"
sudo ovs-ofctl add-flow s9 "in_port=2,actions=output:1"

echo "[*] Starting ping..."
xterm -e "sudo mnexec -a \$(pgrep -f 'bash.*h0') ping 10.0.0.10 -i 0.2 -D > ping_log.txt" &

# Wait for 30 seconds
sleep 30

echo "[*] Switching flow to NEW path..."

# ----------- NEW ROUTE (30-60s) ------------
# Route: h0 → s0 → s2 → s9 → h9

# Clear previous flows
for i in {0..10}; do
  sudo ovs-ofctl del-flows s$i
done

# s0: h0 to s2 (assume port 1 is h0, port 3 is s2)
sudo ovs-ofctl add-flow s0 "in_port=1,actions=output:3"
sudo ovs-ofctl add-flow s0 "in_port=3,actions=output:1"

# s2: s0 to s9
sudo ovs-ofctl add-flow s2 "in_port=1,actions=output:2"
sudo ovs-ofctl add-flow s2 "in_port=2,actions=output:1"

# s9: s2 to h9
sudo ovs-ofctl add-flow s9 "in_port=1,actions=output:2"
sudo ovs-ofctl add-flow s9 "in_port=2,actions=output:1"

# Wait for the experiment to finish
sleep 30

echo "[*] Done. Stopping experiment."
pkill xterm
sudo mn -c
