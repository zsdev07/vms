#!/bin/bash
set -euo pipefail

# =============================
# 🚀 ZVPS - Lightning-Fast VM Manager
# =============================
# Version: 2.1
# Author: ZDEV07
# Powered by ZVPS Technology
# =============================

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# =============================
# 🎨 ASCII Header (FIXED & CLEANER)
# =============================
display_header() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║     ███████╗ ██╗   ██╗ ██████╗  ███████╗                      ║
║     ╚══███╔╝ ██║   ██║ ██╔══██╗ ██╔════╝                      ║
║       ███╔╝  ██║   ██║ ██████╔╝ ███████╗                      ║
║      ███╔╝   ╚██╗ ██╔╝ ██╔═══╝  ╚════██║                      ║
║     ███████╗  ╚████╔╝  ██║      ███████║                      ║
║     ╚══════╝   ╚═══╝   ╚═╝      ╚══════╝                      ║
║                                                                ║
║          ⚡ Lightning-Fast Virtual Machine Manager ⚡          ║
║                 🚀 Powered by ZVPS Technology 🚀              ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${WHITE}Version 2.1${NC} │ ${CYAN}High-Performance VM Management${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
}

# =============================
# 📢 Status Messages with Emojis
# =============================
print_status() {
    local type=$1
    local message=$2
    
    case $type in
        "INFO") echo -e "${BLUE}ℹ️  [INFO]${NC} $message" ;;
        "WARN") echo -e "${YELLOW}⚠️  [WARN]${NC} $message" ;;
        "ERROR") echo -e "${RED}❌ [ERROR]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}✅ [SUCCESS]${NC} $message" ;;
        "INPUT") echo -ne "${CYAN}📝 [INPUT]${NC} $message" ;;
        "PROGRESS") echo -e "${MAGENTA}⏳ [PROGRESS]${NC} $message" ;;
        "ROCKET") echo -e "${YELLOW}🚀 [STARTING]${NC} $message" ;;
        "STOP") echo -e "${RED}🛑 [STOPPING]${NC} $message" ;;
        "DELETE") echo -e "${RED}🗑️  [DELETE]${NC} $message" ;;
        "CONFIG") echo -e "${CYAN}⚙️  [CONFIG]${NC} $message" ;;
        *) echo "[$type] $message" ;;
    esac
}

# =============================
# 🔍 Input Validation
# =============================
validate_input() {
    local type=$1
    local value=$2
    
    case $type in
        "number")
            if ! [[ "$value" =~ ^[0-9]+$ ]]; then
                print_status "ERROR" "Must be a number"
                return 1
            fi
            ;;
        "size")
            if ! [[ "$value" =~ ^[0-9]+[GgMm]$ ]]; then
                print_status "ERROR" "Must be a size with unit (e.g., 100G, 512M)"
                return 1
            fi
            ;;
        "port")
            if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 23 ] || [ "$value" -gt 65535 ]; then
                print_status "ERROR" "Must be a valid port number (23-65535)"
                return 1
            fi
            ;;
        "name")
            if ! [[ "$value" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                print_status "ERROR" "VM name can only contain letters, numbers, hyphens, and underscores"
                return 1
            fi
            ;;
        "username")
            if ! [[ "$value" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
                print_status "ERROR" "Username must start with a letter or underscore"
                return 1
            fi
            ;;
    esac
    return 0
}

# =============================
# 🔧 Dependency Checker
# =============================
check_dependencies() {
    local deps=("qemu-system-x86_64" "wget" "cloud-localds" "qemu-img")
    local missing_deps=()
    
    print_status "PROGRESS" "Checking dependencies..."
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_status "ERROR" "Missing dependencies: ${missing_deps[*]}"
        print_status "INFO" "Install with: ${BOLD}sudo apt install qemu-system cloud-image-utils wget${NC}"
        exit 1
    fi
    
    print_status "SUCCESS" "All dependencies found!"
}

# =============================
# 🧹 Cleanup Function
# =============================
cleanup() {
    rm -f user-data meta-data 2>/dev/null
}

# =============================
# 📋 VM List Functions
# =============================
get_vm_list() {
    find "$VM_DIR" -name "*.conf" -exec basename {} .conf \; 2>/dev/null | sort
}

load_vm_config() {
    local vm_name=$1
    local config_file="$VM_DIR/$vm_name.conf"
    
    if [[ -f "$config_file" ]]; then
        unset VM_NAME OS_TYPE CODENAME IMG_URL HOSTNAME USERNAME PASSWORD
        unset DISK_SIZE MEMORY CPUS SSH_PORT GUI_MODE PORT_FORWARDS IMG_FILE SEED_FILE CREATED QUICK_BOOT
        
        source "$config_file"
        return 0
    else
        print_status "ERROR" "Configuration for VM '$vm_name' not found"
        return 1
    fi
}

save_vm_config() {
    local config_file="$VM_DIR/$VM_NAME.conf"
    
    cat > "$config_file" <<EOF
VM_NAME="$VM_NAME"
OS_TYPE="$OS_TYPE"
CODENAME="$CODENAME"
IMG_URL="$IMG_URL"
HOSTNAME="$HOSTNAME"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
DISK_SIZE="$DISK_SIZE"
MEMORY="$MEMORY"
CPUS="$CPUS"
SSH_PORT="$SSH_PORT"
GUI_MODE="${GUI_MODE:-false}"
QUICK_BOOT="${QUICK_BOOT:-true}"
PORT_FORWARDS="$PORT_FORWARDS"
IMG_FILE="$IMG_FILE"
SEED_FILE="$SEED_FILE"
CREATED="$CREATED"
EOF
    
    print_status "SUCCESS" "Configuration saved to $config_file"
}

# =============================
# 🆕 Create New VM
# =============================
create_new_vm() {
    print_status "CONFIG" "Creating a new VM"
    echo
    
    # OS Selection with emojis
    echo -e "${BOLD}${CYAN}🖥️  Select an Operating System:${NC}"
    echo
    local os_options=()
    local i=1
    for os in "${!OS_OPTIONS[@]}"; do
        echo -e "  ${BOLD}$i)${NC} $os"
        os_options[$i]="$os"
        ((i++))
    done
    echo
    
    while true; do
        read -p "$(print_status "INPUT" "Enter your choice (1-${#OS_OPTIONS[@]}): ")" choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#OS_OPTIONS[@]} ]; then
            local os="${os_options[$choice]}"
            IFS='|' read -r OS_TYPE CODENAME IMG_URL DEFAULT_HOSTNAME DEFAULT_USERNAME DEFAULT_PASSWORD <<< "${OS_OPTIONS[$os]}"
            break
        else
            print_status "ERROR" "Invalid selection. Try again."
        fi
    done

    echo
    print_status "CONFIG" "VM Configuration"
    echo

    # VM Name
    while true; do
        read -p "$(print_status "INPUT" "💾 VM name (default: $DEFAULT_HOSTNAME): ")" VM_NAME
        VM_NAME="${VM_NAME:-$DEFAULT_HOSTNAME}"
        if validate_input "name" "$VM_NAME"; then
            if [[ -f "$VM_DIR/$VM_NAME.conf" ]]; then
                print_status "ERROR" "VM with name '$VM_NAME' already exists"
            else
                break
            fi
        fi
    done

    # Hostname
    while true; do
        read -p "$(print_status "INPUT" "🌐 Hostname (default: $VM_NAME): ")" HOSTNAME
        HOSTNAME="${HOSTNAME:-$VM_NAME}"
        if validate_input "name" "$HOSTNAME"; then
            break
        fi
    done

    # Username
    while true; do
        read -p "$(print_status "INPUT" "👤 Username (default: $DEFAULT_USERNAME): ")" USERNAME
        USERNAME="${USERNAME:-$DEFAULT_USERNAME}"
        if validate_input "username" "$USERNAME"; then
            break
        fi
    done

    # Password
    while true; do
        read -s -p "$(print_status "INPUT" "🔐 Password (default: $DEFAULT_PASSWORD): ")" PASSWORD
        PASSWORD="${PASSWORD:-$DEFAULT_PASSWORD}"
        echo
        if [ -n "$PASSWORD" ]; then
            break
        else
            print_status "ERROR" "Password cannot be empty"
        fi
    done

    # Disk Size
    while true; do
        read -p "$(print_status "INPUT" "💿 Disk size (default: 20G): ")" DISK_SIZE
        DISK_SIZE="${DISK_SIZE:-20G}"
        if validate_input "size" "$DISK_SIZE"; then
            break
        fi
    done

    # Memory
    while true; do
        read -p "$(print_status "INPUT" "🧠 Memory in MB (default: 2048): ")" MEMORY
        MEMORY="${MEMORY:-2048}"
        if validate_input "number" "$MEMORY"; then
            break
        fi
    done

    # CPUs
    while true; do
        read -p "$(print_status "INPUT" "⚙️  CPUs (default: 2): ")" CPUS
        CPUS="${CPUS:-2}"
        if validate_input "number" "$CPUS"; then
            break
        fi
    done

    # SSH Port
    while true; do
        read -p "$(print_status "INPUT" "🔌 SSH Port (default: 2222): ")" SSH_PORT
        SSH_PORT="${SSH_PORT:-2222}"
        if validate_input "port" "$SSH_PORT"; then
            if ss -tln 2>/dev/null | grep -q ":$SSH_PORT "; then
                print_status "ERROR" "Port $SSH_PORT is already in use"
            else
                break
            fi
        fi
    done

    # GUI Mode
    while true; do
        read -p "$(print_status "INPUT" "🖥️  Enable GUI mode? (y/n, default: n): ")" gui_input
        GUI_MODE=false
        gui_input="${gui_input:-n}"
        if [[ "$gui_input" =~ ^[Yy]$ ]]; then 
            GUI_MODE=true
            break
        elif [[ "$gui_input" =~ ^[Nn]$ ]]; then
            break
        else
            print_status "ERROR" "Please answer y or n"
        fi
    done

    # Quick Boot
    while true; do
        read -p "$(print_status "INPUT" "⚡ Enable Quick Boot? (y/n, default: y): ")" qb_input
        QUICK_BOOT=true
        qb_input="${qb_input:-y}"
        if [[ "$qb_input" =~ ^[Yy]$ ]]; then 
            QUICK_BOOT=true
            break
        elif [[ "$qb_input" =~ ^[Nn]$ ]]; then
            QUICK_BOOT=false
            break
        else
            print_status "ERROR" "Please answer y or n"
        fi
    done

    # Port Forwards
    read -p "$(print_status "INPUT" "🌐 Additional port forwards (e.g., 8080:80): ")" PORT_FORWARDS

    IMG_FILE="$VM_DIR/$VM_NAME.img"
    SEED_FILE="$VM_DIR/$VM_NAME-seed.iso"
    CREATED="$(date '+%Y-%m-%d %H:%M:%S')"

    echo
    setup_vm_image
    save_vm_config
}

# =============================
# 📦 Setup VM Image
# =============================
setup_vm_image() {
    print_status "PROGRESS" "Downloading and preparing image..."
    
    mkdir -p "$VM_DIR"
    
    if [[ -f "$IMG_FILE" ]]; then
        print_status "INFO" "Image file already exists. Skipping download."
    else
        print_status "PROGRESS" "Downloading image from $IMG_URL..."
        if wget --progress=bar:force --tries=3 --timeout=30 "$IMG_URL" -O "$IMG_FILE.tmp"; then
            mv "$IMG_FILE.tmp" "$IMG_FILE"
            print_status "SUCCESS" "Image downloaded successfully"
        else
            print_status "ERROR" "Failed to download image"
            exit 1
        fi
    fi
    
    # Resize disk
    print_status "PROGRESS" "Resizing disk to $DISK_SIZE..."
    if qemu-img resize "$IMG_FILE" "$DISK_SIZE" &>/dev/null; then
        print_status "SUCCESS" "Disk resized to $DISK_SIZE"
    else
        print_status "WARN" "Creating new disk image..."
        qemu-img create -f qcow2 "$IMG_FILE" "$DISK_SIZE" &>/dev/null
    fi

    # Cloud-init configuration
    cat > user-data <<EOF
#cloud-config
hostname: $HOSTNAME
ssh_pwauth: true
disable_root: false
users:
  - name: $USERNAME
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    password: $(openssl passwd -6 "$PASSWORD" | tr -d '\n')
chpasswd:
  list: |
    root:$PASSWORD
    $USERNAME:$PASSWORD
  expire: false
package_update: false
package_upgrade: false
EOF

    cat > meta-data <<EOF
instance-id: iid-zvps-$VM_NAME
local-hostname: $HOSTNAME
EOF

    if cloud-localds "$SEED_FILE" user-data meta-data &>/dev/null; then
        print_status "SUCCESS" "Cloud-init seed created"
    else
        print_status "ERROR" "Failed to create cloud-init seed"
        exit 1
    fi
    
    print_status "SUCCESS" "VM '$VM_NAME' created successfully! 🎉"
}

# =============================
# 🚀 Start VM (FIXED - Proper QEMU flags)
# =============================
start_vm() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        print_status "ROCKET" "Starting VM: $vm_name"
        echo
        echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}SSH Connection Info${NC}              ${CYAN}║${NC}"
        echo -e "${CYAN}╠══════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}ssh -p $SSH_PORT $USERNAME@localhost${NC}"
        echo -e "${CYAN}║${NC}  Password: ${YELLOW}$PASSWORD${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
        echo
        
        if [[ ! -f "$IMG_FILE" ]]; then
            print_status "ERROR" "VM image file not found: $IMG_FILE"
            return 1
        fi
        
        if [[ ! -f "$SEED_FILE" ]]; then
            print_status "WARN" "Seed file not found, recreating..."
            setup_vm_image
        fi
        
        # Build optimized QEMU command (FIXED)
        local qemu_cmd=(
            qemu-system-x86_64
            -enable-kvm
            -m "$MEMORY"
            -smp "$CPUS"
            -cpu host
        )

        # Quick boot optimizations (FIXED FLAGS)
        if [[ "${QUICK_BOOT:-true}" == "true" ]]; then
            qemu_cmd+=(
                -machine "type=q35,accel=kvm,hpet=off"
                -boot "order=c,menu=off"
                -rtc "base=utc,driftfix=slew"
            )
        else
            qemu_cmd+=(-machine type=q35,accel=kvm)
        fi

        # Storage (FIXED - removed aio=native, using proper cache settings)
        qemu_cmd+=(
            -drive "file=$IMG_FILE,format=qcow2,if=virtio,cache=writeback"
            -drive "file=$SEED_FILE,format=raw,if=virtio,readonly=on"
        )

        # Network
        qemu_cmd+=(
            -device virtio-net-pci,netdev=net0
            -netdev "user,id=net0,hostfwd=tcp::$SSH_PORT-:22"
        )

        # Additional port forwards
        if [[ -n "$PORT_FORWARDS" ]]; then
            IFS=',' read -ra forwards <<< "$PORT_FORWARDS"
            for forward in "${forwards[@]}"; do
                IFS=':' read -r host_port guest_port <<< "$forward"
                qemu_cmd[-1]="${qemu_cmd[-1]},hostfwd=tcp::$host_port-:$guest_port"
            done
        fi

        # Display
        if [[ "$GUI_MODE" == "true" ]]; then
            qemu_cmd+=(-vga virtio -display gtk,gl=on)
        else
            qemu_cmd+=(-nographic -serial mon:stdio)
        fi

        # Performance enhancements
        qemu_cmd+=(
            -device virtio-balloon-pci
            -device virtio-rng-pci,rng=rng0
            -object rng-random,filename=/dev/urandom,id=rng0
        )

        print_status "ROCKET" "Launching QEMU..."
        echo
        
        "${qemu_cmd[@]}"
        
        echo
        print_status "INFO" "VM $vm_name has been shut down"
    fi
}

# =============================
# 🛑 Stop VM
# =============================
stop_vm() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        if pgrep -f "qemu-system-x86_64.*$IMG_FILE" >/dev/null; then
            print_status "STOP" "Stopping VM: $vm_name"
            pkill -SIGTERM -f "qemu-system-x86_64.*$IMG_FILE"
            sleep 3
            if pgrep -f "qemu-system-x86_64.*$IMG_FILE" >/dev/null; then
                print_status "WARN" "Force stopping..."
                pkill -9 -f "qemu-system-x86_64.*$IMG_FILE"
            fi
            print_status "SUCCESS" "VM $vm_name stopped"
        else
            print_status "INFO" "VM $vm_name is not running"
        fi
    fi
}

# =============================
# 🗑️  Delete VM
# =============================
delete_vm() {
    local vm_name=$1
    
    print_status "DELETE" "This will permanently delete VM '$vm_name' and all its data!"
    read -p "$(print_status "INPUT" "Type 'yes' to confirm: ")" confirm
    if [[ "$confirm" == "yes" ]]; then
        if load_vm_config "$vm_name"; then
            rm -f "$IMG_FILE" "$SEED_FILE" "$VM_DIR/$vm_name.conf"
            print_status "SUCCESS" "VM '$vm_name' has been deleted"
        fi
    else
        print_status "INFO" "Deletion cancelled"
    fi
}

# =============================
# ℹ️  Show VM Info
# =============================
show_vm_info() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        clear
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}      ${BOLD}VM INFORMATION: $vm_name${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} 🖥️  OS:           ${GREEN}$OS_TYPE${NC}"
        echo -e "${CYAN}║${NC} 🌐 Hostname:      ${GREEN}$HOSTNAME${NC}"
        echo -e "${CYAN}║${NC} 👤 Username:      ${GREEN}$USERNAME${NC}"
        echo -e "${CYAN}║${NC} 🔐 Password:      ${YELLOW}$PASSWORD${NC}"
        echo -e "${CYAN}║${NC} 🔌 SSH Port:      ${GREEN}$SSH_PORT${NC}"
        echo -e "${CYAN}║${NC} 🧠 Memory:        ${GREEN}$MEMORY MB${NC}"
        echo -e "${CYAN}║${NC} ⚙️  CPUs:          ${GREEN}$CPUS${NC}"
        echo -e "${CYAN}║${NC} 💿 Disk:          ${GREEN}$DISK_SIZE${NC}"
        echo -e "${CYAN}║${NC} 🖥️  GUI Mode:      ${GREEN}${GUI_MODE}${NC}"
        echo -e "${CYAN}║${NC} ⚡ Quick Boot:    ${GREEN}${QUICK_BOOT:-true}${NC}"
        echo -e "${CYAN}║${NC} 🌐 Port Forwards: ${GREEN}${PORT_FORWARDS:-None}${NC}"
        echo -e "${CYAN}║${NC} 📅 Created:       ${GREEN}$CREATED${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
        echo
        
        # Show running status
        if pgrep -f "qemu-system-x86_64.*$IMG_FILE" >/dev/null; then
            echo -e "${GREEN}🟢 Status: RUNNING${NC}"
        else
            echo -e "${RED}🔴 Status: STOPPED${NC}"
        fi
        
        echo
        read -p "$(print_status "INPUT" "Press Enter to continue...")"
    fi
}

# =============================
# ⚙️  Edit VM Configuration
# =============================
edit_vm_config() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        while true; do
            clear
            print_status "CONFIG" "Editing VM: $vm_name"
            echo
            echo "What would you like to edit?"
            echo
            echo -e "  ${CYAN}1)${NC} 🌐 Hostname"
            echo -e "  ${CYAN}2)${NC} 👤 Username"
            echo -e "  ${CYAN}3)${NC} 🔐 Password"
            echo -e "  ${CYAN}4)${NC} 🔌 SSH Port"
            echo -e "  ${CYAN}5)${NC} 🖥️  GUI Mode"
            echo -e "  ${CYAN}6)${NC} ⚡ Quick Boot"
            echo -e "  ${CYAN}7)${NC} 🌐 Port Forwards"
            echo -e "  ${CYAN}8)${NC} 🧠 Memory (RAM)"
            echo -e "  ${CYAN}9)${NC} ⚙️  CPU Count"
            echo -e "  ${CYAN}10)${NC} 💿 Disk Size"
            echo -e "  ${RED}0)${NC} ⬅️  Back to main menu"
            echo
            
            read -p "$(print_status "INPUT" "Enter your choice: ")" edit_choice
            
            case $edit_choice in
                1)
                    read -p "$(print_status "INPUT" "New hostname (current: $HOSTNAME): ")" new_hostname
                    if [ -n "$new_hostname" ] && validate_input "name" "$new_hostname"; then
                        HOSTNAME="$new_hostname"
                        setup_vm_image
                    fi
                    ;;
                2)
                    read -p "$(print_status "INPUT" "New username (current: $USERNAME): ")" new_username
                    if [ -n "$new_username" ] && validate_input "username" "$new_username"; then
                        USERNAME="$new_username"
                        setup_vm_image
                    fi
                    ;;
                3)
                    read -s -p "$(print_status "INPUT" "New password: ")" new_password
                    echo
                    if [ -n "$new_password" ]; then
                        PASSWORD="$new_password"
                        setup_vm_image
                    fi
                    ;;
                4)
                    read -p "$(print_status "INPUT" "New SSH port (current: $SSH_PORT): ")" new_port
                    if [ -n "$new_port" ] && validate_input "port" "$new_port"; then
                        SSH_PORT="$new_port"
                    fi
                    ;;
                5)
                    read -p "$(print_status "INPUT" "Enable GUI? (y/n): ")" gui_choice
                    [[ "$gui_choice" =~ ^[Yy]$ ]] && GUI_MODE=true || GUI_MODE=false
                    ;;
                6)
                    read -p "$(print_status "INPUT" "Enable Quick Boot? (y/n): ")" qb_choice
                    [[ "$qb_choice" =~ ^[Yy]$ ]] && QUICK_BOOT=true || QUICK_BOOT=false
                    ;;
                7)
                    read -p "$(print_status "INPUT" "Port forwards (current: ${PORT_FORWARDS:-None}): ")" new_forwards
                    PORT_FORWARDS="$new_forwards"
                    ;;
                8)
                    read -p "$(print_status "INPUT" "New memory MB (current: $MEMORY): ")" new_mem
                    if [ -n "$new_mem" ] && validate_input "number" "$new_mem"; then
                        MEMORY="$new_mem"
                    fi
                    ;;
                9)
                    read -p "$(print_status "INPUT" "New CPU count (current: $CPUS): ")" new_cpus
                    if [ -n "$new_cpus" ] && validate_input "number" "$new_cpus"; then
                        CPUS="$new_cpus"
                    fi
                    ;;
                10)
                    read -p "$(print_status "INPUT" "New disk size (current: $DISK_SIZE): ")" new_disk
                    if [ -n "$new_disk" ] && validate_input "size" "$new_disk"; then
                        if qemu-img resize "$IMG_FILE" "$new_disk" &>/dev/null; then
                            DISK_SIZE="$new_disk"
                            print_status "SUCCESS" "Disk resized to $new_disk"
                        else
                            print_status "ERROR" "Failed to resize disk"
                        fi
                    fi
                    ;;
                0)
                    save_vm_config
                    return 0
                    ;;
                *)
                    print_status "ERROR" "Invalid selection"
                    ;;
            esac
            
            save_vm_config
            sleep 1
        done
    fi
}

# =============================
# 📊 Performance Monitor
# =============================
show_vm_performance() {
    local vm_name=$1
    
    if load_vm_config "$vm_name"; then
        clear
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}    ${BOLD}PERFORMANCE METRICS: $vm_name${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
        echo
        
        local qemu_pid=$(pgrep -f "qemu-system-x86_64.*$IMG_FILE")
        
        if [[ -n "$qemu_pid" ]]; then
            echo -e "${GREEN}🟢 VM is RUNNING${NC}"
            echo
            echo -e "${BOLD}Process Stats:${NC}"
            ps -p "$qemu_pid" -o pid,%cpu,%mem,rss,vsz,cmd --no-headers
            echo
            echo -e "${BOLD}Memory Usage:${NC}"
            free -h
            echo
            echo -e "${BOLD}Disk Usage:${NC}"            du -h "$IMG_FILE"
        else
            echo -e "${RED}🔴 VM is STOPPED${NC}"
            echo
            echo -e "${BOLD}VM Configuration:${NC}"
            echo "  🧠 Memory: $MEMORY MB"
            echo "  ⚙️  CPUs: $CPUS"
            echo "  💿 Disk: $DISK_SIZE"
            echo
            echo -e "${BOLD}Disk File Info:${NC}"
            if [[ -f "$IMG_FILE" ]]; then
                ls -lh "$IMG_FILE"
                echo
                qemu-img info "$IMG_FILE"
            fi
        fi
        echo
        read -p "$(print_status "INPUT" "Press Enter to continue...")"
    fi
}

# =============================
# 📋 Clone VM Function
# =============================
clone_vm() {
    local vms=($(get_vm_list))
    
    echo
    print_status "CONFIG" "Clone an existing VM"
    echo
    
    read -p "$(print_status "INPUT" "Enter VM number to clone (1-${#vms[@]}): ")" vm_num
    
    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le ${#vms[@]} ]; then
        local source_vm="${vms[$((vm_num-1))]}"
        
        if load_vm_config "$source_vm"; then
            read -p "$(print_status "INPUT" "Enter new VM name: ")" new_name
            
            if validate_input "name" "$new_name"; then
                if [[ -f "$VM_DIR/$new_name.conf" ]]; then
                    print_status "ERROR" "VM with name '$new_name' already exists"
                    sleep 2
                    return 1
                fi
                
                print_status "PROGRESS" "Cloning VM '$source_vm' to '$new_name'..."
                
                # Copy image file
                local new_img="$VM_DIR/$new_name.img"
                local new_seed="$VM_DIR/$new_name-seed.iso"
                
                if cp "$IMG_FILE" "$new_img"; then
                    cp "$SEED_FILE" "$new_seed"
                    
                    # Update config
                    VM_NAME="$new_name"
                    HOSTNAME="$new_name"
                    IMG_FILE="$new_img"
                    SEED_FILE="$new_seed"
                    CREATED="$(date '+%Y-%m-%d %H:%M:%S')"
                    
                    # Find free SSH port
                    SSH_PORT=$((SSH_PORT + 1))
                    while ss -tln 2>/dev/null | grep -q ":$SSH_PORT "; do
                        SSH_PORT=$((SSH_PORT + 1))
                    done
                    
                    save_vm_config
                    print_status "SUCCESS" "VM cloned successfully! New SSH port: $SSH_PORT"
                else
                    print_status "ERROR" "Failed to clone VM"
                fi
            fi
        fi
    else
        print_status "ERROR" "Invalid selection"
    fi
    sleep 2
}

# =============================
# 💾 Backup VM Function
# =============================
backup_vm() {
    local vms=($(get_vm_list))
    
    echo
    print_status "CONFIG" "Backup a VM"
    echo
    
    read -p "$(print_status "INPUT" "Enter VM number to backup (1-${#vms[@]}): ")" vm_num
    
    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le ${#vms[@]} ]; then
        local vm_name="${vms[$((vm_num-1))]}"
        
        if load_vm_config "$vm_name"; then
            local backup_dir="$VM_DIR/backups"
            mkdir -p "$backup_dir"
            
            local backup_name="${vm_name}_backup_$(date '+%Y%m%d_%H%M%S')"
            local backup_path="$backup_dir/$backup_name"
            
            print_status "PROGRESS" "Creating backup of '$vm_name'..."
            
            mkdir -p "$backup_path"
            
            # Copy files
            if cp "$IMG_FILE" "$backup_path/" && \
               cp "$SEED_FILE" "$backup_path/" && \
               cp "$VM_DIR/$vm_name.conf" "$backup_path/"; then
                
                # Create backup info
                cat > "$backup_path/backup_info.txt" <<EOF
Backup created: $(date)
Original VM: $vm_name
Hostname: $HOSTNAME
OS: $OS_TYPE
Memory: $MEMORY MB
CPUs: $CPUS
Disk: $DISK_SIZE
EOF
                
                print_status "SUCCESS" "Backup created: $backup_path"
                
                # Optional compression
                read -p "$(print_status "INPUT" "Compress backup? (y/n): ")" compress
                if [[ "$compress" =~ ^[Yy]$ ]]; then
                    print_status "PROGRESS" "Compressing backup..."
                    if tar -czf "$backup_path.tar.gz" -C "$backup_dir" "$backup_name"; then
                        rm -rf "$backup_path"
                        print_status "SUCCESS" "Compressed backup: $backup_path.tar.gz"
                    fi
                fi
            else
                print_status "ERROR" "Failed to create backup"
            fi
        fi
    else
        print_status "ERROR" "Invalid selection"
    fi
    sleep 2
}

# =============================
# 📋 Main Menu
# =============================
main_menu() {
    while true; do
        display_header
        
        local vms=($(get_vm_list))
        local vm_count=${#vms[@]}
        
        if [ $vm_count -gt 0 ]; then
            echo -e "${BOLD}${CYAN}📦 Your Virtual Machines:${NC}"
            echo
            for i in "${!vms[@]}"; do
                local status_icon="🔴"
                local status_text="${RED}Stopped${NC}"
                if pgrep -f "qemu-system-x86_64.*${vms[$i]}" >/dev/null; then
                    status_icon="🟢"
                    status_text="${GREEN}Running${NC}"
                fi
                printf "  ${BOLD}%2d)${NC} %s %-20s %s\n" $((i+1)) "$status_icon" "${vms[$i]}" "$(echo -e "$status_text")"
            done
            echo
        else
            echo -e "${YELLOW}📭 No VMs found. Create your first VM!${NC}"
            echo
        fi
        
        echo -e "${BOLD}${CYAN}🎯 Main Menu:${NC}"
        echo
        echo -e "  ${GREEN}1)${NC} 🆕 Create a new VM"
        
        if [ $vm_count -gt 0 ]; then
            echo -e "  ${GREEN}2)${NC} 🚀 Start a VM"
            echo -e "  ${RED}3)${NC} 🛑 Stop a VM"
            echo -e "  ${CYAN}4)${NC} ℹ️  Show VM info"
            echo -e "  ${YELLOW}5)${NC} ⚙️  Edit VM configuration"
            echo -e "  ${RED}6)${NC} 🗑️  Delete a VM"
            echo -e "  ${MAGENTA}7)${NC} 📊 Show VM performance"
            echo -e "  ${BLUE}8)${NC} 📋 Clone a VM"
            echo -e "  ${CYAN}9)${NC} 💾 Backup VM"
        fi
        
        echo -e "  ${RED}0)${NC} 👋 Exit"
        echo
        
        read -p "$(print_status "INPUT" "Enter your choice: ")" choice
        
        case $choice in
            1)
                create_new_vm
                ;;
            2)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "Enter VM number to start (1-$vm_count): ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        start_vm "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "Invalid selection"
                        sleep 2
                    fi
                fi
                ;;
            3)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "Enter VM number to stop (1-$vm_count): ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        stop_vm "${vms[$((vm_num-1))]}"
                        sleep 2
                    else
                        print_status "ERROR" "Invalid selection"
                        sleep 2
                    fi
                fi
                ;;
            4)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "Enter VM number to show info (1-$vm_count): ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        show_vm_info "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "Invalid selection"
                        sleep 2
                    fi
                fi
                ;;
            5)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "Enter VM number to edit (1-$vm_count): ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        edit_vm_config "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "Invalid selection"
                        sleep 2
                    fi
                fi
                ;;
            6)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "Enter VM number to delete (1-$vm_count): ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        delete_vm "${vms[$((vm_num-1))]}"
                        sleep 2
                    else
                        print_status "ERROR" "Invalid selection"
                        sleep 2
                    fi
                fi
                ;;
            7)
                if [ $vm_count -gt 0 ]; then
                    read -p "$(print_status "INPUT" "Enter VM number to show performance (1-$vm_count): ")" vm_num
                    if [[ "$vm_num" =~ ^[0-9]+$ ]] && [ "$vm_num" -ge 1 ] && [ "$vm_num" -le $vm_count ]; then
                        show_vm_performance "${vms[$((vm_num-1))]}"
                    else
                        print_status "ERROR" "Invalid selection"
                        sleep 2
                    fi
                fi
                ;;
            8)
                if [ $vm_count -gt 0 ]; then
                    clone_vm
                fi
                ;;
            9)
                if [ $vm_count -gt 0 ]; then
                    backup_vm
                fi
                ;;
            0)
                clear
                echo
                echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
                echo -e "${CYAN}║                                                ║${NC}"
                echo -e "${CYAN}║${NC}    ${BOLD}Thank you for using ZVPS! 🚀${NC}           ${CYAN}║${NC}"
                echo -e "${CYAN}║${NC}    ${CYAN}Lightning-Fast VM Management${NC}           ${CYAN}║${NC}"
                echo -e "${CYAN}║                                                ║${NC}"
                echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}"
                echo
                exit 0
                ;;
            *)
                print_status "ERROR" "Invalid option"
                sleep 2
                ;;
        esac
    done
}

# =============================
# 🎬 Initialization
# =============================

# Set trap to cleanup on exit
trap cleanup EXIT

# Minimalist splash on first run
clear
echo -e "${CYAN}${BOLD}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ZVPS v2.1 - Lightning VM Manager"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${NC}"
sleep 1

# Check dependencies
check_dependencies

# Initialize paths
VM_DIR="${VM_DIR:-$HOME/zvps-vms}"
mkdir -p "$VM_DIR"

print_status "SUCCESS" "VM directory: $VM_DIR"
sleep 1

# =============================
# 🌍 Supported Operating Systems
# =============================
declare -A OS_OPTIONS=(
    ["🟠 Ubuntu 22.04 LTS"]="ubuntu|jammy|https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img|ubuntu22|ubuntu|ubuntu"
    ["🟠 Ubuntu 24.04 LTS"]="ubuntu|noble|https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img|ubuntu24|ubuntu|ubuntu"
    ["🔴 Debian 11 (Bullseye)"]="debian|bullseye|https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2|debian11|debian|debian"
    ["🔴 Debian 12 (Bookworm)"]="debian|bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|debian12|debian|debian"
    ["🔵 Fedora 40"]="fedora|40|https://download.fedoraproject.org/pub/fedora/linux/releases/40/Cloud/x86_64/images/Fedora-Cloud-Base-40-1.14.x86_64.qcow2|fedora40|fedora|fedora"
    ["🟣 CentOS Stream 9"]="centos|stream9|https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2|centos9|centos|centos"
    ["🟢 AlmaLinux 9"]="almalinux|9|https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2|almalinux9|alma|alma"
    ["🟡 Rocky Linux 9"]="rockylinux|9|https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2|rocky9|rocky|rocky"
)

# =============================
# 🚀 Start Main Menu
# =============================
main_menu
