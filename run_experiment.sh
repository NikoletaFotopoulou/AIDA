#!/bin/bash

# Script to run D-ITG test on Abilene topology with path change

# --- Configuration ---
PY_TOPO_FILE="AbileneTopo.py" # Your topology file name
TOPO_NAME="abilenetopo"
DURATION_SEC=60
SWITCH_TIME_SEC=30

SENDER_HOST="h0"
RECEIVER_HOST="h5"

SENDER_IP="10.0.0.1"  # IP of h0
RECEIVER_IP="10.0.0.6" # IP of h5

SENDER_MAC="00:00:00:00:00:01" # MAC of h0
RECEIVER_MAC="00:00:00:00:00:06" # MAC of h5

# D-ITG Parameters
PACKET_SIZE=512     # bytes
PACKET_RATE=200     # packets per second (pps) - adjust to control congestion
TRAFFIC_TYPE="UDP"  # UDP or TCP
DITG_LOG_RECV="itg_recv_log.txt"
DITG_LOG_SEND="itg_send_log.txt"
DITG_DECODED_OUTPUT="itg_decoded_results.txt"
DITG_RECV_SUMMARY="itg_recv_summary.txt" # D-ITG will create this for -x

# --- Helper Functions ---
cleanup() {
    echo "Stopping Mininet..."
    sudo killall ITGRecv # Ensure ITGRecv is stopped
    if [ -n "$MININET_PID" ]; then
        sudo kill -SIGINT "$MININET_PID"
        wait "$MININET_PID" 2>/dev/null
    fi
    sudo mn -c
    echo "Cleaning up D-ITG log files..."
    rm -f "$DITG_LOG_RECV" "$DITG_LOG_SEND" "$DITG_DECODED_OUTPUT" "$DITG_RECV_SUMMARY"
    echo "Done."
}

# Function to execute commands within Mininet host xterm
# Usage: mn_exec <host_name> <command_string>
mn_exec() {
    local host_name=$1
    shift
    local cmd_string="$@"
    # Using screen in detached mode to run commands in the background inside Mininet
    # Simpler: use the `hX command &` syntax directly in the main script if preferred
    # For this script, we'll use `sudo python -m mininet.term hX $cmd_string` style interaction
    echo "Executing on $host_name: $cmd_string"
    sudo python -m mininet.examples.popen h${host_name#h} "$cmd_string"
}

# Function to add flow rules.
# IMPORTANT: Port numbers here are ASSUMPTIONS based on typical Mininet behavior
# and your AbileneTopo.py structure. VERIFY THEM using `links` in Mininet CLI.
# `sudo ovs-ofctl add-flow <switch> "priority=100,in_port=X,dl_dst=<MAC>,actions=output:Y"`

# Path 1: h0 -> s0 -> s2 -> s9 -> s8 -> s5 -> h5
set_path1_flows() {
    echo "Setting up Path 1 flows (h0 -> s0-s2-s9-s8-s5 -> h5)"
    # Forward path (h0 to h5)
    sudo ovs-ofctl add-flow s0 "priority=100,in_port=1,dl_dst=$RECEIVER_MAC,actions=output:3" # h0(p1) -> s0 -> s2(p3)
    sudo ovs-ofctl add-flow s2 "priority=100,in_port=2,dl_dst=$RECEIVER_MAC,actions=output:3" # s0(p2) -> s2 -> s9(p3)
    sudo ovs-ofctl add-flow s9 "priority=100,in_port=2,dl_dst=$RECEIVER_MAC,actions=output:3" # s2(p2) -> s9 -> s8(p3)
    sudo ovs-ofctl add-flow s8 "priority=100,in_port=4,dl_dst=$RECEIVER_MAC,actions=output:2" # s9(p4) -> s8 -> s5(p2)
    sudo ovs-ofctl add-flow s5 "priority=100,in_port=3,dl_dst=$RECEIVER_MAC,actions=output:1" # s8(p3) -> s5 -> h5(p1)

    # Reverse path (h5 to h0, for acknowledgements if any, or bidirectional traffic)
    sudo ovs-ofctl add-flow s5 "priority=100,in_port=1,dl_dst=$SENDER_MAC,actions=output:3" # h5(p1) -> s5 -> s8(p3)
    sudo ovs-ofctl add-flow s8 "priority=100,in_port=2,dl_dst=$SENDER_MAC,actions=output:4" # s5(p2) -> s8 -> s9(p4)
    sudo ovs-ofctl add-flow s9 "priority=100,in_port=3,dl_dst=$SENDER_MAC,actions=output:2" # s8(p3) -> s9 -> s2(p2)
    sudo ovs-ofctl add-flow s2 "priority=100,in_port=3,dl_dst=$SENDER_MAC,actions=output:2" # s9(p3) -> s2 -> s0(p2)
    sudo ovs-ofctl add-flow s0 "priority=100,in_port=3,dl_dst=$SENDER_MAC,actions=output:1" # s2(p3) -> s0 -> h0(p1)
}

# Path 2: h0 -> s0 -> s1 -> s10 -> s7 -> s6 -> s4 -> s5 -> h5
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

    # Reverse path (h5 to h0)
    sudo ovs-ofctl add-flow s5 "priority=100,in_port=1,dl_dst=$SENDER_MAC,actions=output:2"  # h5(p1) -> s5 -> s4(p2)
    sudo ovs-ofctl add-flow s4 "priority=100,in_port=3,dl_dst=$SENDER_MAC,actions=output:4"  # s5(p3) -> s4 -> s6(p4)
    sudo ovs-ofctl add-flow s6 "priority=100,in_port=3,dl_dst=$SENDER_MAC,actions=output:4"  # s4(p3) -> s6 -> s7(p4)
    sudo ovs-ofctl add-flow s7 "priority=100,in_port=2,dl_dst=$SENDER_MAC,actions=output:4"  # s6(p2) -> s7 -> s10(p4)
    sudo ovs-ofctl add-flow s10 "priority=100,in_port=3,dl_dst=$SENDER_MAC,actions=output:2" # s7(p3) -> s10 -> s1(p2)
    sudo ovs-ofctl add-flow s1 "priority=100,in_port=3,dl_dst=$SENDER_MAC,actions=output:2"  # s10(p3) -> s1 -> s0(p2)
    sudo ovs-ofctl add-flow s0 "priority=100,in_port=2,dl_dst=$SENDER_MAC,actions=output:1"  # s1(p2) -> s0 -> h0(p1)
}

delete_all_flows() {
    echo "Deleting all flows from switches..."
    for i in {0..10}; do
        sudo ovs-ofctl del-flows "s$i"
    done
}

# --- Main Script ---
trap cleanup EXIT # Call cleanup function on script exit (Ctrl+C, normal exit)

# 0. Initial Mininet cleanup
sudo mn -c

# 1. Start Mininet in the background
echo "Starting Mininet with topology $TOPO_NAME from $PY_TOPO_FILE..."
# We use --controller=remote to prevent default L2 learning switch behavior.
# --mac ensures predictable MAC addresses.
# --link=tc allows link parameters if needed later, not strictly for this script.
sudo mn --custom "$PY_TOPO_FILE" --topo "$TOPO_NAME" --controller=remote --mac --link=tc &
MININET_PID=$!
echo "Mininet started with PID $MININET_PID. Waiting for it to initialize..."
sleep 10 # Give Mininet time to start up all switches and hosts

echo "VERIFY PORT NUMBERS! The script uses assumed port numbers."
echo "You can check them in another terminal using Mininet CLI: 'links' or 'net'."
echo "Or check flows: 'sudo ovs-ofctl dump-flows sX'"
echo "Pausing for 10 seconds for you to check if needed..."
sleep 10


# 2. Delete any existing flows (good practice)
delete_all_flows

# 3. Set initial path (Path 1)
set_path1_flows
echo "Initial flows (Path 1) set."

# 4. Start D-ITG Receiver on RECEIVER_HOST
echo "Starting ITGRecv on $RECEIVER_HOST..."
mn_exec "$RECEIVER_HOST" "ITGRecv -l $DITG_LOG_RECV &"
ITGRECV_PID=$(pgrep -f "ITGRecv -l $DITG_LOG_RECV") # Get PID if needed, though often managed by mn_exec
sleep 2 # Give receiver a moment to start

# 5. Start D-ITG Sender on SENDER_HOST
DURATION_MS=$((DURATION_SEC * 1000))
echo "Starting ITGSend on $SENDER_HOST to $RECEIVER_IP for $DURATION_SEC seconds..."
# -x $DITG_RECV_SUMMARY tells receiver to log one-way delay, jitter, etc., useful for ITGDec
mn_exec "$SENDER_HOST" "ITGSend -T $TRAFFIC_TYPE -a $RECEIVER_IP -c $PACKET_SIZE -C $PACKET_RATE -t $DURATION_MS -l $DITG_LOG_SEND -x $DITG_RECV_SUMMARY &"
ITGSEND_PID=$(pgrep -f "ITGSend -T $TRAFFIC_TYPE -a $RECEIVER_IP") # Get PID to wait for it
sleep 1

# 6. Wait until SWITCH_TIME_SEC
echo "Traffic flowing on Path 1 for $SWITCH_TIME_SEC seconds..."
sleep "$SWITCH_TIME_SEC"

# 7. Change the route
echo "Switching to Path 2..."
delete_all_flows # Delete old flows
set_path2_flows  # Add new flows
echo "Flows switched to Path 2."

# 8. Wait for D-ITG to complete the remaining duration
REMAINING_TIME_SEC=$((DURATION_SEC - SWITCH_TIME_SEC))
if [ $REMAINING_TIME_SEC -gt 0 ]; then
    echo "Traffic flowing on Path 2 for $REMAINING_TIME_SEC seconds..."
    sleep "$REMAINING_TIME_SEC"
else
    echo "Total duration reached at switch time."
fi

echo "Waiting for ITGSend to finish completely..."
# Wait for ITGSend to naturally finish if it hasn't already
# This can be done by `wait $ITGSEND_PID` if `mn_exec` ran it as a direct child of the script
# For now, a small buffer sleep.
sleep 5

# 9. Stop ITGRecv (usually done via cleanup, but can be explicit)
echo "Stopping ITGRecv..."
# mn_exec "$RECEIVER_HOST" "killall ITGRecv" # Or use pkill if more robust
# The trap cleanup will also attempt this.

# 10. Decode D-ITG logs
echo "Decoding D-ITG receiver log..."
# The log file is created inside the Mininet host's filesystem view.
# We need to access it from the main system. Mininet usually mounts /tmp.
# A robust way is to copy it out, or have ITGRecv write to a shared mount.
# For simplicity, let's assume the file is accessible, or D-ITG commands can be run via `mn_exec`.
# If ITGRecv was started with `mn_exec ... ITGRecv -l /tmp/$DITG_LOG_RECV`, then it's easier.
# Let's assume $DITG_LOG_RECV is in the current directory because mn_exec might run it there.
# If not, you might need to copy it: `sudo cp /tmp/$DITG_LOG_RECV .` if Mininet uses /tmp
# Or run ITGDec inside the receiver host:
# mn_exec "$RECEIVER_HOST" "ITGDec $DITG_LOG_RECV > /tmp/$DITG_DECODED_OUTPUT"
# sudo cp /tmp/$DITG_DECODED_OUTPUT .

# Assuming DITG_LOG_RECV is in the current directory (or accessible path)
if [ -f "$DITG_LOG_RECV" ]; then
    ITGDec "$DITG_LOG_RECV" > "$DITG_DECODED_OUTPUT"
    echo "Decoded output saved to $DITG_DECODED_OUTPUT"
else
    echo "ERROR: $DITG_LOG_RECV not found. Cannot decode."
    # Attempt to run ITGDec inside the host, assuming log is there
    mn_exec "$RECEIVER_HOST" "ITGDec $DITG_LOG_RECV > $DITG_DECODED_OUTPUT"
    # This will place $DITG_DECODED_OUTPUT inside the host's file system view.
    # You'd then need to copy it out, e.g., if host h5 wrote it to its /root/:
    # sudo cp $(sudo find /tmp/mininet-h5/root -name $DITG_DECODED_OUTPUT) .
    echo "Attempted to run ITGDec inside $RECEIVER_HOST. Check its file system for $DITG_DECODED_OUTPUT."
fi


# 11. Analyze Results (basic analysis using awk)
echo "--- D-ITG Analysis ---"
if [ -f "$DITG_DECODED_OUTPUT" ] && [ -s "$DITG_DECODED_OUTPUT" ]; then
    TOTAL_PACKETS_SENT=$(echo "$PACKET_RATE * $DURATION_SEC" | bc)
    echo "Expected packets sent by ITGSend: $TOTAL_PACKETS_SENT (approx, based on rate)"

    # Count received packets
    RECEIVED_PACKETS=$(wc -l < "$DITG_DECODED_OUTPUT")
    echo "Total packets received and decoded: $RECEIVED_PACKETS"

    # Calculate Packet Loss
    # Note: ITGSend log also contains info about sent packets if needed for more accuracy
    PACKET_LOSS=$(echo "$TOTAL_PACKETS_SENT - $RECEIVED_PACKETS" | bc)
    if [ "$TOTAL_PACKETS_SENT" -gt 0 ]; then
        LOSS_PERCENTAGE=$(awk -v sent="$TOTAL_PACKETS_SENT" -v recv="$RECEIVED_PACKETS" 'BEGIN { if (sent > 0) printf "%.2f", (sent-recv)*100/sent else print "N/A"}')
        echo "Calculated Packet Loss: $PACKET_LOSS packets ($LOSS_PERCENTAGE%)"
    else
        echo "Calculated Packet Loss: N/A (no packets sent or rate is zero)"
    fi


    # Average Latency (One-Way Delay)
    # ITGDec output format (typical): flow_id seq_num tx_time rx_time delay_OWD
    # The 5th column is usually one-way delay in seconds.
    AVG_LATENCY_MS=$(awk '{ total_delay += $5; count++ } END { if (count > 0) printf "%.3f", (total_delay / count) * 1000 else print "N/A" }' "$DITG_DECODED_OUTPUT")
    echo "Average One-Way Delay (Latency): $AVG_LATENCY_MS ms"

    # Out-of-Order Packets
    # We check if sequence number (2nd column) decreases.
    # This simple check assumes a single flow.
    OUT_OF_ORDER_COUNT=$(awk '
        BEGIN { last_seq = -1; ooo_count = 0; }
        {
            current_seq = $2;
            if (last_seq != -1 && current_seq < last_seq) {
                ooo_count++;
            }
            if (current_seq > last_seq) { # handles initial case and seq wraps for very long tests
                 last_seq = current_seq;
            } else if (last_seq == -1) { # first packet
                 last_seq = current_seq;
            }
        }
        END { print ooo_count; }
    ' "$DITG_DECODED_OUTPUT")
    echo "Out-of-Order Packets Received: $OUT_OF_ORDER_COUNT"

else
    echo "Could not find or process $DITG_DECODED_OUTPUT. Analysis skipped."
fi

echo "--- Experiment Finished ---"
# Cleanup will be called by trap EXIT
