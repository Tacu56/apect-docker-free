#!/bin/bash
# Multi-architecture build script for Minecraft Server Docker Image

set -e

IMAGE_NAME="tacu56/apect-minecraft"
VERSION="latest"

echo "Building multi-architecture Docker image: $IMAGE_NAME:$VERSION"

# Create and use buildx builder
docker buildx create --name multiarch --driver docker-container --use 2>/dev/null || true
docker buildx inspect --bootstrap

# Build for multiple architectures and push
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --tag $IMAGE_NAME:$VERSION \
  --tag $IMAGE_NAME:$(date +%Y%m%d) \
  --push \
  .

echo "Multi-architecture build completed successfully!"
echo "Image available for: linux/amd64, linux/arm64"
echo "Docker Hub: https://hub.docker.com/r/$IMAGE_NAME"
