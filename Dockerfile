# Minecraft Server Docker Image
# CRIU checkpoint compatible base image
FROM eclipse-temurin:21-jdk-jammy

LABEL maintainer="minecraft-docker"
LABEL description="Flexible Minecraft server with template support"

# Install dependencies for CRIU compatibility and utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    jq \
    ca-certificates \
    libcap2-bin \
    && rm -rf /var/lib/apt/lists/*

# Create minecraft user for security (CRIU compatible)
RUN useradd -m -d /home/minecraft -s /bin/bash minecraft

# Set working directory
WORKDIR /server

# Create directories
RUN mkdir -p /templates /server/plugins /server/config

# Copy template folders
COPY templates/ /templates/

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Environment variables with defaults
ENV TEMPLATE=leaf \
    MIN_RAM=1G \
    MAX_RAM=4G \
    CPU_CORES=2 \
    WHITELIST=false \
    EULA=false \
    SERVER_PORT=25565 \
    JAVA_OPTS=""

# Expose default Minecraft port
EXPOSE 25565

# CRIU checkpoint compatibility settings
# - Use exec form for proper signal handling
# - Run as PID 1 compatible process
# - Avoid complex init systems

# Volume for persistent data
VOLUME ["/server"]

# Set capabilities for CRIU (if needed at runtime)
# Note: CRIU checkpointing requires --cap-add=SYS_PTRACE --cap-add=CHECKPOINT_RESTORE at runtime

# Health check
HEALTHCHECK --interval=60s --timeout=10s --start-period=120s --retries=3 \
    CMD echo "ping" | nc -w 3 localhost ${SERVER_PORT} || exit 1

# Use exec form for CRIU compatibility
ENTRYPOINT ["/entrypoint.sh"]
