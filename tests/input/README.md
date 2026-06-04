# Input Subsystem Backport Tests

Test suite for validating kernel input subsystem backports. These scripts
exercise the input event path, module loading, uinput virtual devices,
force-feedback locking, and driver-specific behavior to catch regressions
introduced during backporting.

## Requirements

- Root privileges (all tests require `CAP_SYS_ADMIN`)
- The `uinput` kernel module (loaded automatically if available)
- A kernel build tree or installed modules matching the running kernel
- Python 3 (for the Python-based tests)

## Running

Use the orchestrator to run the full suite:

```
sudo ./run-input-tests [-k KERNEL_BUILD_DIR] [-v]
```

Options:
- `-k DIR` — Path to a kernel build tree (uses installed modules if omitted)
- `-v` — Verbose output

Output is in [TAP version 13](https://testanything.org/) format. Exit code
is 0 if all tests pass, 1 if any fail.

Individual tests can also be run standalone; each exits 0 (pass), 1 (fail),
or 77 (skip).

## Scripts

| Script | Language | Description |
|--------|----------|-------------|
| `run-input-tests` | Bash | Master orchestrator; runs all tests and emits TAP summary |
| `input-test-kunit` | Bash | Loads `input_test.ko` and checks KUnit results via debugfs |
| `input-test-modprobe` | Bash | Loads/unloads all built input modules, checks for kernel errors |
| `input-test-modstress` | Bash | Rapid load/unload cycles on modules with known race-condition fixes |
| `input-test-sysfs` | Bash | Validates sysfs attributes (name, capabilities, id, properties) for all input devices |
| `input-test-uinput` | Python | Creates virtual devices via `/dev/uinput`, injects and reads back events |
| `input-test-events` | Python | Event injection regression tests: timestamp ordering, SYN_REPORT boundaries, rapid injection |
| `input-test-ff` | Python | Force-feedback upload/play/erase with deadlock detection via SIGALRM and lockdep scanning |
| `input-test-gpiokeys` | Bash | Validates `gpio_keys` probe, sysfs presence, and dmesg for errors |

## Test Details

### input-test-kunit

Runs the in-tree KUnit test suite (`input_test.ko`). Searches for the module
in `$KERNEL_DIR/drivers/input/tests/`, a flat build directory, or the
installed module path. Ensures KUnit is loaded with `enable=1` (RHEL disables
it by default).

### input-test-modprobe

Iterates over all `.ko` files under the input driver tree. If the running
kernel version matches the build, each module is loaded and unloaded while
dmesg is monitored for BUG/OOPS/panic messages. If versions differ, it falls
back to ELF format validation.

### input-test-modstress

Targets modules with historical race-condition or use-after-free bugs:
`alps`, `appletouch`, `synaptics_i2c`, `bcm5974`. Performs 50 rapid
load/unload cycles and scans dmesg for KASAN, lockdep, or oops reports.

### input-test-sysfs

Walks `/sys/class/input/` and verifies that every input device exposes
readable `name`, `capabilities/{ev,key,rel,abs}`, `id/{bustype,vendor,
product,version}`, and `properties` attributes. Also checks that event nodes
have well-formed `major:minor` device numbers.

### input-test-uinput

Creates virtual keyboard and mouse devices through `/dev/uinput`, injects
key presses and relative motion, reads them back via evdev, and verifies
values match. Also confirms device visibility in `/proc/bus/input/devices`
and cleanup after destroy. Includes an atkbd scancode boundary check when
AT keyboard hardware is present.

### input-test-events

Exercises the kernel event delivery path: verifies monotonic timestamp
ordering, correct SYN_REPORT packet boundaries, preserved event ordering,
and no event loss under rapid injection (20 packets / 60 events).

### input-test-ff

Tests the force-feedback upload/play/stop/erase path through uinput. A
background thread services FF requests while the foreground performs upload
cycles. A 30-second SIGALRM catches deadlocks from circular locking between
`ff-core` and `uinput`. After the test, dmesg is scanned for lockdep
warnings.

### input-test-gpiokeys

Checks whether `gpio_keys` probed successfully by looking for a matching
input device in sysfs or a bound platform device. Verifies event capabilities
and accessible event nodes. Skips cleanly when no gpio-keys hardware is
present.

## Exit Code Convention

All scripts follow the same convention:

| Code | Meaning |
|------|---------|
| 0 | Pass |
| 1 | Fail |
| 77 | Skip (missing hardware, module, or permissions) |

## Environment Variables

| Variable | Used By | Description |
|----------|---------|-------------|
| `KERNEL_DIR` | kunit, modprobe, sysfs | Path to kernel build tree |
| `INPUT_TEST_MODULE` | kunit | Explicit path to `input_test.ko` |
| `VERBOSE` | run-input-tests | Set to 1 for verbose output |
