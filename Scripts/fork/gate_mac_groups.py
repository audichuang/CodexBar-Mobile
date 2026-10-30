#!/usr/bin/env python3
"""Run the Mac test suite through the upstream grouped runner without stopping at the first failing group.

Plain `swift test` is not usable on the gate machines (JS plugin timeouts, fatal errors that only
appear in one process), so the gate uses Scripts/ci_swift_test_by_suite.py's discovery, grouping and
per-group isolation, but keeps going after a failing group so every failure reaches the baseline diff.

Usage: gate_mac_groups.py <swift-command> [group-size] [timeout-seconds]
The swift command must take `test ...` as its arguments and use an absolute scratch path (the runner
changes HOME for each group). Output markers read by gate_lib.sh: `::group::Swift test group i/K`,
`GROUPRESULT i rc` and the final `BADGROUPS [..]`. Exit 1 when any group still fails after one retry.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import ci_swift_test_by_suite as runner  # noqa: E402


def main() -> int:
    command = [sys.argv[1]]
    group_size = int(sys.argv[2]) if len(sys.argv) > 2 else 12
    timeout = int(sys.argv[3]) if len(sys.argv) > 3 else 180
    suites = runner.prioritized_suites(runner.swift_test_list(command))
    groups = list(runner.test_groups(suites, group_size))
    print(f"Discovered {len(suites)} test selections in {len(groups)} groups", flush=True)
    bad = []
    for index, group in enumerate(groups, 1):
        print(f"::group::Swift test group {index}/{len(groups)}", flush=True)
        code = runner.run_group(group, timeout, command)
        if code != 0:
            print(f"Group {index} failed with exit code {code}; retrying group once", flush=True)
            code = runner.run_group(group, timeout, command)
        # Leave a line gate_lib.sh's CRASH_MARKER_RE matches, so a killed group cannot hide behind another group's known failure.
        if code < 0:
            print(f"Exited with unexpected signal code {-code} (group {index})", flush=True)
        elif code == 124:
            print(f"::warning::Command timed out after {timeout}s (group {index})", flush=True)
        print(f"GROUPRESULT {index} {code}", flush=True)
        if code != 0:
            bad.append(index)
    print("BADGROUPS", bad, flush=True)
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
