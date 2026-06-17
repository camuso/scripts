# Intel CMT/CAT (RDT) Test Scripts

Test harnesses for Intel Resource Director Technology (RDT), including
Cache Monitoring Technology (CMT) and Cache Allocation Technology (CAT).

## Required CPU Flags

Your processor must advertise the following flags (check with
`grep -E 'cat_l3|cdp_l3|cqm_llc|cqm_occup_llc|cqm_mbm_total|cqm_mbm_local|mba' /proc/cpuinfo`):

| Flag | Feature |
|------|---------|
| `cat_l3` | L3 Cache Allocation Technology |
| `cdp_l3` | L3 Code/Data Prioritization |
| `cqm_llc` | LLC Cache Quality Monitoring |
| `cqm_occup_llc` | LLC Occupancy Monitoring |
| `cqm_mbm_total` | Total Memory Bandwidth Monitoring |
| `cqm_mbm_local` | Local Memory Bandwidth Monitoring |
| `mba` | Memory Bandwidth Allocation |

At minimum, `cat_l3` and `cqm_llc` are required. MBA tests additionally
require `mba`.

## Prerequisites

- **intel-cmt-cat** package installed (`pqos` utility must be in `$PATH`)
- One of:
  - The kernel `resctrl` filesystem mounted at `/sys/fs/resctrl`, **or**
  - The `msr` kernel module loaded with readable `/dev/cpu/*/msr` devices
- Workload tools as needed: `cyclictest`, `stress-ng`, `fio`, `iperf3`
- Root privileges (required by `pqos` and `taskset -p 99`)

## Scripts

### intelrdt-test

Self-contained single-run test. Detects the available RDT interface
(resctrl or MSR), configures a Class of Service (COS), runs a benchmark,
monitors LLC and memory bandwidth, then resets.

```
sudo ./intelrdt-test
```

No arguments needed. Edit the variables at the top of the script to change
cores, COS mask, or benchmark command.

### intel-cmt-cat-test-harness

Iterates over multiple COS bitmasks with a chosen workload. Supports
CSV-driven test matrices and optional metric extraction into a summary file.

```
sudo ./intel-cmt-cat-test-harness --workload=cyclictest --summary
sudo ./intel-cmt-cat-test-harness --csv=testplan.csv --summary
```

| Option | Description |
|--------|-------------|
| `--workload=TYPE` | One of: `cyclictest`, `stress-ng`, `fio`, `iperf3` |
| `--csv=FILE` | CSV file with rows of `workload,cores,mask` |
| `--summary` | Append extracted metrics to `summary.csv` |

Logs are written to the `rdt_logs/` directory.

### intel-cc-test

Extended variant of the test harness with the same interface as
`intel-cmt-cat-test-harness`. Includes additional boilerplate for usage
display and signal handling.

```
sudo ./intel-cc-test --workload=stress-ng --summary
```

## CSV Test Plan Format

Create a file (e.g. `testplan.csv`) with one test per line:

```
cyclictest,0,0x0f
stress-ng,1,0xf0
fio,2,0x33
iperf3,0,0xcc
```

Fields: `workload,core,cos_mask`

## Interpreting Results

When `--summary` is used, results are appended to `summary.csv` with columns:

```
workload,core,mask,metric_value
```

The metric extracted depends on the workload:

- **cyclictest** — minimum latency (µs)
- **fio** — IOPS
- **iperf3** — sender throughput
- **stress-ng** — success confirmation
