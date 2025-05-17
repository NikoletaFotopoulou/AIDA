last_time = 0.0
with open("udp_times.txt") as f:
    for line in f:
        parts = line.strip().split()
        if len(parts) < 2:
            continue
        frame_no = parts[0]
        timestamp = float(parts[1])
        if timestamp < last_time:
            print("Out-of-order detected at frame {}: {} < {}".format(frame_no, timestamp, last_time))
        last_time = timestamp
