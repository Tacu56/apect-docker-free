#!/bin/bash

# APECT Minecraft Server Launcher
# CRIU Checkpointing Compatible

set -e

# Default values
RAM_MIN="1G"
RAM_MAX="4G"
CPU_CORES=""
WHITELIST="false"
TEMPLATE=""
SERVER_DIR="./server"
CRIU_ENABLED="false"
CRIU_DIR="./checkpoints"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_usage() {
    echo -e "${BLUE}APECT Minecraft Server Launcher${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t, --template <name>     Server template (leaf, fabric, lifesteal, parkour, manhunt, bedwars, pixelmon, economy)"
    echo "  -r, --ram <min:max>       RAM allocation (e.g., 2G:8G or just 4G for both)"
    echo "  -c, --cores <count>       CPU cores limit (uses taskset/cpulimit)"
    echo "  -w, --whitelist           Enable whitelist"
    echo "  -d, --dir <path>          Server directory (default: ./server)"
    echo "  --criu                    Enable CRIU checkpointing"
    echo "  --criu-dir <path>         CRIU checkpoint directory (default: ./checkpoints)"
    echo "  --checkpoint              Create a checkpoint of running server"
    echo "  --restore                 Restore from last checkpoint"
    echo "  -h, --help                Show this help message"
    echo ""
    echo "Templates:"
    echo "  leaf      - Leaf server (optimized Paper fork)"
    echo "  fabric    - Fabric modded server"
    echo "  lifesteal - Lifesteal gamemode (Leaf-based)"
    echo "  parkour   - Parkour gamemode (Leaf-based)"
    echo "  manhunt   - Manhunt gamemode (Leaf-based)"
    echo "  bedwars   - Bedwars gamemode (Leaf-based)"
    echo "  pixelmon  - Pixelmon modded (Fabric-based)"
    echo "  economy   - Economy/survival server (Leaf-based)"
    echo ""
    echo "Examples:"
    echo "  $0 -t leaf -r 4G:8G -c 4 -w"
    echo "  $0 -t pixelmon -r 8G:16G --criu"
    echo "  $0 --checkpoint"
    echo "  $0 --restore"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse RAM argument
parse_ram() {
    local ram_arg="$1"
    if [[ "$ram_arg" == *":"* ]]; then
        RAM_MIN="${ram_arg%%:*}"
        RAM_MAX="${ram_arg##*:}"
    else
        RAM_MIN="$ram_arg"
        RAM_MAX="$ram_arg"
    fi
}

# Get template type (leaf or fabric)
get_template_type() {
    case "$1" in
        leaf|lifesteal|parkour|manhunt|bedwars|economy)
            echo "leaf"
            ;;
        fabric|pixelmon)
            echo "fabric"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Download server jar
download_server_jar() {
    local template_type="$1"
    local jar_path="$SERVER_DIR/server.jar"
    
    if [[ -f "$jar_path" ]]; then
        log_info "Server jar already exists, skipping download"
        return 0
    fi
    
    mkdir -p "$SERVER_DIR"
    
    case "$template_type" in
        leaf)
            log_info "Downloading Leaf server jar..."
            # Leaf MC download URL - using latest stable
            local leaf_url="https://api.leafmc.one/v1/download/latest"
            if command -v curl &> /dev/null; then
                curl -L -o "$jar_path" "$leaf_url" || {
                    log_error "Failed to download Leaf jar"
                    return 1
                }
            elif command -v wget &> /dev/null; then
                wget -O "$jar_path" "$leaf_url" || {
                    log_error "Failed to download Leaf jar"
                    return 1
                }
            else
                log_error "Neither curl nor wget found. Please install one."
                return 1
            fi
            ;;
        fabric)
            log_info "Downloading Fabric server jar..."
            # Fabric installer - downloads latest
            local fabric_url="https://meta.fabricmc.net/v2/versions/loader/1.20.4/0.15.6/1.0.0/server/jar"
            if command -v curl &> /dev/null; then
                curl -L -o "$jar_path" "$fabric_url" || {
                    log_error "Failed to download Fabric jar"
                    return 1
                }
            elif command -v wget &> /dev/null; then
                wget -O "$jar_path" "$fabric_url" || {
                    log_error "Failed to download Fabric jar"
                    return 1
                }
            else
                log_error "Neither curl nor wget found. Please install one."
                return 1
            fi
            ;;
        *)
            log_error "Unknown template type: $template_type"
            return 1
            ;;
    esac
    
    log_info "Server jar downloaded successfully"
}

# Apply template configuration
apply_template() {
    local template="$1"
    local template_dir="./templates/$template"
    
    if [[ ! -d "$template_dir" ]]; then
        log_warn "Template directory not found: $template_dir"
        return 0
    fi
    
    log_info "Applying template: $template"
    
    # Copy template files to server directory
    cp -rn "$template_dir/"* "$SERVER_DIR/" 2>/dev/null || true
    
    log_info "Template applied successfully"
}

# Configure whitelist
configure_whitelist() {
    local whitelist_enabled="$1"
    local server_props="$SERVER_DIR/server.properties"
    
    if [[ ! -f "$server_props" ]]; then
        # Create basic server.properties if not exists
        cat > "$server_props" << EOF
#Minecraft server properties
enable-command-block=true
gamemode=survival
difficulty=normal
spawn-protection=0
max-players=20
online-mode=true
white-list=$whitelist_enabled
enforce-whitelist=$whitelist_enabled
EOF
    else
        # Update existing server.properties
        if grep -q "^white-list=" "$server_props"; then
            sed -i "s/^white-list=.*/white-list=$whitelist_enabled/" "$server_props"
        else
            echo "white-list=$whitelist_enabled" >> "$server_props"
        fi
        
        if grep -q "^enforce-whitelist=" "$server_props"; then
            sed -i "s/^enforce-whitelist=.*/enforce-whitelist=$whitelist_enabled/" "$server_props"
        else
            echo "enforce-whitelist=$whitelist_enabled" >> "$server_props"
        fi
    fi
    
    log_info "Whitelist configured: $whitelist_enabled"
}

# Accept EULA
accept_eula() {
    local eula_file="$SERVER_DIR/eula.txt"
    echo "eula=true" > "$eula_file"
    log_info "EULA accepted"
}

# Build JVM arguments for CRIU compatibility
build_jvm_args() {
    local jvm_args=""
    
    # Memory settings
    jvm_args+="-Xms${RAM_MIN} -Xmx${RAM_MAX} "
    
    # CRIU compatibility flags
    if [[ "$CRIU_ENABLED" == "true" ]]; then
        # Disable JIT compilation features that break CRIU
        jvm_args+="-XX:+UseSerialGC "
        jvm_args+="-XX:-UsePerfData "
        jvm_args+="-XX:+UseContainerSupport "
        # Disable compressed oops for better CRIU compatibility
        jvm_args+="-XX:-UseCompressedOops "
        jvm_args+="-XX:-UseCompressedClassPointers "
        # Disable thread local allocation buffer
        jvm_args+="-XX:-UseTLAB "
        # Ensure predictable memory layout
        jvm_args+="-XX:+AlwaysPreTouch "
    else
        # Standard optimized flags
        jvm_args+="-XX:+UseG1GC "
        jvm_args+="-XX:+ParallelRefProcEnabled "
        jvm_args+="-XX:MaxGCPauseMillis=200 "
        jvm_args+="-XX:+UnlockExperimentalVMOptions "
        jvm_args+="-XX:+DisableExplicitGC "
        jvm_args+="-XX:+AlwaysPreTouch "
        jvm_args+="-XX:G1NewSizePercent=30 "
        jvm_args+="-XX:G1MaxNewSizePercent=40 "
        jvm_args+="-XX:G1HeapRegionSize=8M "
        jvm_args+="-XX:G1ReservePercent=20 "
        jvm_args+="-XX:G1HeapWastePercent=5 "
        jvm_args+="-XX:G1MixedGCCountTarget=4 "
        jvm_args+="-XX:InitiatingHeapOccupancyPercent=15 "
        jvm_args+="-XX:G1MixedGCLiveThresholdPercent=90 "
        jvm_args+="-XX:G1RSetUpdatingPauseTimePercent=5 "
        jvm_args+="-XX:SurvivorRatio=32 "
        jvm_args+="-XX:+PerfDisableSharedMem "
        jvm_args+="-XX:MaxTenuringThreshold=1 "
    fi
    
    # Common flags
    jvm_args+="-Dusing.aikars.flags=https://mcflags.emc.gs "
    jvm_args+="-Daikars.new.flags=true "
    jvm_args+="-jar server.jar nogui"
    
    echo "$jvm_args"
}

# Create CRIU checkpoint
create_checkpoint() {
    if ! command -v criu &> /dev/null; then
        log_error "CRIU is not installed"
        return 1
    fi
    
    local pid_file="$SERVER_DIR/server.pid"
    if [[ ! -f "$pid_file" ]]; then
        log_error "Server PID file not found. Is the server running?"
        return 1
    fi
    
    local pid=$(cat "$pid_file")
    
    if ! kill -0 "$pid" 2>/dev/null; then
        log_error "Server process (PID: $pid) is not running"
        return 1
    fi
    
    mkdir -p "$CRIU_DIR"
    local checkpoint_name="checkpoint_$(date +%Y%m%d_%H%M%S)"
    local checkpoint_path="$CRIU_DIR/$checkpoint_name"
    mkdir -p "$checkpoint_path"
    
    log_info "Creating checkpoint for PID $pid..."
    
    sudo criu dump -t "$pid" \
        --images-dir "$checkpoint_path" \
        --leave-running \
        --shell-job \
        --tcp-established \
        --ext-unix-sk \
        --file-locks \
        || {
            log_error "Failed to create checkpoint"
            return 1
        }
    
    # Save current directory for restore
    echo "$SERVER_DIR" > "$checkpoint_path/server_dir"
    
    log_info "Checkpoint created: $checkpoint_path"
    
    # Create symlink to latest
    ln -sf "$checkpoint_name" "$CRIU_DIR/latest"
}

# Restore from checkpoint
restore_checkpoint() {
    if ! command -v criu &> /dev/null; then
        log_error "CRIU is not installed"
        return 1
    fi
    
    local checkpoint_path="$CRIU_DIR/latest"
    
    if [[ ! -d "$checkpoint_path" ]]; then
        log_error "No checkpoint found at: $checkpoint_path"
        return 1
    fi
    
    log_info "Restoring from checkpoint..."
    
    sudo criu restore \
        --images-dir "$checkpoint_path" \
        --shell-job \
        --tcp-established \
        --ext-unix-sk \
        --file-locks \
        || {
            log_error "Failed to restore from checkpoint"
            return 1
        }
    
    log_info "Server restored from checkpoint"
}

# Start the server
start_server() {
    local jvm_args=$(build_jvm_args)
    
    log_info "Starting Minecraft server..."
    log_info "RAM: ${RAM_MIN} - ${RAM_MAX}"
    [[ -n "$CPU_CORES" ]] && log_info "CPU Cores: $CPU_CORES"
    log_info "Whitelist: $WHITELIST"
    [[ "$CRIU_ENABLED" == "true" ]] && log_info "CRIU: Enabled"
    
    cd "$SERVER_DIR"
    
    # Build the command
    local cmd="java $jvm_args"
    
    # Apply CPU core limit if specified
    if [[ -n "$CPU_CORES" ]]; then
        if command -v taskset &> /dev/null; then
            # Generate CPU mask for specified number of cores
            local cpu_mask=$(printf "0x%x" $((2**CPU_CORES - 1)))
            cmd="taskset $cpu_mask $cmd"
            log_info "Using taskset with mask: $cpu_mask"
        elif command -v cpulimit &> /dev/null; then
            # Calculate percentage (100% per core)
            local cpu_percent=$((CPU_CORES * 100))
            log_warn "taskset not available, using cpulimit instead"
            # cpulimit needs to wrap the process differently
            eval "$cmd" &
            local server_pid=$!
            echo $server_pid > server.pid
            cpulimit -p $server_pid -l $cpu_percent &
            wait $server_pid
            return
        else
            log_warn "Neither taskset nor cpulimit available. Running without CPU limits."
        fi
    fi
    
    # Run the server
    eval "$cmd" &
    local server_pid=$!
    echo $server_pid > server.pid
    
    log_info "Server started with PID: $server_pid"
    
    # Wait for server
    wait $server_pid
}

# Parse command line arguments
ACTION="start"

while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--template)
            TEMPLATE="$2"
            shift 2
            ;;
        -r|--ram)
            parse_ram "$2"
            shift 2
            ;;
        -c|--cores)
            CPU_CORES="$2"
            shift 2
            ;;
        -w|--whitelist)
            WHITELIST="true"
            shift
            ;;
        -d|--dir)
            SERVER_DIR="$2"
            shift 2
            ;;
        --criu)
            CRIU_ENABLED="true"
            shift
            ;;
        --criu-dir)
            CRIU_DIR="$2"
            shift 2
            ;;
        --checkpoint)
            ACTION="checkpoint"
            shift
            ;;
        --restore)
            ACTION="restore"
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Execute action
case "$ACTION" in
    checkpoint)
        create_checkpoint
        ;;
    restore)
        restore_checkpoint
        ;;
    start)
        if [[ -z "$TEMPLATE" ]]; then
            log_error "Template is required. Use -t or --template"
            print_usage
            exit 1
        fi
        
        template_type=$(get_template_type "$TEMPLATE")
        if [[ -z "$template_type" ]]; then
            log_error "Invalid template: $TEMPLATE"
            print_usage
            exit 1
        fi
        
        log_info "Template: $TEMPLATE (Type: $template_type)"
        
        # Setup server
        mkdir -p "$SERVER_DIR"
        download_server_jar "$template_type"
        apply_template "$TEMPLATE"
        configure_whitelist "$WHITELIST"
        accept_eula
        
        # Start server
        start_server
        ;;
esac
