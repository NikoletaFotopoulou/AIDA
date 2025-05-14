#!/bin/bash

# --- Configuration ---
PY_TOPO_FILE="AbileneTopo.py" # Your topology file name
TOPO_NAME="abilenetopo"
SWITCH_DELAY_SEC=15 # Time to wait before switching paths

SENDER_HOST_NAME="h0"
RECEIVER_HOST_NAME="h5"

# MAC addresses (Mininet default: 00:00:00:00:00:0X for h(X-1))
SENDER_MAC="00:00:00:00:00:01" # MAC of h0
RECEIVER_MAC="00:00:00:00:00:06" # MAC of h5

# IP addresses (Mininet default: 10.0.0.X for h(X-1))
RECEIVER_IP="10.0.0.6" # IP of h5

MININET_LOG="/tmp/mininet_simple_run.log"

# --- Helper Functions ---
cleanup() {
    echo "Cleaning up Mininet..."
    if [ -n "$MININET_PID" ] && ps -p "$MININET_PID" > /dev/null; then
        sudo kill -SIGINT "$MININET_PID"
        wait "$MININET_PID" 2>/dev/null
    fi
    sudo mn -c # General Mininet cleanup
    echo "Cleanup complete."
}

# Function to execute commands within Mininet host namespace
mn_exec_simple() {
    local host_name=$1
    shift
    local cmd_string="$@"
    echo "Executing on $host_name: $cmd_string"
    sudo ip netns exec "$host_name" bash -c "$cmd_string"
}

# Path 1: h0 -> s0 -> s2 -> s9 -> s8 -> s5 -> h5
# Port numbers are ASSUMPTIONS. VERIFY THEM in Mininet CLI with 'links' or 'net'.
set_path1_flows() {
    echo "Setting up Path 1 flows (h0 -> s0-s2-s9-s8-s5 -> h5)"
    # Forward path (h0 to h5)
    sudo ovs-ofctl add-flow s0 "priority=100,in_port=1,dl_dst=$RECEIVER_MAC,actions=output:3" # h0(p1) -> s0 -> s2(p3)
    sudo ovs-ofctl add-flow s2 "priority=100,in_port=2,dl_dst=$RECEIVER_MAC,actions=output:3" # s0(p2) -> s2 -> s9(p3)
    sudo ovs-ofctl add-flow s9 "priority=100,in_port=2,dl_dst=$RECEIVER_MAC,actions=output:3" # s2(p2) -> s9 -> s8(p3)
    sudo ovs-ofctl add-flow s8 "priority=100,in_port=4,dl_dst=$RECEIVER_MAC,actions=output:2" # s9(p4) -> s8 -> s5(p2)
    sudo ovs-ofctl add-flow s5 "priority=100,in_port=3,dl_dst=$RECEIVER_MAC,actions=output:1" # s8(p3) -> s5 -> h5(p1)

    # Reverse path (h5 to h0, for ping replies)
    sudo ovs-ofctl add-flow s5 "priority=100,in_port=1,dl_dst=$SENDER_MAC,actions=output:3" # h5(p1) -> s5 -> s8(p3)
    sudo ovs-ofctl add-flow s8 "priority=100,in_port=2,dl_dst=$SENDER_MAC,actions=output:4" # s5(p2) -> s8 -> s9(p4)
    sudo ovs-ofctl add-flow s9 "priority=100,in_port=3,dl_dst=$SENDER_MAC,actions=output:2" # s8(p3) -> s9 -> s2(p2)
    sudo ovs-ofctl add-flow s2 "priority=100,in_port=3,dl_dst=$SENDER_MAC,actions=output:2" # s9(p3) -> s2 -> s0(p2)
    sudo ovs-ofctl add-flow s0 "priority=100,in_port=3,dl_dst=$SENDER_MAC,actions=output:1" # s2(p3) -> s0 -> h0(p1)
}

# Path 2: h0 -> s0 -> s1 -> s10 -> s7 -> s6 -> s4 -> s5 -> h5
# Port numbers are ASSUMPTIONS. VERIFY THEM!
set_path2_flows() {
    echo "Setting up Path 2 flows (h0 -> s0-s1-s10-s7-s6-s4-s5 -> h5)"
    # Forward path (h0 to h5)
    sudo ovs-ofctl add-flow s0 "priority=100,in_port=1,dl_dst=$RECEIVER_MAC,actions=output:2"  # h0(p1) -> s0 -> s1(p2)
    sudo ovs-ofctl add-flow s1 "priority=100,in_port=2,dl_dst=$RECEIVER_MAC,actions=output:3"  # s0(p2) -> s1 -> s10(p3)
    sudo ovs-ofctl add-flow s10 "priority=100,in_port=2,dl_dst=$RECEIVER_MAC,actions=output:3" # s1(p2) -> s10 -> s7(p3)
    sudo ovs-ofctl add-flow s7 "priority=100,in_port=4,dl_dst=$RECEIVER_MAC,actions=output:2"  # s10(p4) -> s7 -> s6(p2)
    sudo ovs-ofctl add-flow s6 "priority=100,in_port=4,dl_dst=$RECEIVER_MAC,actions=output:3"  # s7(p4) -> s6 -> s4(p3)
    sudo ovs-ofctl add-flow s4 "priority=100,in_port=4,dl_dst=$RECEIVER_MAC,actions=output:3"  # s6(p4) -> s4 -> s5(p3)
    sudo ovs-ofctl add-flow s5 "priority=100,in_port=2,dl_dst=$RECEIVER_MAC,actions=output:1"  # s4(p2) -> s5 -> h5(p1)

    # Reverse path (h5 to h0, for ping replies)
    sudo ovs-ofctl add-flow s5 "priority=100,in_port=1,dl_dst=$SENDER_MAC,actions=output:2"  # h5(p1) -> s5 -> s4(p2)
    sudo ovs-ofctl add-flow s4 "priority=100,in_port=3,dl_dst=$SENDER_MAC,actions=output:4"  # s5(p3) -> s4 -> s6(p4)
    sudo ovs-ofctl add-flow s6 "priority=100,in_port=3,dl_dst=$SENDER_MAC,actions=output:4"  # s4(p3) -> s6 -> s7(p4)
    sudo ovs-ofctl add-flow s7 "priority=100,in_port=2,dl_dst=$SENDER_MAC,actions=output:4"  # s6(p2) -> s7 -> s10(p4)
    sudo ovs-ofctl add-flow s10 "priority=100,in_port=3,dl_dst=$SENDER_MAC,actions=output:2" # s7(p3) -> s10 -> s1(p2)
    sudo ovs-ofctl add-flow s1 "priority=100,in_port=3,dl_dst=$SENDER_MAC,actions=output:2"  # s10(p3) -> s1 -> s0(p2)
    sudo ovs-ofctl add-flow s0 "priority=100,in_port=2,dl_dst=$SENDER_MAC,actions=output:1"  # s1(p2) -> s0 -> h0(p1)
}

delete_all_flows() {
    echo "Deleting all flows from all switches..."
    for i in {0..10}; do
        sudo ovs-ofctl del-flows "s$i"
    done
}

# --- Main Script ---
trap cleanup EXIT # Call cleanup function on script exit (Ctrl+C, normal exit)

# 0. Initial Mininet cleanup
sudo mn -c

# 1. Start Mininet in the background
# We use a trick: start Mininet and have it execute a long sleep command internally.
# This keeps the Mininet process alive.
# The sleep duration should be longer than your script's expected runtime.
KEEPALIVE_DURATION=$((SWITCH_DELAY_SEC + 30)) # e.g., 15s switch + 30s buffer

echo "Starting Mininet with topology $TOPO_NAME from $PY_TOPO_FILE (will stay alive for $KEEPALIVE_DURATION s)..."
sudo mn --custom "$PY_TOPO_FILE" --topo "$TOPO_NAME" --controller=remote --mac --link=tc \
         bash -c "echo Mininet CLI is running a sleep for $KEEPALIVE_DURATION seconds to keep the network up.; sleep $KEEPALIVE_DURATION" > "$MININET_LOG" 2>&1 &
MININET_PID=$! # Get PID of the mn command itself

echo "Mininet started with PID $MININET_PID. Log: $MININET_LOG. Waiting for it to initialize..."
sleep 15 # Give Mininet ample time to start up, create OVS bridges and host namespaces.
         # Check $MININET_LOG for errors or "Mininet CLI is running..." message.

# Verify Mininet started correctly and OVS bridges exist
if ! sudo ovs-vsctl list-br | grep -q s0; then
    echo "ERROR: Mininet switch s0 not found. Mininet might have failed to start."
    echo "Check log: $MININET_LOG"
    cat "$MININET_LOG"
    exit 1
fi
if ! sudo ip netns list | grep -q $SENDER_HOST_NAME; then
    echo "ERROR: Network namespace for $SENDER_HOST_NAME not found."
    echo "Check log: $MININET_LOG"
    cat "$MININET_LOG"
    exit 1
fi
echo "Mininet seems to be running."

echo ""
echo "IMPORTANT: The port numbers in flow rules are ASSUMPTIONS."
echo "If pings fail, verify port numbers by opening a new terminal, running 'sudo mn -c && sudo mn --custom $PY_TOPO_FILE --topo $TOPO_NAME --controller=remote -x', then using 'links' or 'net' in the Mininet CLI."
echo "Then adjust set_path1_flows and set_path2_flows in this script."
echo "Pausing for 10s for you to read this / prepare to check ports if needed..."
sleep 10


# 2. Delete any existing flows (good practice)
delete_all_flows

# 3. Set initial path (Path 1)
set_path1_flows
echo "Initial flows (Path 1) set."

# 4. Test connectivity on Path 1
echo "Pinging $RECEIVER_HOST_NAME ($RECEIVER_IP) from $SENDER_HOST_NAME on Path 1..."
mn_exec_simple "$SENDER_HOST_NAME" "ping -c 3 $RECEIVER_IP"
if [ $? -eq 0 ]; then
    echo "Ping on Path 1 SUCCESSFUL."
else
    echo "Ping on Path 1 FAILED. Check flow rules and port numbers!"
fi
echo ""

# 5. Wait for SWITCH_DELAY_SEC
echo "Waiting for $SWITCH_DELAY_SEC seconds before switching paths..."
sleep "$SWITCH_DELAY_SEC"

# 6. Change the route: Delete Path 1 flows, Add Path 2 flows
echo "Switching to Path 2..."
delete_all_flows
set_path2_flows
echo "Flows switched to Path 2."

# 7. Test connectivity on Path 2
echo "Pinging $RECEIVER_HOST_NAME ($RECEIVER_IP) from $SENDER_HOST_NAME on Path 2..."
mn_exec_simple "$SENDER_HOST_NAME" "ping -c 3 $RECEIVER_IP"
if [ $? -eq 0 ]; then
    echo "Ping on Path 2 SUCCESSFUL."
else
    echo "Ping on Path 2 FAILED. Check flow rules and port numbers!"
fi
echo ""

echo "Experiment finished. Mininet will be stopped by the cleanup trap or when its internal sleep finishes."
# The trap EXIT will call cleanup()
