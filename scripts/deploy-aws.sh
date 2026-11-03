#!/usr/bin/env bash
# ==============================================================================
# AWS EC2 Deployment Script: Hospital Appointment Booking System
# Target OS: Ubuntu 22.04 LTS / 24.04 LTS or Amazon Linux 2023
# ==============================================================================

set -euo pipefail

echo "================================================================="
echo " Starting Hospital Appointment Booking Deployment on AWS EC2     "
echo "================================================================="

# 1. Update OS packages
echo "[Step 1/5] Updating system packages..."
if command -v apt-get &> /dev/null; then
    sudo apt-get update -y
    sudo apt-get install -y ca-certificates curl gnupg lsb-release git
elif command -v dnf &> /dev/null; then
    sudo dnf update -y
    sudo dnf install -y git curl
fi

# 2. Install Docker if not installed
if ! command -v docker &> /dev/null; then
    echo "[Step 2/5] Installing Docker Engine..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker "$USER"
    sudo systemctl enable docker
    sudo systemctl start docker
    rm -f get-docker.sh
else
    echo "[Step 2/5] Docker is already installed."
fi

# 3. Install Docker Compose plugin if not present
if ! docker compose version &> /dev/null; then
    echo "[Step 3/5] Installing Docker Compose plugin..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get install -y docker-compose-plugin
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y docker-compose-plugin
    fi
fi

# 4. Build or pull the Docker image
echo "[Step 4/5] Building Docker container image..."
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$APP_DIR"

# Stop and remove existing container if running
sudo docker rm -f hospital-booking-app 2>/dev/null || true

# Build production image
sudo docker build -t hospital-booking:latest .

# 5. Run the production container on port 80
echo "[Step 5/5] Running production container on port 80..."
sudo docker run -d \
    --name hospital-booking-app \
    --restart unless-stopped \
    -p 80:80 \
    hospital-booking:latest

# Health check
echo "Waiting for Nginx to initialize..."
sleep 3
if curl -s -f http://localhost/healthz > /dev/null; then
    echo "================================================================="
    echo " Deployment SUCCESSFUL! Application is LIVE on port 80.          "
    echo " Access your EC2 Public IP or Public DNS in your browser.         "
    echo "================================================================="
else
    echo "Health check failed! Showing container logs:"
    sudo docker logs hospital-booking-app
    exit 1
fi

