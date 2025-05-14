#!/bin/bash

# Script to run D-ITG test on Abilene topology with path change

# --- Configuration ---
PY_TOPO_FILE="AbileneTopo.py" # Your topology file name
TOPO_NAME="abilenetopo"
DURATION_SEC=60
SWITCH_TIME_SEC=30

SENDER_HOST="h0"
RECEIVER_HOST="h5"

SENDER_IP="10.0.0.1"  # IP of h0 (ensure your topo assigns these or adjust)
RECEIVER_IP="10.0.0.6" # IP of h5 (ensure your topo assigns these or adjust)

SENDER_MAC="00:00:00:00:00:01"
RECEIVER_MAC="00:00:00:00:00:06"

# D-ITG Parameters
PACKET_SIZE=512
PACKET_RATE=200
TRAFFIC_TYPE="UDP"

# Log files *inside* the Mininet host's /tmp directory
DITG_LOG_RECV_ON_HOST="/tmp/itg_recv_log.txt"
DITG_LOG_SEND_ON_HOST="/tmp/itg_send_log.txt"
DITG_RECV_SUMMARY_ON_HOST="/tmp/itg_recv_summary.txt" # Log for -x on sender, written by receiver
DITG_DECODED_OUTPUT_ON_HOST="/tmp/itg_decoded_results.txt"

# Local copy of the decoded results for analysis
DITG_DECODED_OUTPUT_LOCAL="itg_decoded_results.txt"

MININET_MAIN_LOG="/tmp/mininet_main_run.log" # Log for the main Mininet process

# --- Helper Functions ---
cleanup() {
    echo "Stopping Mininet and cleaning up..."
    # Ensure ITGRecv and ITGSend are stopped on hosts
    # Using pkill within the namespace is more robust
    if sudo ip netns list | grep -q "$SENDER_HOST"; then
        mn_exec "$SENDER_HOST" "pkill ITGSend"
    fi
    if sudo ip netns list | grep -q "$RECEIVER_HOST"; then
        mn_exec "$RECEIVER_HOST" "pkill ITGRecv"
    fi

    # Stop the main Mininet process
    # mn -c is the most reliable way to clean up Mininet interfaces, OVS bridges etc.
    sudo mn -c
    echo "Mininet cleanup done."

    echo "Cleaning up D-ITG log files from script directory..."
    rm -f "$DITG_DECODED_OUTPUT_LOCAL"
    # Note: Logs on hosts in /tmp will be cleared if the host namespaces are destroyed by mn -c
    # or on VM reboot.
    echo "Done."
}

# Function to execute commands within Mininet host namespace
# Usage: mn_exec <host_name> <command_string>
mn_exec() {
    local host_name=$1
    shift
    local cmd_string="$@"
    echo "Executing on $host_name (ns): $cmd_string"
    # Execute the command as root within the host's network namespace.
    # 'cd /tmp' ensures relative log file paths for D-ITG are in /tmp within the host.
    # The command string itself should handle backgrounding with '&' if needed.
    sudo ip netns exec "$host_name" bash -c "cd /tmp && $cmd_string"
}

# Function to add flow rules.
# IMPORTANT: Port numbers here are ASSUMPTIONS. VERIFY THEM!
set_path1_flows() {
    echo "Setting up Path 1 flows (h0 -> s0-s2-s9-s8-s5 -> h5)"
    sudo ovs-ofctl add-flow s0 "priority=100,in_port=1,dl_dst=$RECEIVER_MAC,actions=output:3"
    sudo ovs-ofctl add-flow s2 "priority=100,in_port=2,dl_dst=$RECEIVER_MAC,actions=output:3"
    sudo ovs-ofctl add-flow s9 "priority=100,in_port=2,dl_dst=$RECEIVER_MAC,actions=output:3"
    sudo ovs-ofctl add-flow s8 "priority=100,in_port=4,dl_dst=$RECEIVER_MAC,actions=output:2"
    sudo ovs-ofctl add-flow s5 "priority=100,in_port=3,dl_dst=$RECEIVER_MAC,actions=output:1"
    sudo ovs-ofctl add-flow s5 "priority=100,in_port=1,dl_dst=$SENDER_MAC,actions=output:3"
    sudo ovs-ofctl add-flow s8 "priority=100,in_port=2,dl_dst=$SENDER_MAC,actions=output:4"
    sudo ovs-ofctl add-flow s9 "priority=100,in_port=3,dl_dst=$SENDER_MAC,actions=output:2"
    sudo ovs-ofctl add-flow s2 "priority=100,in_port=3,dl_dst=$SENDER_MAC,actions=output:2"
    sudo ovs-ofctl add-flow s0 "priority=100,in_port=3,dl_dst=$SENDER_MAC,actions=output:1"
}

set_path2_flows() {
    echo "Setting up Path 2 flows (h0 -> s0-s1-s10-s7-s6-s4-s5 -> h5)"
    sudo ovs-ofctl add-flow s0 "priority=100,in_port=1,dl_dst=$RECEIVER_MAC,actions=output:2"
    sudo ovs-ofctl add-flow s1 "priority=100,in_port=2,dl_dst=$RECEIVER_MAC,actions=output:3"
    sudo ovs-ofctl add-flow s10 "priority=100,in_port=2,dl_dst=$RECEIVER_MAC,actions=output:3"
    sudo ovs-ofctl add-flow s7 "priority=100,in_port=4,dl_dst=$RECEIVER_MAC,actions=output:2"
    sudo ovs-ofctl add-flow s6 "priority=100,in_port=4,dl_dst=$RECEIVER_MAC,actions=output:3"
    sudo ovs-ofctl add-flow s4 "priority=100,in_port=4,dl_dst=$RECEIVER_MAC,actions=output:3"
    sudo ovs-ofctl add-flow s5 "priority=100,in_port=2,dl_dst=$RECEIVER_MAC,actions=output:1"
    sudo ovs-ofctl add-flow s5 "priority=100,in_port=1,dl_dst=$SENDER_MAC,actions=output:2"
    sudo ovs-ofctl add-flow s4 "priority=100,in_port=3,dl_dst=$SENDER_MAC,actions=output:4"
    sudo ovs-ofctl add-flow s6 "priority=100,in_port=3,dl_dst=$SENDER_MAC,actions=output:4"
    sudo ovs-ofctl add-flow s7 "priority=100,in_port=2,dl_dst=$SENDER_MAC,actions=output:4"
    sudo ovs-ofctl add-flow s10 "priority=100,in_port=3,dl_dst=$SENDER_MAC,actions=output:2"
    sudo ovs-ofctl add-flow s1 "priority=100,in_port=3,dl_dst=$SENDER_MAC,actions=output:2"
    sudo ovs-ofctl add-flow s0 "priority=100,in_port=2,dl_dst=$SENDER_MAC,actions=output:1"
}

delete_all_flows() {
    echo "Deleting all flows from switches..."
    for i in {0..10}; do
        sudo ovs-ofctl del-flows "s$i"
    done
}

# --- Main Script ---
trap cleanup EXIT # Call cleanup function on script exit

# 0. Initial Mininet cleanup
sudo mn -c

# 1. Start Mininet in the background using nohup for robustness
echo "Starting Mininet with topology $TOPO_NAME from $PY_TOPO_FILE..."
# nohup ensures the process isn't killed when the shell exits
# Stdin is redirected from /dev/null, stdout/stderr to a log file
sudo nohup mn --custom "$PY_TOPO_FILE" --topo "$TOPO_NAME" --controller=remote --mac --link=tc < /dev/null > "$MININET_MAIN_LOG" 2>&1 &
# The PID captured by $! for nohup might be nohup itself or the shell used by sudo.
# What matters is that Mininet process is running. `mn -c` will find and kill it.
echo "Mininet start initiated. Log: $MININET_MAIN_LOG. Waiting for it to initialize..."
sleep 15 # Crucial: Give Mininet ample time to start all switches, hosts, and namespaces.
         # Check $MININET_MAIN_LOG for "mininet>" prompt or "completed" messages.
         # If it says "completed" too soon, Mininet isn't staying up.

# Verify Mininet is running and created OVS bridges and host namespaces
if ! sudo ovs-vsctl show > /dev/null 2>&1; then
    echo "ERROR: ovs-vsctl failed. Open vSwitch might not be running or Mininet failed to start correctly."
    cat "$MININET_MAIN_LOG"
    exit 1
fi
if ! sudo ovs-vsctl list-br | grep -q s0; then
    echo "ERROR: Mininet switch s0 not found by ovs-vsctl. Mininet might have failed to initialize OVS bridges."
    echo "Check $MININET_MAIN_LOG"
    cat "$MININET_MAIN_LOG"
    exit 1
fi
if ! sudo ip netns list | grep -q "$SENDER_HOST"; then
    echo "ERROR: Network namespace for $SENDER_HOST not found. Mininet host setup failed."
    echo "Check $MININET_MAIN_LOG"
    cat "$MININET_MAIN_LOG"
    exit 1
fi
echo "Mininet seems to be running with OVS bridges and host namespaces."


echo "VERIFY PORT NUMBERS! The script uses assumed port numbers."
echo "You can check them in another terminal: sudo mn (connects to existing), then 'links' or 'net'."
echo "Or check flows: 'sudo ovs-ofctl dump-flows sX'"
echo "Pausing for 10 seconds for you to check if needed..."
sleep 10

# 2. Delete any existing flows
delete_all_flows

# 3. Set initial path (Path 1)
set_path1_flows
echo "Initial flows (Path 1) set."

# 4. Start D-ITG Receiver on RECEIVER_HOST
echo "Starting ITGRecv on $RECEIVER_HOST..."
mn_exec "$RECEIVER_HOST" "ITGRecv -l $DITG_LOG_RECV_ON_HOST &"
sleep 2

# 5. Start D-ITG Sender on SENDER_HOST
DURATION_MS=$((DURATION_SEC * 1000))
echo "Starting ITGSend on $SENDER_HOST to $RECEIVER_IP for $DURATION_SEC seconds..."
mn_exec "$SENDER_HOST" "ITGSend -T $TRAFFIC_TYPE -a $RECEIVER_IP -c $PACKET_SIZE -C $PACKET_RATE -t $DURATION_MS -l $DITG_LOG_SEND_ON_HOST -x $DITG_RECV_SUMMARY_ON_HOST &"
sleep 1

# 6. Wait until SWITCH_TIME_SEC
echo "Traffic flowing on Path 1 for $SWITCH_TIME_SEC seconds..."
sleep "$SWITCH_TIME_SEC"

# 7. Change the route
echo "Switching to Path 2..."
delete_all_flows
set_path2_flows
echo "Flows switched to Path 2."

# 8. Wait for D-ITG to complete the remaining duration
REMAINING_TIME_SEC=$((DURATION_SEC - SWITCH_TIME_SEC))
if [ $REMAINING_TIME_SEC -gt 0 ]; then
    echo "Traffic flowing on Path 2 for $REMAINING_TIME_SEC seconds..."
    sleep "$REMAINING_TIME_SEC"
fi

echo "Waiting for ITGSend to finish completely (extra buffer)..."
sleep 5 # Buffer for ITGSend to ensure it finishes writing logs

# 9. Stop ITGRecv (explicitly, though cleanup trap also tries)
echo "Attempting to stop ITGRecv on $RECEIVER_HOST..."
mn_exec "$RECEIVER_HOST" "pkill ITGRecv"
sleep 1

# 10. Decode D-ITG logs
echo "Decoding D-ITG receiver log from host $RECEIVER_HOST..."
# Run ITGDec inside the receiver host, outputting to its /tmp
mn_exec "$RECEIVER_HOST" "ITGDec $DITG_LOG_RECV_ON_HOST -o $DITG_DECODED_OUTPUT_ON_HOST"
sleep 1 # give ITGDec a moment

echo "Copying decoded log from $RECEIVER_HOST:$DITG_DECODED_OUTPUT_ON_HOST to local $DITG_DECODED_OUTPUT_LOCAL"
if sudo ip netns exec "$RECEIVER_HOST" test -f "$DITG_DECODED_OUTPUT_ON_HOST"; then
    # Copy content by 'cat'ing from namespace to local file
    sudo ip netns exec "$RECEIVER_HOST" cat "$DITG_DECODED_OUTPUT_ON_HOST" > "$DITG_DECODED_OUTPUT_LOCAL"
    if [ -s "$DITG_DECODED_OUTPUT_LOCAL" ]; then
        echo "Decoded output successfully copied to $DITG_DECODED_OUTPUT_LOCAL"
    else
        echo "WARNING: Copied $DITG_DECODED_OUTPUT_LOCAL is empty. $RECEIVER_HOST:$DITG_DECODED_OUTPUT_ON_HOST might be empty."
        echo "Contents of /tmp on $RECEIVER_HOST:"
        mn_exec "$RECEIVER_HOST" "ls -l /tmp"
        echo "Content of raw receiver log $DITG_LOG_RECV_ON_HOST on $RECEIVER_HOST (if exists):"
        mn_exec "$RECEIVER_HOST" "cat $DITG_LOG_RECV_ON_HOST"
    fi
else
    echo "ERROR: $DITG_DECODED_OUTPUT_ON_HOST not found on $RECEIVER_HOST. Cannot copy."
    echo "Contents of /tmp on $RECEIVER_HOST:"
    mn_exec "$RECEIVER_HOST" "ls -l /tmp"
    echo "Content of raw receiver log $DITG_LOG_RECV_ON_HOST on $RECEIVER_HOST (if exists):"
    mn_exec "$RECEIVER_HOST" "cat $DITG_LOG_RECV_ON_HOST"
fi


# 11. Analyze Results
echo "--- D-ITG Analysis (from $DITG_DECODED_OUTPUT_LOCAL) ---"
if [ -f "$DITG_DECODED_OUTPUT_LOCAL" ] && [ -s "$DITG_DECODED_OUTPUT_LOCAL" ]; then
    TOTAL_PACKETS_SENT=$(echo "$PACKET_RATE * $DURATION_SEC" | bc)
    echo "Expected packets sent by ITGSend: $TOTAL_PACKETS_SENT (approx, based on rate)"

    RECEIVED_PACKETS=$(wc -l < "$DITG_DECODED_OUTPUT_LOCAL")
    echo "Total packets received and decoded: $RECEIVED_PACKETS"

    PACKET_LOSS=$(echo "$TOTAL_PACKETS_SENT - $RECEIVED_PACKETS" | bc)
    if [ "$TOTAL_PACKETS_SENT" -gt 0 ]; then
        LOSS_PERCENTAGE=$(awk -v sent="$TOTAL_PACKETS_SENT" -v recv="$RECEIVED_PACKETS" 'BEGIN { if (sent > 0) printf "%.2f", (sent-recv)*100/sent else print "N/A"}')
        echo "Calculated Packet Loss: $PACKET_LOSS packets ($LOSS_PERCENTAGE%)"
    else
        echo "Calculated Packet Loss: N/A (no packets sent or rate is zero)"
    fi

    AVG_LATENCY_MS=$(awk '{ total_delay += $5; count++ } END { if (count > 0) printf "%.3f", (total_delay / count) * 1000 else print "N/A" }' "$DITG_DECODED_OUTPUT_LOCAL")
    echo "Average One-Way Delay (Latency): $AVG_LATENCY_MS ms"

    OUT_OF_ORDER_COUNT=$(awk '
        BEGIN { last_seq = -1; ooo_count = 0; }
        { current_seq = $2; if (last_seq != -1 && current_seq < last_seq) { ooo_count++; } if (current_seq > last_seq || last_seq == -1) { last_seq = current_seq; } }
        END { print ooo_count; }
    ' "$DITG_DECODED_OUTPUT_LOCAL")
    echo "Out-of-Order Packets Received: $OUT_OF_ORDER_COUNT"
else
    echo "Could not find or process local $DITG_DECODED_OUTPUT_LOCAL. Analysis skipped."
fi

echo "--- Experiment Finished ---"
# Cleanup will be called by trap EXIT
