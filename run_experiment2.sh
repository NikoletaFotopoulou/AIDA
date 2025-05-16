#!/bin/bash

echo "Starting experiment script..."

# IPs (based on your topology file, h0=10.0.0.1, h1=10.0.0.2, etc.)
H0_IP="10.0.0.1"
H5_IP="10.0.0.6"
H6_IP="10.0.0.7" # Congestion source
H7_IP="10.0.0.8" # Congestion destination

# Experiment duration
TOTAL_DURATION=60
SWITCH_TIME=30
MEASUREMENT_DURATION=$(($TOTAL_DURATION - 5)) # Start measurements after initial sleep, run for ~55s

# Output files
PING_LOG="h0_ping_h5.log"
IPERF_SERVER_LOG="h7_iperf_server.log"
IPERF_CLIENT_LOG="h6_iperf_client.log"
TCPDUMP_H0_LOG="h0_capture.pcap"
TCPDUMP_H5_LOG="h5_capture.pcap"

# Clean up previous logs
rm -f $PING_LOG $IPERF_SERVER_LOG $IPERF_CLIENT_LOG $TCPDUMP_H0_LOG $TCPDUMP_H5_LOG

# Wait for network to be ready
echo "Waiting for Mininet to settle (5s)..."
sleep 5

# --- Initial Path Setup (h0-s0-s1-s10-s7-s8-s5-h5) ---
echo "Setting up initial flows for h0 <-> h5..."
# Forward h0 (10.0.0.1) to h5 (10.0.0.6)
sudo ovs-ofctl add-flow s0 "ip,in_port=1,nw_dst=$H5_IP,actions=output:2"
sudo ovs-ofctl add-flow s1 "ip,in_port=2,nw_dst=$H5_IP,actions=output:3"
sudo ovs-ofctl add-flow s10 "ip,in_port=2,nw_dst=$H5_IP,actions=output:3"
sudo ovs-ofctl add-flow s7 "ip,in_port=4,nw_dst=$H5_IP,actions=output:3"
sudo ovs-ofctl add-flow s8 "ip,in_port=3,nw_dst=$H5_IP,actions=output:2"
sudo ovs-ofctl add-flow s5 "ip,in_port=3,nw_dst=$H5_IP,actions=output:1"

# Reverse h5 (10.0.0.6) to h0 (10.0.0.1)
sudo ovs-ofctl add-flow s5 "ip,in_port=1,nw_dst=$H0_IP,actions=output:3"
sudo ovs-ofctl add-flow s8 "ip,in_port=2,nw_dst=$H0_IP,actions=output:3"
sudo ovs-ofctl add-flow s7 "ip,in_port=3,nw_dst=$H0_IP,actions=output:4"
sudo ovs-ofctl add-flow s10 "ip,in_port=3,nw_dst=$H0_IP,actions=output:2"
sudo ovs-ofctl add-flow s1 "ip,in_port=3,nw_dst=$H0_IP,actions=output:2"
sudo ovs-ofctl add-flow s0 "ip,in_port=2,nw_dst=$H0_IP,actions=output:1"

# --- Setup Congestion Traffic (h6 to h7) ---
# This path (h6-s6-s7-h7) will put load on the s6-s7 link.
# The initial h0-h5 path uses s7. The new path does not.
# This means congestion will primarily affect the first path if s7 is a bottleneck.
echo "Setting up flows for congestion h6 -> h7..."
# Forward h6 (10.0.0.7) to h7 (10.0.0.8) via s6-s7
sudo ovs-ofctl add-flow s6 "udp,in_port=1,nw_dst=$H7_IP,tp_dst=5001,actions=output:4" # h6 to s6, then s6 to s7 (port 4 on s6)
sudo ovs-ofctl add-flow s7 "udp,in_port=2,nw_dst=$H7_IP,tp_dst=5001,actions=output:1" # s6 to s7 (port 2 on s7), then s7 to h7
# Optional: Reverse path for iperf3 control messages if using TCP or for iperf UDP report
sudo ovs-ofctl add-flow s7 "udp,in_port=1,nw_dst=$H6_IP,tp_src=5001,actions=output:2"
sudo ovs-ofctl add-flow s6 "udp,in_port=4,nw_dst=$H6_IP,tp_src=5001,actions=output:1"


echo "Starting measurements..."
# Start tcpdump on h0 and h5 (capturing ICMP for ping and UDP port 5001 for iperf)
# The `mn exec` or `mx` command is used to run commands on Mininet hosts
echo "Starting tcpdump on h0 and h5..."
mx h0 tcpdump -i h0-eth0 -w $TCPDUMP_H0_LOG -U "icmp or (udp and port 5001)" &
TCPDUMP_H0_PID=$!
mx h5 tcpdump -i h5-eth0 -w $TCPDUMP_H5_LOG -U "icmp or (udp and port 5001)" &
TCPDUMP_H5_PID=$!
sleep 1 # Give tcpdump time to start

# Start ping from h0 to h5 (e.g., 10 pings/sec for ~55 seconds)
# -D prints UNIX timestamps, useful for precise delay calculation if needed
# -c count should be high enough to span the whole measurement duration
PING_COUNT=$(($MEASUREMENT_DURATION * 10)) # 10 pings per second
echo "Starting ping h0 -> h5 ($PING_COUNT packets)..."
mx h0 ping -D -i 0.1 -c $PING_COUNT $H5_IP > $PING_LOG &
PING_PID=$!

# Start iperf server on h7 (congestion target)
echo "Starting iperf server on h7..."
mx h7 iperf -s -u -p 5001 > $IPERF_SERVER_LOG &
IPERF_SERVER_PID=$!
sleep 1 # Give server time to start

# Start iperf client on h6 sending UDP traffic to h7 (congestion source)
# Send 5 Mbps for MEASUREMENT_DURATION. Adjust bandwidth (e.g., 5M, 8M)
# to be a significant portion of your link capacity (10Mbps in example topo)
CONGESTION_BW="5M"
echo "Starting iperf client on h6 -> h7 ($CONGESTION_BW for $MEASUREMENT_DURATION s)..."
mx h6 iperf -c $H7_IP -u -p 5001 -b $CONGESTION_BW -t $MEASUREMENT_DURATION > $IPERF_CLIENT_LOG &
IPERF_CLIENT_PID=$!

echo "Initial setup complete. Waiting $SWITCH_TIME seconds before path switch..."
sleep $SWITCH_TIME

# --- Switch Path (h0-s0-s2-s9-s8-s5-h5) ---
echo "Switching path for h0 <-> h5..."
# Delete *specific* old flows. Using "ip,nw_dst=..." is safer than "del-flows sX"
# which would remove ALL flows, including congestion flows.
# Cookie could also be used: add-flow sX "cookie=0x1,..." then del-flows sX "cookie=0x1/-1"
echo "Deleting old flows for h0 <-> h5..."
sudo ovs-ofctl del-flows s0 "ip,nw_dst=$H5_IP"
sudo ovs-ofctl del-flows s1 "ip,nw_dst=$H5_IP" # s1 is no longer on path
sudo ovs-ofctl del-flows s10 "ip,nw_dst=$H5_IP" # s10 is no longer on path
sudo ovs-ofctl del-flows s7 "ip,in_port=4,nw_dst=$H5_IP" # s7 has different in_port if on path

sudo ovs-ofctl del-flows s5 "ip,nw_dst=$H0_IP"
sudo ovs-ofctl del-flows s8 "ip,in_port=2,nw_dst=$H0_IP" # s8 has different in_port
sudo ovs-ofctl del-flows s7 "ip,nw_dst=$H0_IP"
sudo ovs-ofctl del-flows s10 "ip,nw_dst=$H0_IP"
sudo ovs-ofctl del-flows s1 "ip,nw_dst=$H0_IP"
# s0 and s5 will get new rules, so deleting their specific old rule is fine.

echo "Adding new flows for h0 <-> h5..."
# Forward h0 to h5 (New Path: s0-s2-s9-s8-s5)
sudo ovs-ofctl add-flow s0 "ip,in_port=1,nw_dst=$H5_IP,actions=output:3"
sudo ovs-ofctl add-flow s2 "ip,in_port=2,nw_dst=$H5_IP,actions=output:3"
sudo ovs-ofctl add-flow s9 "ip,in_port=2,nw_dst=$H5_IP,actions=output:3"
sudo ovs-ofctl add-flow s8 "ip,in_port=4,nw_dst=$H5_IP,actions=output:2"
sudo ovs-ofctl add-flow s5 "ip,in_port=3,nw_dst=$H5_IP,actions=output:1" # This rule might be same as before if s8-s5 link is reused

# Reverse h5 to h0 (New Path)
sudo ovs-ofctl add-flow s5 "ip,in_port=1,nw_dst=$H0_IP,actions=output:3"
sudo ovs-ofctl add-flow s8 "ip,in_port=2,nw_dst=$H0_IP,actions=output:4"
sudo ovs-ofctl add-flow s9 "ip,in_port=3,nw_dst=$H0_IP,actions=output:2"
sudo ovs-ofctl add-flow s2 "ip,in_port=3,nw_dst=$H0_IP,actions=output:2"
sudo ovs-ofctl add-flow s0 "ip,in_port=3,nw_dst=$H0_IP,actions=output:1"

remaining_time=$(($TOTAL_DURATION - $SWITCH_TIME - 5)) # -5 for initial sleep
echo "Path switched. Waiting for remaining $remaining_time seconds..."
sleep $remaining_time

echo "Stopping measurements and cleaning up..."
kill $PING_PID 2>/dev/null
kill $IPERF_CLIENT_PID 2>/dev/null
# Wait a moment for client to finish telling server, then kill server
sleep 1
kill $IPERF_SERVER_PID 2>/dev/null
# tcpdump might take a moment to flush buffers after SIGTERM
kill $TCPDUMP_H0_PID 2>/dev/null
kill $TCPDUMP_H5_PID 2>/dev/null
wait $TCPDUMP_H0_PID $TCPDUMP_H5_PID 2>/dev/null # Wait for tcpdump to exit

echo "Experiment done. Log files:"
echo "  Ping: $PING_LOG"
echo "  Iperf Server (h7): $IPERF_SERVER_LOG"
echo "  Iperf Client (h6): $IPERF_CLIENT_LOG"
echo "  TCPDump h0: $TCPDUMP_H0_LOG"
echo "  TCPDump h5: $TCPDUMP_H5_LOG"

# Sanity check: Dump final flows (optional)
# echo "Final flows on s0:"
# sudo ovs-ofctl dump-flows s0
# echo "Final flows on s5:"
# sudo ovs-ofctl dump-flows s5
