timestamps = []
with open("udp_times.txt") as f:
    for line in f:
        parts = line.strip().split()
        if len(parts) < 2:
            continue
        frame_no = parts[0]
        timestamp = float(parts[1])

        if timestamps and timestamp < max(timestamps):
            print("Out-of-order detected at frame", frame_no, ":", timestamp, " < ", max(timestamps))

        timestamps.append(timestamp)
