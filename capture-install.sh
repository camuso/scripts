#!/bin/bash
# capture-install.sh - Install capture-shutdown and capture-boot scripts and services

# Script-level variable declarations
declare script_dir=""
declare install_prefix="/usr/local"
declare systemd_dir="/etc/systemd/system"
declare log_dir="/var/log/shutdown-traces"
declare -i errors=0

declare usagestr="$(
cat <<EOF
$(basename "$0") [-h|--help] [--uninstall] [--status]

Install capture-shutdown and capture-boot scripts and services.

This script installs:
- capture-shutdown: Captures dmesg during shutdown
- capture-boot: Captures dmesg immediately on boot (before it's cleared)
- Systemd service files for both scripts

Options:
  -h, --help     Show this help message
  --uninstall    Uninstall scripts and services
  --status       Show service status

EOF
)"

#** usage: print usage information
#*
usage() {
	echo -e "$usagestr"
}

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

#** error: print error message and exit
#*
# Arguments
#   $1 - error message
#*
error() {
	local msg="$1"
	echo -e "\033[0;31mERROR:\033[0m $msg" >&2
	exitme 1
}

#** info: print info message
#*
# Arguments
#   $1 - info message
#*
info() {
	local msg="$1"
	echo -e "\033[0;32mINFO:\033[0m $msg"
}

#** warn: print warning message
#*
# Arguments
#   $1 - warning message
#*
warn() {
	local msg="$1"
	echo -e "\033[1;33mWARN:\033[0m $msg"
}

#** check_root: verify script is run as root
#*
check_root() {
	if [[ $EUID -ne 0 ]]; then
		error "This script must be run as root (use sudo)"
	fi
}

#** install_scripts: install capture scripts to /usr/local/bin
#*
install_scripts() {
	info "Installing scripts to ${install_prefix}/bin..."
	
	# Copy scripts (try new names first, fall back to old names for compatibility)
	if [[ -f "${script_dir}/capture-shutdown" ]]; then
		cp "${script_dir}/capture-shutdown" "${install_prefix}/bin/" || \
			error "Failed to copy capture-shutdown"
		chmod +x "${install_prefix}/bin/capture-shutdown" || \
			error "Failed to make capture-shutdown executable"
	elif [[ -f "${script_dir}/shutdown-capture" ]]; then
		cp "${script_dir}/shutdown-capture" "${install_prefix}/bin/capture-shutdown" || \
			error "Failed to copy shutdown-capture"
		chmod +x "${install_prefix}/bin/capture-shutdown" || \
			error "Failed to make capture-shutdown executable"
	else
		error "capture-shutdown script not found"
	fi
	
	if [[ -f "${script_dir}/capture-boot" ]]; then
		cp "${script_dir}/capture-boot" "${install_prefix}/bin/" || \
			error "Failed to copy capture-boot"
		chmod +x "${install_prefix}/bin/capture-boot" || \
			error "Failed to make capture-boot executable"
	elif [[ -f "${script_dir}/boot-capture" ]]; then
		cp "${script_dir}/boot-capture" "${install_prefix}/bin/capture-boot" || \
			error "Failed to copy boot-capture"
		chmod +x "${install_prefix}/bin/capture-boot" || \
			error "Failed to make capture-boot executable"
	else
		error "capture-boot script not found"
	fi
	
	info "Scripts installed successfully"
}

#** install_services: install systemd service files
#*
install_services() {
	info "Installing systemd service files..."
	
	# Copy service files (try new names first, fall back to old names for compatibility)
	if [[ -f "${script_dir}/capture-shutdown.service" ]]; then
		cp "${script_dir}/capture-shutdown.service" "${systemd_dir}/" || \
			error "Failed to copy capture-shutdown.service"
	elif [[ -f "${script_dir}/shutdown-capture.service" ]]; then
		cp "${script_dir}/shutdown-capture.service" "${systemd_dir}/capture-shutdown.service" || \
			error "Failed to copy shutdown-capture.service"
	else
		error "capture-shutdown.service not found"
	fi
	
	if [[ -f "${script_dir}/capture-boot.service" ]]; then
		cp "${script_dir}/capture-boot.service" "${systemd_dir}/" || \
			error "Failed to copy capture-boot.service"
	elif [[ -f "${script_dir}/boot-capture.service" ]]; then
		cp "${script_dir}/boot-capture.service" "${systemd_dir}/capture-boot.service" || \
			error "Failed to copy boot-capture.service"
	else
		error "capture-boot.service not found"
	fi
	
	info "Service files installed successfully"
}

#** create_log_directory: create log directory for traces
#*
create_log_directory() {
	info "Creating log directory ${log_dir}..."
	
	if [[ ! -d "${log_dir}" ]]; then
		mkdir -p "${log_dir}" || error "Failed to create log directory"
		chmod 755 "${log_dir}" || error "Failed to set permissions on log directory"
		info "Log directory created"
	else
		info "Log directory already exists"
	fi
}

#** enable_services: enable and start systemd services
#*
enable_services() {
	info "Enabling and starting services..."
	
	# Reload systemd
	systemctl daemon-reload || error "Failed to reload systemd"
	
	# Enable services
	systemctl enable capture-shutdown.service || \
		warn "Failed to enable capture-shutdown.service (may already be enabled)"
	systemctl enable capture-boot.service || \
		warn "Failed to enable capture-boot.service (may already be enabled)"
	
	# Start capture-boot (capture-shutdown will run automatically during shutdown)
	systemctl start capture-boot.service || \
		warn "Failed to start capture-boot.service"
	
	info "Services enabled and started"
}

#** verify_installation: verify installation was successful
#*
verify_installation() {
	info "Verifying installation..."
	
	local -i errors=0
	
	# Check scripts exist and are executable
	if [[ ! -x "${install_prefix}/bin/capture-shutdown" ]]; then
		error "capture-shutdown script not found or not executable"
		errors=$((errors + 1))
	fi
	
	if [[ ! -x "${install_prefix}/bin/capture-boot" ]]; then
		error "capture-boot script not found or not executable"
		errors=$((errors + 1))
	fi
	
	# Check service files exist
	if [[ ! -f "${systemd_dir}/capture-shutdown.service" ]]; then
		error "capture-shutdown.service not found"
		errors=$((errors + 1))
	fi
	
	if [[ ! -f "${systemd_dir}/capture-boot.service" ]]; then
		error "capture-boot.service not found"
		errors=$((errors + 1))
	fi
	
	# Check services are enabled
	if ! systemctl is-enabled capture-shutdown.service >/dev/null 2>&1; then
		warn "capture-shutdown.service is not enabled"
	fi
	
	if ! systemctl is-enabled capture-boot.service >/dev/null 2>&1; then
		warn "capture-boot.service is not enabled"
	fi
	
	if [[ $errors -eq 0 ]]; then
		info "Installation verified successfully"
		return 0
	else
		error "Installation verification failed with $errors errors"
	fi
}

#** uninstall: uninstall scripts and services
#*
uninstall() {
	info "Uninstalling capture-shutdown and capture-boot..."
	
	# Stop and disable services (try both old and new names for compatibility)
	systemctl stop capture-boot.service boot-capture.service 2>/dev/null || true
	systemctl disable capture-shutdown.service shutdown-capture.service 2>/dev/null || true
	systemctl disable capture-boot.service boot-capture.service 2>/dev/null || true
	
	# Remove service files (try both old and new names)
	rm -f "${systemd_dir}/capture-shutdown.service"
	rm -f "${systemd_dir}/shutdown-capture.service"
	rm -f "${systemd_dir}/capture-boot.service"
	rm -f "${systemd_dir}/boot-capture.service"
	
	# Remove scripts (try both old and new names)
	rm -f "${install_prefix}/bin/capture-shutdown"
	rm -f "${install_prefix}/bin/shutdown-capture"
	rm -f "${install_prefix}/bin/capture-boot"
	rm -f "${install_prefix}/bin/boot-capture"
	
	# Reload systemd
	systemctl daemon-reload 2>/dev/null || true
	
	info "Uninstallation complete"
	warn "Log directory ${log_dir} was not removed (preserving existing logs)"
	info "To remove logs manually: sudo rm -rf ${log_dir}"
}

#** show_status: show status of systemd services
#*
show_status() {
	info "Service status:"
	echo ""
	systemctl status capture-shutdown.service --no-pager -l || true
	echo ""
	systemctl status capture-boot.service --no-pager -l || true
}

#** main
#*
main() {
	# Trap for control-c
	trap control_c SIGINT

	# Initialize script directory
	script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	
	# Parse arguments
	if [[ "${1:-}" == "--uninstall" ]]; then
		check_root
		uninstall
		exitme 0
	fi
	
	if [[ "${1:-}" == "--status" ]]; then
		check_root
		show_status
		exitme 0
	fi
	
	if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "help" ]]; then
		usage
		exitme 0
	fi
	
	check_root
	
	info "Installing capture-shutdown and capture-boot..."
	echo ""
	
	install_scripts
	install_services
	create_log_directory
	enable_services
	
	echo ""
	info "Installation complete!"
	echo ""
	info "Installed files:"
	echo "  Scripts: ${install_prefix}/bin/capture-shutdown"
	echo "           ${install_prefix}/bin/capture-boot"
	echo "  Services: ${systemd_dir}/capture-shutdown.service"
	echo "            ${systemd_dir}/capture-boot.service"
	echo "  Log directory: ${log_dir}"
	echo ""
	info "To check service status, run:"
	echo "  sudo systemctl status capture-shutdown.service"
	echo "  sudo systemctl status capture-boot.service"
	echo ""
	info "To view logs:"
	echo "  sudo journalctl -u capture-shutdown.service"
	echo "  sudo journalctl -u capture-boot.service"
	echo ""
	info "To uninstall, run:"
	echo "  sudo $0 --uninstall"
	echo ""
	
	verify_installation
}

main "$@"
