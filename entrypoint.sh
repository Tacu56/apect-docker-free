#!/bin/bash
set -e

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Template to JAR type mapping
get_jar_type() {
    case "${TEMPLATE,,}" in
        leaf|lifesteal|parkour|manhunt|bedwars|economy)
            echo "leaf"
            ;;
        fabric|pixelmon)
            echo "fabric"
            ;;
        *)
            log_error "Unknown template: $TEMPLATE"
            exit 1
            ;;
    esac
}

# Validate jar file integrity
validate_jar() {
    local jar_file="/server/server.jar"
    
    if [ ! -f "$jar_file" ]; then
        return 1
    fi
    
    # Check if file is empty
    if [ ! -s "$jar_file" ]; then
        log_warn "Server jar file is empty"
        return 1
    fi
    
    # Check if it's a valid jar file (zip archive)
    if ! file "$jar_file" | grep -q "Zip archive data\|Java archive"; then
        log_warn "Server jar is not a valid jar file"
        return 1
    fi
    
    # Try to read jar manifest to verify it's not corrupted
    if ! unzip -t "$jar_file" >/dev/null 2>&1; then
        log_warn "Server jar file is corrupted or incomplete"
        return 1
    fi
    
    return 0
}

# Copy server jar from template
copy_template_jar() {
    local template_dir="/templates/${TEMPLATE,,}"
    local template_jar="$template_dir/server.jar"
    
    if [ -f "$template_jar" ]; then
        log_info "Found server.jar in template folder, copying..."
        cp "$template_jar" /server/server.jar
        
        if validate_jar; then
            log_info "Template server.jar copied and validated successfully"
            return 0
        else
            log_warn "Template server.jar is invalid or corrupted"
            rm -f /server/server.jar
            return 1
        fi
    else
        log_info "No server.jar found in template folder"
        return 1
    fi
}

# Copy template files
copy_template_files() {
    local template_dir="/templates/${TEMPLATE,,}"
    
    if [ -d "$template_dir" ]; then
        log_info "Copying template files from $template_dir..."
        
        # Copy all files from template, preserving structure (exclude server.jar as it's handled separately)
        if [ "$(ls -A $template_dir 2>/dev/null)" ]; then
            for item in "$template_dir"/*; do
                if [ "$(basename "$item")" != "server.jar" ]; then
                    cp -rn "$item" /server/ 2>/dev/null || true
                fi
            done
            log_info "Template files copied"
        else
            log_info "Template directory is empty, skipping..."
        fi
    else
        log_warn "Template directory not found: $template_dir"
    fi
}

# Setup EULA
setup_eula() {
    if [ "${EULA,,}" = "true" ]; then
        echo "eula=true" > /server/eula.txt
        log_info "EULA accepted"
    else
        log_warn "EULA not accepted. Set EULA=true to accept."
        log_warn "By setting EULA=true, you agree to the Minecraft EULA: https://aka.ms/MinecraftEULA"
    fi
}

# Setup whitelist
setup_whitelist() {
    if [ "${WHITELIST,,}" = "true" ]; then
        log_info "Enabling whitelist..."
        
        # Create or update server.properties
        if [ -f /server/server.properties ]; then
            if grep -q "^white-list=" /server/server.properties; then
                sed -i 's/^white-list=.*/white-list=true/' /server/server.properties
            else
                echo "white-list=true" >> /server/server.properties
            fi
            if grep -q "^enforce-whitelist=" /server/server.properties; then
                sed -i 's/^enforce-whitelist=.*/enforce-whitelist=true/' /server/server.properties
            else
                echo "enforce-whitelist=true" >> /server/server.properties
            fi
        else
            echo "white-list=true" > /server/server.properties
            echo "enforce-whitelist=true" >> /server/server.properties
        fi
        
        # Create empty whitelist.json if it doesn't exist
        if [ ! -f /server/whitelist.json ]; then
            echo "[]" > /server/whitelist.json
        fi
        
        log_info "Whitelist enabled"
    fi
}

# Build Java options
build_java_opts() {
    local opts=""
    
    # Memory settings
    opts="-Xms${MIN_RAM} -Xmx${MAX_RAM}"
    
    # CPU cores limit using processors
    opts="$opts -XX:ActiveProcessorCount=${CPU_CORES}"
    
    # G1GC garbage collector (recommended for Minecraft)
    opts="$opts -XX:+UseG1GC"
    opts="$opts -XX:+ParallelRefProcEnabled"
    opts="$opts -XX:MaxGCPauseMillis=200"
    opts="$opts -XX:+UnlockExperimentalVMOptions"
    opts="$opts -XX:+DisableExplicitGC"
    opts="$opts -XX:+AlwaysPreTouch"
    opts="$opts -XX:G1NewSizePercent=30"
    opts="$opts -XX:G1MaxNewSizePercent=40"
    opts="$opts -XX:G1HeapRegionSize=8M"
    opts="$opts -XX:G1ReservePercent=20"
    opts="$opts -XX:G1HeapWastePercent=5"
    opts="$opts -XX:G1MixedGCCountTarget=4"
    opts="$opts -XX:InitiatingHeapOccupancyPercent=15"
    opts="$opts -XX:G1MixedGCLiveThresholdPercent=90"
    opts="$opts -XX:G1RSetUpdatingPauseTimePercent=5"
    opts="$opts -XX:SurvivorRatio=32"
    opts="$opts -XX:+PerfDisableSharedMem"
    opts="$opts -XX:MaxTenuringThreshold=1"
    
    # CRIU compatibility flags
    opts="$opts -XX:-UsePerfData"
    opts="$opts -XX:+UseContainerSupport"
    
    # Append custom Java options if provided
    if [ -n "$JAVA_OPTS" ]; then
        opts="$opts $JAVA_OPTS"
    fi
    
    echo "$opts"
}

# Main execution
main() {
    log_section "Minecraft Server Startup"
    
    log_info "Template: $TEMPLATE"
    log_info "RAM: $MIN_RAM - $MAX_RAM"
    log_info "CPU Cores: $CPU_CORES"
    log_info "Whitelist: $WHITELIST"
    log_info "Server Port: $SERVER_PORT"
    
    # Determine jar type based on template
    JAR_TYPE=$(get_jar_type)
    log_info "Server type: $JAR_TYPE"
    
    # Get server jar from template
    if [ ! -f /server/server.jar ] || ! validate_jar; then
        if [ -f /server/server.jar ]; then
            log_warn "Existing server jar is corrupted, removing..."
            rm -f /server/server.jar
        fi
        
        # Copy from template folder
        if ! copy_template_jar; then
            log_error "No valid server.jar found in template folder: /templates/${TEMPLATE,,}/"
            log_error "Please ensure a valid server.jar exists in the template directory."
            exit 1
        fi
    else
        log_info "Server jar already exists and is valid, skipping"
    fi
    
    # Copy template files (won't overwrite existing)
    copy_template_files
    
    # Setup EULA
    setup_eula
    
    # Setup whitelist if enabled
    setup_whitelist
    
    # Build Java options
    JAVA_OPTIONS=$(build_java_opts)
    log_info "Java options: $JAVA_OPTIONS"
    
    log_section "Starting Minecraft Server"
    
    # Change to server directory
    cd /server
    
    # Execute server with exec for proper PID 1 handling (CRIU compatible)
    # Using exec ensures signals are properly forwarded
    exec java $JAVA_OPTIONS -jar server.jar nogui
}

# Run main function
main "$@"
