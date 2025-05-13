#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status.
set -x  # Print commands and their arguments as they are executed.

# --- Configuration ---
OF_VERSION="OpenFlow13"
H0_IP="10.0.0.0"
H5_IP="10.0.0.5"
# MACs are set by Mininet based on host number, e.g. 00:00:00:00:00:00 for h0, ...:05 for h5
# We will primarily match on IP, relying on --arp for L2 resolution.

COOKIE_PATH1="0x1111" # Unique identifier for path 1 flows
COOKIE_PATH2="0x2222" # Unique identifier for path 2 flows

DITG_RECV_LOG="/tmp/h5_ditg_recv.log"
DITG_SEND_LOG="/tmp/h0_ditg_send.log"
DITG_SEND_ACK_LOG="/tmp/h0_ditg_ack.log" # Log for sender about received packets by receiver

# --- Helper Functions ---
add_flow() {
    SWITCH=$1
    COOKIE=$2
    PRIORITY=$3
    MATCH=$4
    ACTION=$5
    echo "EXECUTING: sudo ovs-ofctl -O ${OF_VERSION} add-flow ${SWITCH} \"cookie=${COOKIE},priority=${PRIORITY},${MATCH},actions=${ACTION}\""
    sudo ovs-ofctl -O ${OF_VERSION} add-flow ${SWITCH} "cookie=${COOKIE},priority=${PRIORITY},${MATCH},actions=${ACTION}"
    echo "COMMAND EXECUTED for $SWITCH. Check for errors above if any."
}

del_flows_by_cookie() {
    SWITCH=$1
    COOKIE=$2
    sudo ovs-ofctl -O ${OF_VERSION} del-flows ${SWITCH} "cookie=${COOKIE}/-1" # Mask is -1 to match exact cookie
}

# --- Path 1 Flow Definitions (h0 -> s0-s1-s10-s7-s8-s5 -> h5) ---
# s0-s1-s10-s7-s8-s5
install_path1() {
    echo "Installing Path 1 flows (Cookie: $COOKIE_PATH1)"
    # Forward Path: h0 (10.0.0.0) to h5 (10.0.0.5)
    # s0: h0 (p1) -> s1 (p2)
    add_flow s0 $COOKIE_PATH1 100 "in_port=1,dl_type=0x0800,nw_dst=${H5_IP}" "output:2"
    # s1: s0 (p2) -> s10 (p3)
    add_flow s1 $COOKIE_PATH1 100 "in_port=2,dl_type=0x0800,nw_dst=${H5_IP}" "output:3"
    # s10: s1 (p2) -> s7 (p3)
    add_flow s10 $COOKIE_PATH1 100 "in_port=2,dl_type=0x0800,nw_dst=${H5_IP}" "output:3"
    # s7: s10 (p4) -> s8 (p3)
    add_flow s7 $COOKIE_PATH1 100 "in_port=4,dl_type=0x0800,nw_dst=${H5_IP}" "output:3"
    # s8: s7 (p3) -> s5 (p2, link is s5-eth3<->s8-eth2, so s8-p2 to s5-p3)
    add_flow s8 $COOKIE_PATH1 100 "in_port=3,dl_type=0x0800,nw_dst=${H5_IP}" "output:2"
    # s5: s8 (p3) -> h5 (p1)
    add_flow s5 $COOKIE_PATH1 100 "in_port=3,dl_type=0x0800,nw_dst=${H5_IP}" "output:1"

    # Reverse Path: h5 (10.0.0.5) to h0 (10.0.0.0)
    # s5: h5 (p1) -> s8 (p3)
    add_flow s5 $COOKIE_PATH1 100 "in_port=1,dl_type=0x0800,nw_dst=${H0_IP}" "output:3"
    # s8: s5 (p2) -> s7 (p3)
    add_flow s8 $COOKIE_PATH1 100 "in_port=2,dl_type=0x0800,nw_dst=${H0_IP}" "output:3"
    # s7: s8 (p3) -> s10 (p4)
    add_flow s7 $COOKIE_PATH1 100 "in_port=3,dl_type=0x0800,nw_dst=${H0_IP}" "output:4"
    # s10: s7 (p3) -> s1 (p2)
    add_flow s10 $COOKIE_PATH1 100 "in_port=3,dl_type=0x0800,nw_dst=${H0_IP}" "output:2"
    # s1: s10 (p3) -> s0 (p2)
    add_flow s1 $COOKIE_PATH1 100 "in_port=3,dl_type=0x0800,nw_dst=${H0_IP}" "output:2"
    # s0: s1 (p2) -> h0 (p1)
    add_flow s0 $COOKIE_PATH1 100 "in_port=2,dl_type=0x0800,nw_dst=${H0_IP}" "output:1"
}

uninstall_path1() {
    echo "Uninstalling Path 1 flows (Cookie: $COOKIE_PATH1)"
    del_flows_by_cookie s0 $COOKIE_PATH1
    del_flows_by_cookie s1 $COOKIE_PATH1
    del_flows_by_cookie s10 $COOKIE_PATH1
    del_flows_by_cookie s7 $COOKIE_PATH1
    del_flows_by_cookie s8 $COOKIE_PATH1
    del_flows_by_cookie s5 $COOKIE_PATH1
}

# --- Path 2 Flow Definitions (h0 -> s0-s2-s9-s8-s5 -> h5) ---
# s0-s2-s9-s8-s5
install_path2() {
    echo "Installing Path 2 flows (Cookie: $COOKIE_PATH2)"
    # Forward Path: h0 (10.0.0.0) to h5 (10.0.0.5)
    # s0: h0 (p1) -> s2 (p3)
    add_flow s0 $COOKIE_PATH2 100 "in_port=1,dl_type=0x0800,nw_dst=${H5_IP}" "output:3"
    # s2: s0 (p2) -> s9 (p3)
    add_flow s2 $COOKIE_PATH2 100 "in_port=2,dl_type=0x0800,nw_dst=${H5_IP}" "output:3"
    # s9: s2 (p2) -> s8 (p3, link is s8-eth4<->s9-eth3, so s9-p3 to s8-p4)
    add_flow s9 $COOKIE_PATH2 100 "in_port=2,dl_type=0x0800,nw_dst=${H5_IP}" "output:3"
    # s8: s9 (p4) -> s5 (p2, link is s5-eth3<->s8-eth2, so s8-p2 to s5-p3)
    add_flow s8 $COOKIE_PATH2 100 "in_port=4,dl_type=0x0800,nw_dst=${H5_IP}" "output:2"
    # s5: s8 (p3) -> h5 (p1)
    add_flow s5 $COOKIE_PATH2 100 "in_port=3,dl_type=0x0800,nw_dst=${H5_IP}" "output:1"

    # Reverse Path: h5 (10.0.0.5) to h0 (10.0.0.0)
    # s5: h5 (p1) -> s8 (p3)
    add_flow s5 $COOKIE_PATH2 100 "in_port=1,dl_type=0x0800,nw_dst=${H0_IP}" "output:3"
    # s8: s5 (p2) -> s9 (p4)
    add_flow s8 $COOKIE_PATH2 100 "in_port=2,dl_type=0x0800,nw_dst=${H0_IP}" "output:4"
    # s9: s8 (p3) -> s2 (p2)
    add_flow s9 $COOKIE_PATH2 100 "in_port=3,dl_type=0x0800,nw_dst=${H0_IP}" "output:2"
    # s2: s9 (p3) -> s0 (p2)
    add_flow s2 $COOKIE_PATH2 100 "in_port=3,dl_type=0x0800,nw_dst=${H0_IP}" "output:2"
    # s0: s2 (p3) -> h0 (p1)
    add_flow s0 $COOKIE_PATH2 100 "in_port=3,dl_type=0x0800,nw_dst=${H0_IP}" "output:1"
}

uninstall_path2() {
    echo "Uninstalling Path 2 flows (Cookie: $COOKIE_PATH2)"
    del_flows_by_cookie s0 $COOKIE_PATH2
    del_flows_by_cookie s2 $COOKIE_PATH2
    del_flows_by_cookie s9 $COOKIE_PATH2
    del_flows_by_cookie s8 $COOKIE_PATH2
    del_flows_by_cookie s5 $COOKIE_PATH2
}


# --- Main Execution ---

# Cleanup previous D-ITG logs if they exist
echo "Attempting to remove old D-ITG log files..."
sudo rm -f $DITG_RECV_LOG $DITG_SEND_LOG $DITG_SEND_ACK_LOG
echo "Old D-ITG log files removal attempted."

# Initial cleanup of any lingering flows from previous runs
uninstall_path1
uninstall_path2
echo "Cleaned up old flows."

# Install Path 1
install_path1
echo "Path 1 flows installed."

# Verify connectivity (optional, but good for debugging)
echo "Pinging h5 from h0 to check Path 1..."
# Use Mininet's CLI syntax for executing commands on hosts if this script is run OUTSIDE Mininet CLI
# If running inside Mininet CLI via 'sh run_experiment.sh', then this is fine.
# Otherwise, you'd need to `sudo mnexec -a <pid_of_h0> ping -c 1 ${H5_IP}`
# For simplicity, we'll assume this script's commands are typed into Mininet prompt or
# Mininet hosts are accessed via `mx hX command` or `hX command` from Mininet CLI
# Example using Mininet CLI command structure (you'd put this in Mininet prompt):
# h0 ping -c 1 10.0.0.5

echo "Starting ITGRecv on h5 (listening for 70 seconds)..."
# In Mininet CLI:
# h5 ITGRecv -l $DITG_RECV_LOG &
# RECV_PID=$! # This won't work directly if typed in Mininet CLI
# We'll send a command to mininet to run this.
# A bit tricky to manage PIDs from an external script.
# Simpler to start ITGRecv with a long timeout and kill it later, or just let it run.
# For this script, we'll assume you type ITG commands in Mininet CLI.
echo "In Mininet CLI, type: h5 ITGRecv -l $DITG_RECV_LOG &"
read -p "Press [Enter] after starting ITGRecv on h5..."

echo "Starting ITGSend on h0 for 60 seconds (UDP, 512B packets, 100 packets/sec)..."
# In Mininet CLI:
# h0 ITGSend -a $H5_IP -T UDP -c 512 -C 100 -t 60000 -l $DITG_SEND_LOG -x $DITG_SEND_ACK_LOG &
echo "In Mininet CLI, type: h0 ITGSend -a $H5_IP -T UDP -c 512 -C 100 -t 60000 -l $DITG_SEND_LOG -x $DITG_SEND_ACK_LOG &"
# Let's capture the PID if possible, though from external script it's hard.
# If you run `ITGSend` in Mininet CLI, it will run in background.

echo "Waiting for 30 seconds..."
sleep 30

echo "Switching paths: Uninstalling Path 1, Installing Path 2"
uninstall_path1
install_path2
echo "Path 2 flows installed."

echo "Traffic now on Path 2. Waiting for remaining 30 seconds of ITGSend..."
sleep 30 # Wait for ITGSend to complete its 60-second run

echo "ITGSend should be complete. Stopping ITGRecv on h5 (if needed)..."
# In Mininet CLI, find ITGRecv PID: h5 ps aux | grep ITGRecv
# Then: h5 kill <PID>
# Or simply: h5 killall ITGRecv
echo "In Mininet CLI, type: h5 killall ITGRecv"
read -p "Press [Enter] after stopping ITGRecv on h5..."

echo "Experiment finished."
echo "--------------------"
echo "ANALYSIS:"
echo "Decode D-ITG logs to see results:"
echo "On the machine running Mininet (or copy logs from /tmp/):"
echo "  ITGDec $DITG_RECV_LOG"
echo "This will show packet count, delay, jitter, loss for packets received at h5."
echo "  ITGDec $DITG_SEND_LOG"
echo "This will show packet count for packets sent from h0."
echo "  ITGDec $DITG_SEND_ACK_LOG"
echo "This will show sender's view of successfully received packets (if protocol supports it, e.g. with -rp for receiver port)."
echo ""
echo "Check flow tables on switches (example for s0):"
echo "  sudo ovs-ofctl -O $OF_VERSION dump-flows s0"
echo ""
echo "To clean up all flows on a switch (e.g., s0):"
echo "  sudo ovs-ofctl -O $OF_VERSION del-flows s0"

# Optional: Final cleanup of Path 2 flows
uninstall_path2
