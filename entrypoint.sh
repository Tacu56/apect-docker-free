#!/bin/bash
set -e

# Function to download server JAR based on TYPE and VERSION
download_server() {
    local type="$1"
    local version="$2"
    
    case "$type" in
        "paper")
            if [ "$version" = "latest" ]; then
                version=$(curl -s "https://papermc.io/api/v2/projects/paper" | jq -r '.versions[-1]')
            fi
            build=$(curl -s "https://papermc.io/api/v2/projects/paper/versions/$version" | jq -r '.builds[-1]')
            download_url="https://papermc.io/api/v2/projects/paper/versions/$version/builds/$build/downloads/paper-$version-$build.jar"
            ;;
        "leaf")
            if [ "$version" = "latest" ]; then
                version=$(curl -s "https://api.leafmc.org/v1/leaf" | jq -r '.versions[-1]')
            fi
            build=$(curl -s "https://api.leafmc.org/v1/leaf/$version" | jq -r '.builds[-1]')
            download_url="https://api.leafmc.org/v1/leaf/$version/$build/download"
            ;;
        "folia")
            if [ "$version" = "latest" ]; then
                version=$(curl -s "https://papermc.io/api/v2/projects/folia" | jq -r '.versions[-1]')
            fi
            build=$(curl -s "https://papermc.io/api/v2/projects/folia/versions/$version" | jq -r '.builds[-1]')
            download_url="https://papermc.io/api/v2/projects/folia/versions/$version/builds/$build/downloads/folia-$version-$build.jar"
            ;;
        "fabric")
            if [ "$version" = "latest" ]; then
                version=$(curl -s "https://meta.fabricmc.net/v2/versions/game" | jq -r '.[0]')
            fi
            loader_version=$(curl -s "https://meta.fabricmc.net/v2/versions/loader" | jq -r '.[0].loader.version')
            installer_url="https://meta.fabricmc.net/v2/versions/loader/$version/$loader_version/server/jar"
            download_url="$installer_url"
            ;;
        *)
            echo "Unknown server type: $type"
            exit 1
            ;;
    esac
    
    echo "Downloading $type server version $version..."
    wget -O server.jar "$download_url"
}

# Function to setup Velocity proxy configuration
velocity-setup() {
    local type="$1"
    
    case "$type" in
        "paper"|"folia")
            # Setup paper-global.yml for proxy protocol
            mkdir -p config
            if [ ! -f config/paper-global.yml ]; then
                cp /paper-global.yml config/paper-global.yml
            fi
            ;;
        "leaf")
            # Setup spigot.yml for proxy protocol
            if [ ! -f spigot.yml ]; then
                cat > spigot.yml << EOF
settings:
  bungeecord: true
EOF
            fi
            ;;
        "fabric")
            # Download FabricProxy-Lite mod
            mkdir -p mods
            if [ ! -f mods/FabricProxy-Lite.jar ]; then
                echo "Downloading FabricProxy-Lite mod..."
                wget -O mods/FabricProxy-Lite.jar "https://cdn.modrinth.com/data/8dI4tmCM/versions/1.4.0/FabricProxy-Lite-1.4.0.jar"
            fi
            ;;
    esac
}

# Function to download additional plugins/mods
download_additional_plugins() {
    local plugins="$1"
    local type="$2"
    
    if [ -n "$plugins" ]; then
        echo "Downloading additional plugins/mods..."
        
        case "$type" in
            "fabric")
                mkdir -p mods
                echo "$plugins" | tr ',' '\n' | while read -r url; do
                    if [ -n "$url" ]; then
                        echo "Downloading mod from: $url"
                        wget -O "mods/$(basename "$url")" "$url"
                    fi
                done
                ;;
            *)
                mkdir -p plugins
                echo "$plugins" | tr ',' '\n' | while read -r url; do
                    if [ -n "$url" ]; then
                        echo "Downloading plugin from: $url"
                        wget -O "plugins/$(basename "$url")" "$url"
                    fi
                done
                ;;
        esac
    fi
}

# Main execution logic
main() {
    cd /data
    
    # Download server jar if it doesn't exist
    if [ ! -f server.jar ]; then
        download_server "$TYPE" "$VERSION"
    fi
    
    # Setup Velocity proxy configuration
    velocity-setup "$TYPE"
    
    # Download additional plugins/mods
    download_additional_plugins "$ADDITIONAL_PLUGINS" "$TYPE"
    
    # Ensure EULA is accepted
    if [ ! -f eula.txt ]; then
        echo "eula=true" > eula.txt
    fi
    
    # For Fabric, we need to accept the EULA differently
    if [ "$TYPE" = "fabric" ]; then
        echo "eula=true" > eula.txt
    fi
    
    echo "Starting $TYPE server with memory: $MEM"
    
    # CRIU compatibility: Use exec to make Java PID 1
    exec java -Xms${MEM} -Xmx${MEM} -jar server.jar nogui
}

# Run main function
main "$@"
