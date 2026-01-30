# Minecraft Server Docker Image

A flexible Docker image for running Minecraft servers with template support. Supports multiple server types including Leaf, Fabric, and various game modes.

## Features

- **Template-based deployment** - Choose from 8 pre-configured templates
- **Automatic JAR downloads** - Leaf and Fabric server jars are downloaded automatically
- **Resource control** - Configure RAM and CPU limits
- **Whitelist support** - Enable whitelist via environment variable
- **CRIU checkpoint compatible** - Supports live migration and checkpointing

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

### Build the Image

```bash
docker build -t minecraft-server .
```

### Run a Server

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

## CRIU Checkpointing

This image is designed to be CRIU checkpoint compatible. To enable checkpointing:

```bash
docker run -d \
  --cap-add=SYS_PTRACE \
  --cap-add=CHECKPOINT_RESTORE \
  --security-opt seccomp=unconfined \
  -e TEMPLATE=leaf \
  -e EULA=true \
  -p 25565:25565 \
  -v $(pwd)/server-data:/server \
  --name minecraft-server \
  minecraft-server
```

### Creating a Checkpoint

```bash
docker checkpoint create minecraft-server checkpoint1
```

### Restoring from Checkpoint

```bash
docker start --checkpoint checkpoint1 minecraft-server
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
