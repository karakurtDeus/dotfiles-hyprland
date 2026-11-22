import json
from pathlib import Path
import shutil
import subprocess
import sys
import time


def read(path):
    try:
        return Path(path).read_text()
    except OSError:
        return ""


def probe(command, timeout):
    try:
        return subprocess.run(
            command, capture_output=True, text=True, timeout=timeout, check=True
        ).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def find_media(directory):
    try:
        files = [entry for entry in Path(directory).iterdir()
                 if entry.is_file() and not entry.name.startswith(".")]
    except OSError:
        return {}

    def order(path):
        stem = path.stem.casefold()
        priority = 0 if stem == "main" else 1 if stem.endswith("_main") else 2
        return priority, path.name.casefold()

    for path in sorted(files, key=order):
        mime = probe(["file", "--brief", "--mime-type", "--", str(path)], 2)
        if mime == "image/gif":
            kind = "animated"
        elif mime.startswith("image/"):
            kind = "image"
        elif mime.startswith("video/") or probe([
            "ffprobe", "-v", "error", "-select_streams", "v:0",
            "-show_entries", "stream=codec_type", "-of",
            "default=noprint_wrappers=1:nokey=1", str(path),
        ], 2) == "video":
            kind = "video"
        else:
            continue

        try:
            return {"url": path.as_uri(), "kind": kind, "modified": path.stat().st_mtime_ns}
        except OSError:
            continue
    return {}


def cpu_times():
    fields = read("/proc/stat").splitlines()
    if not fields:
        return 0, 0
    values = list(map(int, fields[0].split()[1:9]))
    return sum(values), sum(values[3:5])


def memory_percent():
    sizes = {}
    for line in read("/proc/meminfo").splitlines():
        key, _, value = line.partition(":")
        if key in {"MemTotal", "MemAvailable"}:
            sizes[key] = int(value.split()[0])
    total = sizes.get("MemTotal", 0)
    available = sizes.get("MemAvailable")
    return round(100 * (total - available) / total) if total and available is not None else None


def network_counters():
    interfaces = set()
    for line in read("/proc/net/route").splitlines()[1:]:
        fields = line.split()
        if len(fields) >= 4 and fields[1] == "00000000" and int(fields[3], 16) & 1:
            interfaces.add(fields[0])
    result = {}
    for line in read("/proc/net/dev").splitlines()[2:]:
        name, _, data = line.partition(":")
        name = name.strip()
        if name == "lo" or (interfaces and name not in interfaces):
            continue
        fields = data.split()
        if len(fields) >= 9:
            result[name] = int(fields[0]), int(fields[8])
    return result


def gpu_percent(nvidia_smi):
    values = []
    if nvidia_smi:
        report = probe([nvidia_smi, "--query-gpu=utilization.gpu",
                        "--format=csv,noheader,nounits"], 0.8)
        values.extend(int(line) for line in report.splitlines() if line.strip().isdigit())
    for device in Path("/sys/class/drm").glob("card*/device/gpu_busy_percent"):
        value = read(device).strip()
        if value.isdigit():
            values.append(int(value))
    return max(values, default=None)


def battery_percent():
    values = []
    for supply in Path("/sys/class/power_supply").glob("*"):
        if read(supply / "type").strip() != "Battery" or read(supply / "scope").strip() == "Device":
            continue
        capacity = read(supply / "capacity").strip()
        if capacity.isdigit():
            values.append(int(capacity))
    return round(sum(values) / len(values)) if values else None


def stream_stats():
    nvidia_smi = shutil.which("nvidia-smi")
    previous_time = time.monotonic()
    previous_cpu = cpu_times()
    previous_network = network_counters()
    gpu = None
    next_gpu = 0
    while True:
        now = time.monotonic()
        elapsed = now - previous_time
        total, idle = cpu_times()
        total_delta = total - previous_cpu[0]
        idle_delta = idle - previous_cpu[1]
        cpu = round(100 * (total_delta - idle_delta) / total_delta) if total_delta > 0 else None
        network = network_counters()
        download = upload = 0
        for name, (received, sent) in network.items():
            old_received, old_sent = previous_network.get(name, (received, sent))
            download += max(0, received - old_received)
            upload += max(0, sent - old_sent)
        if now >= next_gpu:
            gpu = gpu_percent(nvidia_smi)
            next_gpu = now + 3
        uptime = read("/proc/uptime").split()
        print(json.dumps({
            "uptime": int(float(uptime[0])) if uptime else None,
            "cpu": cpu,
            "memory": memory_percent(),
            "gpu": gpu,
            "download": round(download / elapsed) if elapsed > 0 else 0,
            "upload": round(upload / elapsed) if elapsed > 0 else 0,
            "battery": battery_percent(),
        }), flush=True)
        previous_time, previous_cpu, previous_network = now, (total, idle), network
        time.sleep(max(0, 1 - (time.monotonic() - now)))


if __name__ == "__main__":
    if sys.argv[1] == "media":
        print(json.dumps(find_media(sys.argv[2])))
    elif sys.argv[1] == "stats":
        try:
            stream_stats()
        except BrokenPipeError:
            pass
    else:
        sys.exit(2)
