# Minecraft Server Docker Image

A flexible Docker image for running Minecraft servers with template support. Supports multiple server types including Leaf, Fabric, and various game modes.

This image is only on github for transparency reasons, this readme is not kept up to date, and we recomment youuse this image at your own risk. This is the image used across all of our server on https://www.apect.net, although it is not recommended to use this image yourself.

## Docker Hub

This image is available on Docker Hub as [`tacu56/apect-minecraft`](https://hub.docker.com/r/tacu56/apect-minecraft).

```bash
docker pull tacu56/apect-minecraft
```

## Architecture Support

This image supports multiple architectures:
- **AMD64** (x86_64) - Standard servers and desktops
- **ARM64** (AArch64) - Apple Silicon, ARM servers, Raspberry Pi 4+

The Docker Hub image automatically provides the correct architecture for your system. No additional flags needed.

For local builds on ARM64 systems:

```bash
# Build for current architecture only
docker build -t minecraft-server .

# Or build for multiple architectures
docker buildx build --platform linux/amd64,linux/arm64 -t minecraft-server .
```

## Features

- **Template-based deployment** - Choose from 8 pre-configured templates
- **Automatic JAR downloads** - Leaf and Fabric server jars are downloaded automatically
- **Resource control** - Configure RAM and CPU limits
- **Whitelist support** - Enable whitelist via environment variable

## Templates

| Template | Server Type | Description |
|----------|-------------|-------------|
| `leaf` | Leaf | Base Leaf server with your configs |
| `fabric` | Fabric | Base Fabric server with your configs |
| `lifesteal` | Leaf | Lifesteal gamemode with plugins |
| `parkour` | Leaf | Parkour server with plugins |
| `manhunt` | Leaf | Manhunt gamemode with plugins |
| `bedwars` | Leaf | Bedwars gamemode with plugins |
| `pixelmon` | Fabric | Pixelmon modded server |
| `economy` | Leaf | Economy/survival server with plugins |

## Quick Start

### Using the Pre-built Image

The image is available on Docker Hub as `tacu56/apect-minecraft`:

```bash
docker pull tacu56/apect-minecraft
```

### Build the Image Locally

```bash
docker build -t minecraft-server .
```

### Multi-Architecture Build (For Docker Hub)

To build for multiple architectures (AMD64 and ARM64):

```bash
# Make the build script executable
chmod +x build-multiarch.sh

# Run the multi-architecture build
./build-multiarch.sh
```

Or manually:

```bash
# Setup buildx
docker buildx create --name multiarch --driver docker-container --use
docker buildx inspect --bootstrap

# Build and push for multiple architectures
docker buildx build --platform linux/amd64,linux/arm64 -t tacu56/apect-minecraft --push .
```

### Run a Server (Using Docker Hub Image)

```bash
docker run -d \
  -e TEMPLATE=leaf \
  -e MIN_RAM=2G \
  -e MAX_RAM=4G \
  -e CPU_CORES=2 \
  -e WHITELIST=false \
  -e EULA=true \
  -p 25565:25565 \
  -v $(pwd)/server-data:/server \
  --name my-minecraft-server \
  tacu56/apect-minecraft
```

### Run a Server (Using Local Build)

```bash
docker run -d \
  -e TEMPLATE=leaf \
  -e MIN_RAM=2G \
  -e MAX_RAM=4G \
  -e CPU_CORES=2 \
  -e WHITELIST=false \
  -e EULA=true \
  -p 25565:25565 \
  -v $(pwd)/server-data:/server \
  --name my-minecraft-server \
  minecraft-server
```

### Using Docker Compose

Update the `docker-compose.yml` to use the Docker Hub image:

```yaml
version: '3.8'
services:
  minecraft:
    image: tacu56/apect-minecraft
    environment:
      - TEMPLATE=leaf
      - MIN_RAM=2G
      - MAX_RAM=4G
      - CPU_CORES=2
      - WHITELIST=false
      - EULA=true
    ports:
      - "25565:25565"
    volumes:
      - ./server-data:/server
    restart: unless-stopped
```

Then run:

```bash
docker-compose up -d
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TEMPLATE` | `leaf` | Server template to use |
| `MIN_RAM` | `1G` | Minimum RAM allocation |
| `MAX_RAM` | `4G` | Maximum RAM allocation |
| `CPU_CORES` | `2` | Number of CPU cores to use |
| `WHITELIST` | `false` | Enable server whitelist |
| `EULA` | `false` | Accept Minecraft EULA |
| `SERVER_PORT` | `25565` | Server port |
| `JAVA_OPTS` | `` | Additional Java options |

## Adding Your Configuration Files

Each template has a folder in `templates/`:

```
templates/
├── leaf/           # Base Leaf configs
├── fabric/         # Base Fabric configs
├── lifesteal/      # Lifesteal configs + plugins
├── parkour/        # Parkour configs + plugins
├── manhunt/        # Manhunt configs + plugins
├── bedwars/        # Bedwars configs + plugins
├── pixelmon/       # Pixelmon configs + mods
└── economy/        # Economy configs + plugins
```

### For Leaf-based templates (leaf, lifesteal, parkour, manhunt, bedwars, economy):

Add your files:
- `server.properties` - Server settings
- `bukkit.yml`, `spigot.yml`, `paper.yml` - Server configs
- `plugins/` - Plugin JARs and their configs

### For Fabric-based templates (fabric, pixelmon):

Add your files:
- `server.properties` - Server settings
- `mods/` - Mod JARs
- `config/` - Mod configurations

## Examples

### Lifesteal Server with 6GB RAM

```bash
docker run -d \
  -e TEMPLATE=lifesteal \
  -e MIN_RAM=4G \
  -e MAX_RAM=6G \
  -e CPU_CORES=4 \
  -e WHITELIST=true \
  -e EULA=true \
  -p 25565:25565 \
  -v $(pwd)/lifesteal-data:/server \
  --name lifesteal-server \
  minecraft-server
```

### Pixelmon Server with 8GB RAM

```bash
docker run -d \
  -e TEMPLATE=pixelmon \
  -e MIN_RAM=6G \
  -e MAX_RAM=8G \
  -e CPU_CORES=4 \
  -e EULA=true \
  -p 25565:25565 \
  -v $(pwd)/pixelmon-data:/server \
  --name pixelmon-server \
  minecraft-server
```

## Persistent Data

Mount a volume to `/server` to persist your server data:

```bash
-v /path/to/your/data:/server
```

This will persist:
- World files
- Player data
- Plugin data
- Server configurations
- Logs

## Console Access

Attach to the server console:

```bash
docker attach minecraft-server
```

To detach without stopping: `Ctrl+P` then `Ctrl+Q`

## Logs

View server logs:

```bash
docker logs -f minecraft-server
```

## License

MIT License
