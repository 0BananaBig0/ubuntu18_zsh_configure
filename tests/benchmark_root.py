"""Compare root discovery: python3 tests/benchmark_root.py OLD_FILE NEW_FILE."""

from pathlib import Path
import platform
import statistics
import subprocess
import sys
import tempfile
import time


def benchmark(sources):
    print(platform.platform())
    print(subprocess.check_output(["zsh", "--version"], text=True).strip())
    print("7 samples, 20 calls/sample; medians include shell launch and sourcing.")
    with tempfile.TemporaryDirectory(prefix="zinit-benchmark-") as scratch:
        root = Path(scratch)
        (root / ".root").touch()
        for depth in (5, 25, 100):
            nested = root.joinpath(*(["d"] * depth))
            nested.mkdir(parents=True, exist_ok=True)
            for source in sources:
                samples = []
                for _ in range(7):
                    start = time.perf_counter()
                    subprocess.run(
                        ["zsh", "-f", "-c",
                         'source "$1"; repeat 20 { find_root_path >/dev/null || exit 1; }',
                         "benchmark", str(source)],
                        cwd=nested, check=True, capture_output=True, timeout=30,
                    )
                    samples.append(time.perf_counter() - start)
                median = statistics.median(samples)
                print("%s depth=%d total=%.4fs per_call=%.2fms"
                      % (source, depth, median, median * 1000 / 20), flush=True)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    benchmark([Path(arg).resolve(strict=True) for arg in sys.argv[1:]])
