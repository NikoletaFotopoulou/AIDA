#!/bin/bash

# --- Configuration ---
MININET_TOPO_FILE="abilene_topo.py" # YOUR Mininet topology Python file name
H_SRC="h0"
H_DST="h5"
H_SRC_IP="10.0.0.1"  # Default Mininet IP for h0
H_DST_IP="10.0.0.6"  # Default Mininet IP for h5
H_SRC_MAC="00:00:00:00:00:01" # Default Mininet MAC for h0
H_DST_MAC="00:00:00:00:00:06" # Default Mininet MAC for h5

TOTAL_DURATION=60     # Total seconds for D-ITG traffic
SWITCH_OVER_TIME=30   # Seconds after which to switch the path

# D-ITG Parameters (UDP traffic)
DITG_PPS=100          # Packets per second
DITG_PKT_SIZE=512     # Bytes per packet
DITG_SENDER_LOG_BASENAME="itg_sender.log"
DITG_RECEIVER_LOG_BASENAME="itg_receiver.log"
DITG_DECODED_LOG_BASENAME="itg_decoded_results.txt"

DITG_DURATION_MS_CALCULATED=$(($TOTAL_DURATION * 1000))
REMAINING_TIME_CALCULATED=$(($TOTAL_DURATION - $SWITCH_OVER_TIME))

if ! command -v ITGRecv &> /dev/null || ! command -v ITGSend &> /dev/null || ! command -v ITGDec &> /dev/null; then
    echo "ERROR: D-ITG commands not found."
    exit 1
fi
if [ ! -f "$MININET_TOPO_FILE" ]; then
    echo "ERROR: Mininet topology file '$MININET_TOPO_FILE' not found."
    exit 1
fi
rm -f $DITG_SENDER_LOG_BASENAME $DITG_RECEIVER_LOG_BASENAME $DITG_DECODED_LOG_BASENAME

echo "INFO: Starting Mininet and running the experiment..."
echo "      Total D-ITG duration: $TOTAL_DURATION seconds."
echo "      Path switch will occur at: $SWITCH_OVER_TIME seconds."
echo "      D-ITG sender duration in ms: $DITG_DURATION_MS_CALCULATED"
echo "      Time on second path: $REMAINING_TIME_CALCULATED seconds"

sudo mn --custom "$MININET_TOPO_FILE" --topo abilenetopo --controller=remote --switch ovs,protocols=OpenFlow10 --mac << EOF

sh echo "[MN] Mininet session started. Performing initial setup."
sh echo "[MN] Deleting all existing flows from all switches..."
sh for i in \$(seq 0 10); do sudo ovs-ofctl del-flows s\$i; done
sh echo "[MN] Adding ARP flooding rules to all switches..."
sh for i in \$(seq 0 10); do sudo ovs-ofctl add-flow s\$i "priority=1,arp,actions=FLOOD"; done

sh echo "[MN] Setting up OpenFlow rules for PATH 1: $H_SRC -> s0 -> s1 -> s10 -> s7 -> s6 -> s4 -> s5 -> $H_DST"
sh sudo ovs-ofctl add-flow s0 "priority=100,in_port=1,dl_dst=$H_DST_MAC,actions=output:2"
sh sudo ovs-ofctl add-flow s1 "priority=100,in_port=2,dl_dst=$H_DST_MAC,actions=output:3"
sh sudo ovs-ofctl add-flow s10 "priority=100,in_port=2,dl_dst=$H_DST_MAC,actions=output:3"
sh sudo ovs-ofctl add-flow s7 "priority=100,in_port=4,dl_dst=$H_DST_MAC,actions=output:2"
sh sudo ovs-ofctl add-flow s6 "priority=100,in_port=4,dl_dst=$H_DST_MAC,actions=output:3"
sh sudo ovs-ofctl add-flow s4 "priority=100,in_port=4,dl_dst=$H_DST_MAC,actions=output:3"
sh sudo ovs-ofctl add-flow s5 "priority=100,in_port=2,dl_dst=$H_DST_MAC,actions=output:1"
sh sudo ovs-ofctl add-flow s5 "priority=100,in_port=1,dl_dst=$H_SRC_MAC,actions=output:2"
sh sudo ovs-ofctl add-flow s4 "priority=100,in_port=3,dl_dst=$H_SRC_MAC,actions=output:4"
sh sudo ovs-ofctl add-flow s6 "priority=100,in_port=3,dl_dst=$H_SRC_MAC,actions=output:4"
sh sudo ovs-ofctl add-flow s7 "priority=100,in_port=2,dl_dst=$H_SRC_MAC,actions=output:4"
sh sudo ovs-ofctl add-flow s10 "priority=100,in_port=3,dl_dst=$H_SRC_MAC,actions=output:2"
sh sudo ovs-ofctl add-flow s1 "priority=100,in_port=3,dl_dst=$H_SRC_MAC,actions=output:2"
sh sudo ovs-ofctl add-flow s0 "priority=100,in_port=2,dl_dst=$H_SRC_MAC,actions=output:1"

sh echo "[MN] Starting D-ITG Receiver on $H_DST ($H_DST_IP)..."
$H_DST ITGRecv -l ../$DITG_RECEIVER_LOG_BASENAME &
sh true
sh echo "[MN] D-ITG Receiver started on $H_DST."
sh sleep 2

sh echo "[MN] Starting D-ITG Sender on $H_SRC to $H_DST_IP for $TOTAL_DURATION seconds ($DITG_DURATION_MS_CALCULATED ms)..."
$H_SRC ITGSend -a $H_DST_IP -T UDP -c $DITG_PKT_SIZE -C $DITG_PPS -t $DITG_DURATION_MS_CALCULATED -l ../$DITG_SENDER_LOG_BASENAME -x ../$DITG_RECEIVER_LOG_BASENAME &
sh true
sh echo "[MN] D-ITG Sender started on $H_SRC."

sh echo "[MN] Running traffic on PATH 1 for $SWITCH_OVER_TIME seconds..."
sh sleep $SWITCH_OVER_TIME

sh echo "[MN] >>> Path switch occurring NOW! <<<"
sh echo "[MN] Deleting all existing flows from all switches..."
sh for i in \$(seq 0 10); do sudo ovs-ofctl del-flows s\$i; done
sh echo "[MN] Re-adding ARP flooding rules to all switches..."
sh for i in \$(seq 0 10); do sudo ovs-ofctl add-flow s\$i "priority=1,arp,actions=FLOOD"; done

sh echo "[MN] Setting up OpenFlow rules for PATH 2: $H_SRC -> s0 -> s2 -> s9 -> s8 -> s5 -> $H_DST"
sh sudo ovs-ofctl add-flow s0 "priority=100,in_port=1,dl_dst=$H_DST_MAC,actions=output:3"
sh sudo ovs-ofctl add-flow s2 "priority=100,in_port=3,dl_dst=$H_DST_MAC,actions=output:2"
sh sudo ovs-ofctl add-flow s9 "priority=100,in_port=2,dl_dst=$H_DST_MAC,actions=output:3"
sh sudo ovs-ofctl add-flow s8 "priority=100,in_port=4,dl_dst=$H_DST_MAC,actions=output:2"
sh sudo ovs-ofctl add-flow s5 "priority=100,in_port=3,dl_dst=$H_DST_MAC,actions=output:1"
sh sudo ovs-ofctl add-flow s5 "priority=100,in_port=1,dl_dst=$H_SRC_MAC,actions=output:3"
sh sudo ovs-ofctl add-flow s8 "priority=100,in_port=2,dl_dst=$H_SRC_MAC,actions=output:4"
sh sudo ovs-ofctl add-flow s9 "priority=100,in_port=3,dl_dst=$H_SRC_MAC,actions=output:2"
sh sudo ovs-ofctl add-flow s2 "priority=100,in_port=2,dl_dst=$H_SRC_MAC,actions=output:3"
sh sudo ovs-ofctl add-flow s0 "priority=100,in_port=3,dl_dst=$H_SRC_MAC,actions=output:1"

sh echo "[MN] Traffic running on PATH 2 for $REMAINING_TIME_CALCULATED seconds..."
sh sleep $REMAINING_TIME_CALCULATED

sh echo "[MN] D-ITG sender should be finished. Waiting a few more seconds..."
sh sleep 5 
sh echo "[MN] Stopping D-ITG Receiver on $H_DST..."
$H_DST pkill -SIGINT ITGRecv
sh echo "[MN] Experiment finished within Mininet. Exiting Mininet CLI."
exit
EOF

echo "INFO: Mininet session has ended."
sleep 2 

echo "INFO: Analyzing D-ITG logs..."
if [ -f "$DITG_RECEIVER_LOG_BASENAME" ]; then
    echo "INFO: Decoding $DITG_RECEIVER_LOG_BASENAME with ITGDec..."
    ITGDec "$DITG_RECEIVER_LOG_BASENAME" > "$DITG_DECODED_LOG_BASENAME"
    echo "INFO: D-ITG results decoded into $DITG_DECODED_LOG_BASENAME"
    echo ""
    echo "--- D-ITG Analysis Results ---"
    TOTAL_SENT_PACKETS=$(($DITG_PPS * $TOTAL_DURATION))
    RECEIVED_PACKETS_LINE=$(grep "NUMBER OF RECEIVED PACKETS" "$DITG_DECODED_LOG_BASENAME")
    RECEIVED_PACKETS=$(echo "$RECEIVED_PACKETS_LINE" | awk '{print $NF}')
    AVG_DELAY_LINE=$(grep "AVERAGE DELAY" "$DITG_DECODED_LOG_BASENAME")
    AVG_DELAY=$(echo "$AVG_DELAY_LINE" | awk '{print $3}')
    UNIT_DELAY=$(echo "$AVG_DELAY_LINE" | awk '{print $4}')
    AVG_JITTER_LINE=$(grep "AVERAGE.*JITTER" "$DITG_DECODED_LOG_BASENAME" | head -n 1)
    AVG_JITTER=$(echo "$AVG_JITTER_LINE" | awk '{print $3}')
    UNIT_JITTER=$(echo "$AVG_JITTER_LINE" | awk '{print $4}')
    OUT_OF_ORDER_LINE=$(grep "OUT-OF-ORDER PACKETS" "$DITG_DECODED_LOG_BASENAME")
    OUT_OF_ORDER_PACKETS=$(echo "$OUT_OF_ORDER_LINE" | awk '{print $NF}')
    echo "Total Packets Sent (calculated): $TOTAL_SENT_PACKETS"
    if [[ -n "$RECEIVED_PACKETS" && "$RECEIVED_PACKETS" =~ ^[0-9]+$ ]]; then
        echo "Total Packets Received: $RECEIVED_PACKETS"
        LOST_PACKETS_CALCULATED=$(($TOTAL_SENT_PACKETS - $RECEIVED_PACKETS))
        if [ "$TOTAL_SENT_PACKETS" -gt 0 ]; then 
            LOSS_PERCENTAGE=$(awk "BEGIN {printf \"%.2f%%\", ($LOST_PACKETS_CALCULATED*100)/$TOTAL_SENT_PACKETS}")
        else
            LOSS_PERCENTAGE="N/A (0 sent)"
        fi
        echo "Packets Lost (calculated): $LOST_PACKETS_CALCULATED ($LOSS_PERCENTAGE)"
    else
        echo "Total Packets Received: N/A (check $DITG_DECODED_LOG_BASENAME for 'NUMBER OF RECEIVED PACKETS')"
        echo "Packets Lost: N/A (could not calculate)"
    fi
    if [[ -n "$AVG_DELAY" ]]; then
        echo "Average One-Way Delay: $AVG_DELAY ${UNIT_DELAY:-}"
    else
        echo "Average One-Way Delay: N/A (check $DITG_DECODED_LOG_BASENAME for 'AVERAGE DELAY')"
    fi
    if [[ -n "$AVG_JITTER" ]]; then
        echo "Average Jitter: $AVG_JITTER ${UNIT_JITTER:-}"
    else
        echo "Average Jitter: N/A (check $DITG_DECODED_LOG_BASENAME for 'AVERAGE JITTER')"
    fi
    if [[ -n "$OUT_OF_ORDER_PACKETS" ]]; then
        echo "Out-of-Order Packets: $OUT_OF_ORDER_PACKETS"
    else
        echo "Out-of-Order Packets: N/A (check $DITG_DECODED_LOG_BASENAME for 'OUT-OF-ORDER PACKETS')"
    fi
    echo "------------------------------"
    echo "For detailed D-ITG results, see the file: $DITG_DECODED_LOG_BASENAME"
else
    echo "ERROR: D-ITG receiver log file ($DITG_RECEIVER_LOG_BASENAME) not found. Analysis cannot be performed."
    echo "       This usually means ITGRecv did not run correctly or couldn't write its log file."
    echo "       Check for errors earlier in the Mininet session output, especially around '[MN] Starting D-ITG Receiver'."
fi
echo "INFO: Cleaning up any remaining Mininet processes..."
sudo mn -c
echo "INFO: Script finished."
