#!/bin/bash

# D-ITG test script for Mininet Abilene topology with flow rule changes

# Configuration
HOST1="h0"       # Source host (New York)
HOST2="h6"       # Destination host (Denver)
DURATION=60      # Test duration in seconds
CHANGE_TIME=30   # When to change the route (seconds)
ITG_RECV_PORT=9000  # Port for ITGRecv
LOG_DIR="./itg_logs"
mkdir -p $LOG_DIR

# MAC addresses (Mininet's default pattern)
MAC1="00:00:00:00:00:01"  # h0
MAC2="00:00:00:00:00:07"  # h6

# Function to set flow rules for path 1 (initial path: s0->s1->s10->s7->s6)
setup_initial_flows() {
    echo "Setting up initial flow rules..."
    
    # s0 (New York) - send to s1 (Chicago) out port 2 (assuming port 1 is host)
    sudo ovs-ofctl add-flow s0 "priority=100,in_port=1,dl_dst=$MAC2,actions=output:2"
    
    # s1 (Chicago) - receive from s0 port X, send to s10 (Indianapolis)
    sudo ovs-ofctl add-flow s1 "priority=100,in_port=1,dl_dst=$MAC2,actions=output:3"
    
    # s10 (Indianapolis) - receive from s1, send to s7 (Kansas City)
    sudo ovs-ofctl add-flow s10 "priority=100,in_port=2,dl_dst=$MAC2,actions=output:3"
    
    # s7 (Kansas City) - receive from s10, send to s6 (Denver)
    sudo ovs-ofctl add-flow s7 "priority=100,in_port=3,dl_dst=$MAC2,actions=output:2"
    
    # s6 (Denver) - receive from s7, send to host
    sudo ovs-ofctl add-flow s6 "priority=100,in_port=2,dl_dst=$MAC2,actions=output:1"
    
    # Reverse path (for two-way communication)
    sudo ovs-ofctl add-flow s6 "priority=100,in_port=1,dl_dst=$MAC1,actions=output:2"
    sudo ovs-ofctl add-flow s7 "priority=100,in_port=2,dl_dst=$MAC1,actions=output:3"
    sudo ovs-ofctl add-flow s10 "priority=100,in_port=3,dl_dst=$MAC1,actions=output:2"
    sudo ovs-ofctl add-flow s1 "priority=100,in_port=3,dl_dst=$MAC1,actions=output:1"
    sudo ovs-ofctl add-flow s0 "priority=100,in_port=2,dl_dst=$MAC1,actions=output:1"
}

# Function to set flow rules for path 2 (alternate path: s0->s2->s9->s8->s7->s6)
setup_alternate_flows() {
    echo "Changing to alternate flow rules at $CHANGE_TIME seconds..."
    
    # Clear old flows
    sudo ovs-ofctl del-flows s0
    sudo ovs-ofctl del-flows s1
    sudo ovs-ofctl del-flows s10
    sudo ovs-ofctl del-flows s7
    
    # s0 (New York) - send to s2 (Washington DC) out port 3
    sudo ovs-ofctl add-flow s0 "priority=100,in_port=1,dl_dst=$MAC2,actions=output:3"
    
    # s2 (Washington DC) - receive from s0, send to s9 (Atlanta)
    sudo ovs-ofctl add-flow s2 "priority=100,in_port=1,dl_dst=$MAC2,actions=output:2"
    
    # s9 (Atlanta) - receive from s2, send to s8 (Houston)
    sudo ovs-ofctl add-flow s9 "priority=100,in_port=2,dl_dst=$MAC2,actions=output:3"
    
    # s8 (Houston) - receive from s9, send to s7 (Kansas City)
    sudo ovs-ofctl add-flow s8 "priority=100,in_port=3,dl_dst=$MAC2,actions=output:2"
    
    # s7 (Kansas City) - receive from s8, send to s6 (Denver)
    sudo ovs-ofctl add-flow s7 "priority=100,in_port=4,dl_dst=$MAC2,actions=output:2"
    
    # s6 rules remain the same
    
    # Reverse path
    sudo ovs-ofctl add-flow s7 "priority=100,in_port=2,dl_dst=$MAC1,actions=output:4"
    sudo ovs-ofctl add-flow s8 "priority=100,in_port=2,dl_dst=$MAC1,actions=output:3"
    sudo ovs-ofctl add-flow s9 "priority=100,in_port=3,dl_dst=$MAC1,actions=output:2"
    sudo ovs-ofctl add-flow s2 "priority=100,in_port=2,dl_dst=$MAC1,actions=output:1"
    sudo ovs-ofctl add-flow s0 "priority=100,in_port=3,dl_dst=$MAC1,actions=output:1"
}

# Function to start ITGRecv on receiver host
start_receiver() {
    echo "Starting ITGRecv on $HOST2..."
    docker exec -it $HOST2 ITGRecv -p $ITG_RECV_PORT > $LOG_DIR/receiver.log 2>&1 &
    RECV_PID=$!
    sleep 2  # Give it time to start
}

# Function to start ITGSend on sender host
start_sender() {
    echo "Starting ITGSend on $HOST1..."
    docker exec -it $HOST1 ITGSend -a $HOST2 -T UDP -t ${DURATION}000 -l $LOG_DIR/sender.log -x $LOG_DIR/receiver.log -p $ITG_RECV_PORT &
    SEND_PID=$!
}

# Function to parse and display results
show_results() {
    echo -e "\nTest completed. Analyzing results..."
    
    # Parse D-ITG logs
    docker exec -it $HOST1 ITGDec $LOG_DIR/sender.log > $LOG_DIR/parsed_results.txt
    
    # Extract metrics
    LATENCY=$(grep "Average delay" $LOG_DIR/parsed_results.txt | awk '{print $3}')
    PACKET_LOSS=$(grep "Average loss" $LOG_DIR/parsed_results.txt | awk '{print $3}')
    OUT_OF_ORDER=$(grep "Out of order" $LOG_DIR/parsed_results.txt | awk '{print $4}')
    
    echo -e "\nResults:"
    echo "Average Latency: $LATENCY ms"
    echo "Packet Loss: $PACKET_LOSS %"
    echo "Out-of-order Packets: $OUT_OF_ORDER"
    
    # Save raw data
    echo -e "\nRaw results saved to $LOG_DIR/parsed_results.txt"
}

# Main execution
cleanup() {
    echo "Cleaning up..."
    kill $RECV_PID 2>/dev/null
    kill $SEND_PID 2>/dev/null
    sudo ovs-ofctl del-flows s0
    sudo ovs-ofctl del-flows s1
    sudo ovs-ofctl del-flows s2
    sudo ovs-ofctl del-flows s6
    sudo ovs-ofctl del-flows s7
    sudo ovs-ofctl del-flows s8
    sudo ovs-ofctl del-flows s9
    sudo ovs-ofctl del-flows s10
}

trap cleanup EXIT

# Set initial flows
setup_initial_flows

# Start receiver and sender
start_receiver
start_sender

# Schedule flow change
(
    sleep $CHANGE_TIME
    setup_alternate_flows
) &

# Wait for test to complete
echo "Test running for $DURATION seconds..."
sleep $DURATION

# Get results
show_results
