#!/bin/bash
set -euo pipefail

# =================================================================
# 🚀 ZVPS - Ultra-Clean VM Manager (v2.1)
# =================================================================
# Improvements:
# 1. Fixed QEMU 'aio=native' error (added cache.direct=on)
# 2. Updated deprecated -no-hpet to -machine hpet=off
# 3. New minimalist, clean ASCII header
# 4. Global variable cleanup
# =================================================================

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# =============================
# 🎨 New Clean Header
# =============================
display_header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "  ███████╗██╗   ██╗██████╗ ███████╗"
    echo "  ╚══███╔╝██║   ██║██╔══██╗██╔════╝"
    echo "    ███╔╝ ██║   ██║██████╔╝███████╗"
    echo "   ███╔╝  ╚██╗ ██╔╝██╔═══╝ ╚════██║"
    echo "  ███████╗ ╚████╔╝ ██║     ███████║"
    echo "  ╚══════╝  ╚═══╝  ╚═╝     ╚══════╝"
    echo -e "  ${WHITE}Lightning-Fast Virtualization${NC}"
    echo -e "  ${BLUE}──────────────────────────────────────${NC}"
    echo
}

print_status() {
    local type=$1
    local message=$2
    case $type in
        "INFO") echo -e "${BLUE}info${NC}  $message" ;;
        "WARN") echo -e "${YELLOW}warn${NC}  $message" ;;
        "ERROR") echo -e "${RED}err ${NC}  $message" ;;
        "SUCCESS") echo -e "${GREEN}ok  ${NC}  $message" ;;
        "INPUT") echo -ne "${CYAN}task${NC}  $message" ;;
        "ROCKET") echo -e "${YELLOW}exec${NC}  $message" ;;
        *) echo "[$type] $message" ;;
    esac
}

# =============================
# 🔍 Utilities
# =============================
validate_input() {
    local type=$1
    local value=$2
    case $type in
        "number") [[ "$value" =~ ^[0-9]+$ ]] || return 1 ;;
        "size") [[ "$value" =~ ^[0-9]+[GgMm]$ ]] || return 1 ;;
        "port") [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge 22 ] && [ "$value" -le 65535 ] || return 1 ;;
        "name") [[ "$value" =~ ^[a-zA-Z0-9_-]+$ ]] || return 1 ;;
    esac
    return 0
}

check_dependencies() {
    local deps=("qemu-system-x86_64" "wget" "cloud-localds" "qemu-img")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            print_status "ERROR" "Missing $dep. Install: sudo apt install qemu-system cloud-image-utils wget"
            exit 1
        fi
    done
}

cleanup() {
    rm -f user-data meta-data 2>/dev/null
}

get_vm_list() {
    find "$VM_DIR" -name "*.conf" -exec basename {} .conf \; 2>/dev/null | sort
}

load_vm_config() {
    local config_file="$VM_DIR/$1.conf"
    if [[ -f "$config_file" ]]; then
        source "$config_file"
        return 0
    fi
    return 1
}

save_vm_config() {
    cat > "$VM_DIR/$VM_NAME.conf" <<EOF
VM_NAME="$VM_NAME"
OS_TYPE="$OS_TYPE"
IMG_URL="$IMG_URL"
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
DISK_SIZE="$DISK_SIZE"
MEMORY="$MEMORY"
CPUS="$CPUS"
SSH_PORT="$SSH_PORT"
GUI_MODE="${GUI_MODE:-false}"
PORT_FORWARDS="$PORT_FORWARDS"
IMG_FILE="$IMG_FILE"
SEED_FILE="$SEED_FILE"
CREATED="$(date)"
EOF
}

# =============================
# 📦 Core Actions
# =============================
setup_vm_image() {
    print_status "INFO" "Preparing image..."
    mkdir -p "$VM_DIR"
    
    [[ ! -f "$IMG_FILE" ]] && {
        wget -q --show-progress "$IMG_URL" -O "$IMG_FILE"
    }

    qemu-img resize "$IMG_FILE" "$DISK_SIZE" &>/dev/null

    cat > user-data <<EOF
#cloud-config
hostname: $HOSTNAME
ssh_pwauth: true
users:
  - name: $USERNAME
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    password: $(openssl passwd -6 "$PASSWORD")
chpasswd: { list: "root:$PASSWORD\n$USERNAME:$PASSWORD", expire: false }
EOF
    echo "instance-id: $VM_NAME" > meta-data
    cloud-localds "$SEED_FILE" user-data meta-data &>/dev/null
}

start_vm() {
    if load_vm_config "$1"; then
        print_status "ROCKET" "Booting $1..."
        echo -e "${WHITE}SSH: ssh -p $SSH_PORT $USERNAME@localhost | Pass: $PASSWORD${NC}\n"

        # FIX: cache.direct=on added for aio=native
        # FIX: -machine hpet=off used instead of deprecated -no-hpet
        local qemu_cmd=(
            qemu-system-x86_64
            -enable-kvm
            -m "$MEMORY"
            -smp "$CPUS"
            -cpu host
            -machine type=q35,accel=kvm,hpet=off
            -drive "file=$IMG_FILE,format=qcow2,if=virtio,cache=writeback,cache.direct=on,aio=native"
            -drive "file=$SEED_FILE,format=raw,if=virtio,readonly=on"
            -netdev "user,id=net0,hostfwd=tcp::$SSH_PORT-:22"
            -device virtio-net-pci,netdev=net0
        )

        [[ "$GUI_MODE" == "true" ]] && qemu_cmd+=(-vga virtio -display gtk) || qemu_cmd+=(-nographic)

        "${qemu_cmd[@]}"
    fi
}

# =============================
# 📋 Simple Interface
# =============================
create_new_vm() {
    print_status "INFO" "OS: 1) Ubuntu 24.04  2) Debian 12"
    read -p "Selection: " os_sel
    case $os_sel in
        1) OS_TYPE="Ubuntu"; IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img";;
        *) OS_TYPE="Debian"; IMG_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2";;
    esac

    read -p "VM Name: " VM_NAME
    read -p "User: " USERNAME
    read -s -p "Pass: " PASSWORD; echo
    read -p "RAM (MB): " MEMORY
    read -p "Port: " SSH_PORT
    
    DISK_SIZE="20G"
    CPUS="2"
    HOSTNAME="$VM_NAME"
    IMG_FILE="$VM_DIR/$VM_NAME.img"
    SEED_FILE="$VM_DIR/$VM_NAME-seed.iso"

    setup_vm_image
    save_vm_config
}

main_menu() {
    while true; do
        display_header
        vms=($(get_vm_list))
        for i in "${!vms[@]}"; do
            echo -e "  $((i+1))) ${GREEN}●${NC} ${vms[$i]}"
        done
        echo -e "\n  [n] New VM  [s] Start VM  [d] Delete  [q] Quit"
        read -p "> " cmd
        case $cmd in
            n) create_new_vm ;;
            s) read -p "VM Index: " idx; start_vm "${vms[$((idx-1))]}" ;;
            d) read -p "VM Index: " idx; rm -f "$VM_DIR/${vms[$((idx-1))]}"* ; print_status "SUCCESS" "Deleted" ;;
            q) exit 0 ;;
        esac
    done
}

# Init
trap cleanup EXIT
check_dependencies
VM_DIR="$HOME/zvps-vms"
mkdir -p "$VM_DIR"
main_menu
