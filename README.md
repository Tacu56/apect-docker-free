# ApectNet Docker Infrastructure

A flexible, CRIU-compatible Docker infrastructure for Minecraft servers supporting multiple server types.

## Features

- **Multi-type Support**: Paper, Leaf, Folia, and Fabric servers
- **CRIU Compatible**: Proper PID 1 execution with `exec`
- **Velocity Integration**: Pre-configured proxy support
- **Auto-plugin Downloads**: Direct URL plugin/mod installation
- **Persistent Data**: Volume-mounted server data
- **Optimized Defaults**: Pre-configured server properties

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TYPE` | `paper` | Server type: `paper`, `leaf`, `folia`, `fabric` |
| `VERSION` | `latest` | Server version (e.g., `1.20.1`, `latest`) |
| `MEM` | `1G` | Java memory allocation (e.g., `2G`, `4G`) |
| `ADDITIONAL_PLUGINS` | `""` | Comma-separated URLs for plugins/mods |

## Usage

### Basic Usage

```bash
docker-compose up -d
```

### Custom Server Type

```bash
docker-compose run --rm -e TYPE=folia -e VERSION=1.20.1 -e MEM=4G apectnet
```

### With Additional Plugins

```bash
docker-compose run --rm \
  -e TYPE=paper \
  -e ADDITIONAL_PLUGINS="https://example.com/plugin1.jar,https://example.com/plugin2.jar" \
  apectnet
```

### Fabric with Mods

```bash
docker-compose run --rm \
  -e TYPE=fabric \
  -e VERSION=1.20.1 \
  -e ADDITIONAL_PLUGINS="https://modrinth.com/mod/fabric-api/latest" \
  apectnet
```

## Server Types

### Paper
- Downloads from PaperMC API
- Supports Velocity proxy via `paper-global.yml`
- Plugin directory: `plugins/`

### Leaf
- Downloads from LeafMC API  
- Supports proxy via `spigot.yml`
- Plugin directory: `plugins/`

### Folia
- Downloads from PaperMC Folia API
- Supports Velocity proxy via `paper-global.yml`
- Plugin directory: `plugins/`

### Fabric
- Downloads from FabricMC API
- Auto-downloads FabricProxy-Lite mod
- Mod directory: `mods/`

## CRIU Compatibility

This setup is designed to work with CRIU (Checkpoint/Restore in Userspace):

- Uses `exec` to make Java process PID 1
- No background processes remain after startup
- Clean process tree for checkpointing

## Persistence

All server data is stored in `/data` and mounted as a Docker volume:
- World files
- Server configuration
- Plugins/mods
- Player data

## Development

To build the image:

```bash
docker build -t apectnet .
```

To run with custom settings:

```bash
docker run -d \
  -p 25565:25565 \
  -v apectnet-data:/data \
  -e TYPE=paper \
  -e VERSION=1.20.1 \
  -e MEM=2G \
  --name apectnet-server \
  apectnet
```
