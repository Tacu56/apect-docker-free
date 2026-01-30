FROM openjdk:21-slim

# Install required packages for downloads and basic utilities
RUN apt-get update && \
    apt-get install -y wget curl unzip && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /data

# Create volume for server data
VOLUME ["/data"]

# Copy scripts and configuration files
COPY entrypoint.sh /entrypoint.sh
COPY eula.txt /data/eula.txt
COPY server.properties /data/server.properties

# Make entrypoint script executable
RUN chmod +x /entrypoint.sh

# Expose Minecraft port
EXPOSE 25565

# Set environment variables with defaults
ENV TYPE=paper
ENV VERSION=latest
ENV MEM=1G
ENV ADDITIONAL_PLUGINS=""

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]
