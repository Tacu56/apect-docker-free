# APECT Minecraft Server Launcher (Docker-Free)

A lightweight, Docker-free Minecraft server launcher with multiple templates, CRIU checkpointing support, and resource management.

## Features

- **8 Pre-configured Templates**: Leaf, Fabric, Lifesteal, Parkour, Manhunt, Bedwars, Pixelmon, Economy
- **Resource Management**: RAM allocation and CPU core limits
- **CRIU Checkpointing**: Save and restore server state for zero-downtime migrations
- **Whitelist Support**: Easy whitelist toggle via command line
- **Cross-Platform**: Works on Linux (Bash) and Windows (Batch)

## Templates

| Template | Base | Description |
|----------|------|-------------|
| `leaf` | Leaf | Optimized Paper fork for vanilla+ servers |
| `fabric` | Fabric | Modded server base |
| `lifesteal` | Leaf | Lifesteal PvP gamemode |
| `parkour` | Leaf | Parkour minigame server |
| `manhunt` | Leaf | Manhunt gamemode |
| `bedwars` | Leaf | Bedwars minigame server |
| `pixelmon` | Fabric | Pixelmon modded server |
| `economy` | Leaf | Economy/survival server |

## Quick Start

### Linux/macOS
```bash
chmod +x server.sh
./server.sh -t leaf -r 4G:8G -w
```

### Windows
```batch
server.bat -t leaf -r 4G:8G -w
```

## Command Line Options

| Option | Description |
|--------|-------------|
| `-t, --template <name>` | Server template (required) |
| `-r, --ram <min:max>` | RAM allocation (e.g., `2G:8G` or `4G`) |
| `-c, --cores <count>` | CPU cores limit |
| `-w, --whitelist` | Enable whitelist |
| `-d, --dir <path>` | Server directory (default: `./server`) |
| `--criu` | Enable CRIU checkpointing mode |
| `--criu-dir <path>` | Checkpoint directory (default: `./checkpoints`) |
| `--checkpoint` | Create checkpoint of running server (Linux) |
| `--restore` | Restore from last checkpoint (Linux) |
| `-h, --help` | Show help message |

## Examples

### Basic Leaf Server
```bash
./server.sh -t leaf -r 4G
```

### High-Performance Bedwars Server
```bash
./server.sh -t bedwars -r 4G:16G -c 8 -w
```

### Pixelmon with CRIU Support
```bash
./server.sh -t pixelmon -r 8G:16G --criu
```

### Create Checkpoint
```bash
./server.sh --checkpoint
```

### Restore from Checkpoint
```bash
./server.sh --restore
```

## Resource Management

### RAM Allocation
Use `-r` or `--ram` to set memory limits:
- Single value: `4G` (sets both min and max)
- Range: `2G:8G` (min:max)

### CPU Core Limiting
Use `-c` or `--cores` to limit CPU usage:
- Linux: Uses `taskset` for CPU affinity
- Windows: Uses process affinity mask

## CRIU Checkpointing

CRIU (Checkpoint/Restore In Userspace) allows you to freeze the server state and restore it later.

### Requirements (Linux only)
- CRIU installed: `sudo apt install criu`
- Root privileges for checkpoint/restore operations

### CRIU-Compatible JVM Flags
When `--criu` is enabled, the launcher uses special JVM flags:
- Serial GC instead of G1GC
- Disabled compressed oops/class pointers
- Disabled TLAB
- Pre-touched memory allocation

### Usage
1. Start server with CRIU mode:
   ```bash
   ./server.sh -t leaf -r 4G --criu
   ```

2. Create checkpoint (server keeps running):
   ```bash
   ./server.sh --checkpoint
   ```

3. Restore from checkpoint:
   ```bash
   ./server.sh --restore
   ```

## Adding Custom Configurations

Each template has a directory in `templates/`:
```
templates/
├── leaf/
│   ├── server.properties
│   ├── config/
│   └── plugins/
├── fabric/
│   ├── server.properties
│   └── mods/
├── lifesteal/
│   ├── server.properties
│   └── plugins/
...
```

Add your custom:
- **Plugins**: Place `.jar` files in `templates/<template>/plugins/`
- **Mods**: Place `.jar` files in `templates/<template>/mods/` (Fabric-based)
- **Configs**: Add any config files/folders to the template directory

Files are copied to the server directory on first launch.

## Directory Structure

```
apect-docker-free/
├── server.sh          # Linux/macOS launcher
├── server.bat         # Windows launcher
├── templates/         # Server templates
│   ├── leaf/
│   ├── fabric/
│   ├── lifesteal/
│   ├── parkour/
│   ├── manhunt/
│   ├── bedwars/
│   ├── pixelmon/
│   └── economy/
├── server/            # Created on first run
│   ├── server.jar
│   ├── server.properties
│   ├── plugins/
│   └── ...
└── checkpoints/       # CRIU checkpoints (if enabled)
```

## License

MIT License
