# Bash Script Coding Standards

These standards apply to all bash scripts created in this repository.

## Indentation

- Use full tab stops for indentation
- Do not mix tabs and spaces

## Variable Declarations

### Script-Level Variables

- Variables local to the script are declared in **lowercase**
- Declare script-level variables at the **top of the script** using `declare` with appropriate type
- Use type declarations when appropriate:
  - `declare -i` for integers
  - `declare -a` for arrays
  - `declare -r` for read-only constants
  - `declare` (no flag) for strings

Example:
```bash
declare shutdown_log_dir="/var/log/shutdown-traces"
declare -i max_traces=10
declare -a file_list=()
```

### Function-Level Variables

- Variables local to functions are declared with the `local` keyword
- Include type declarations when appropriate:
  - `local -i` for integers
  - `local -a` for arrays
  - `local` (no flag) for strings

Example:
```bash
some_function() {
	local -i count=0
	local filename=""
	local -a items=()
	# ...
}
```

## Script Structure

### Modular Design

- Scripts must be completely modular with a `main()` function
- The `main()` function is invoked by `main "$@"` at the bottom of the file
- All logic should be organized into functions

Example structure:
```bash
#!/bin/bash

# Variable declarations at top
declare some_var="value"
declare -i some_int=0

# Function definitions
function1() {
	# ...
}

function2() {
	# ...
}

#** main
#*
main() {
	# Main logic here
}

main "$@"
```

### Control-C Handling

- Control-C should be trapped and mapped to an `exitme()` function
- The trap is set in the `main()` function: `trap control_c SIGINT`
- Implement a `control_c()` function that calls `exitme()`

Example:
```bash
#** control_c: control-c trap
#*
control_c() {
	echo -e "\nCtrl-c detected\nCleaning up and exiting."
	exitme 1
}

#** exitme: exit with code and optional message
#*
# Arguments
#   $1 - exit code
#   $2 - optional message
#*
exitme() {
	local -i code="$1"
	local msg="$2"

	((code == 0)) && exit "$code"
	[[ -n "$msg" ]] && echo -e "$msg" >&2
	usage
	exit "$code"
}

main() {
	trap control_c SIGINT
	# ...
}
```

### Usage Function

- There must be a `usage()` function with a here document statement
- The here document should describe the script and all its options
- Store the usage text in a variable declared at the top: `declare usagestr="$(...)"`
- Usage should be invoked when user types: `help`, `--help`, or `-h`

Example:
```bash
declare usagestr="$(
cat <<EOF
$(basename "$0") [-h|--help] [OPTIONS]

Description of what the script does.

Options:
  -h, --help     Show this help message
  -o, --option   Description of option

EOF
)"

#** usage: print usage information
#*
usage() {
	echo -e "$usagestr"
}

main() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
			-h|--help|help)
				usage
				exit 0
				;;
			# ...
		esac
	done
}
```

## Function Documentation

- Use comment blocks to document functions
- Format: `#** function_name: brief description`
- Include argument descriptions if applicable

Example:
```bash
#** capture_traces: Capture dmesg and kernel messages
#*
# Arguments
#   $1 - log directory path
#   $2 - maximum number of traces
#*
capture_traces() {
	local log_dir="$1"
	local -i max_traces="$2"
	# ...
}
```

## Summary Checklist

When creating a new bash script, ensure:

- [ ] Full tab stops for indentation
- [ ] Script-level variables declared at top with `declare` and type
- [ ] Function-level variables use `local` with type
- [ ] Script is modular with `main()` function
- [ ] `main "$@"` at bottom of file
- [ ] Control-C trap mapped to `exitme()` function
- [ ] `usage()` function with here document
- [ ] Help options: `help`, `--help`, `-h`
- [ ] Functions documented with comment blocks

