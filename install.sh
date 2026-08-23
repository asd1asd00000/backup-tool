#!/bin/bash

# Pasarguard Tool Installer

echo "========================================="
echo "  Installing Pasarguard Management Tool  "
echo "========================================="

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Error: Please run this install script as root (use sudo)."
    exit 1
fi

# Update package list and install zip/unzip
echo "Installing required dependencies (zip, unzip)..."
apt-get update -y > /dev/null 2>&1
apt-get install -y zip unzip > /dev/null 2>&1

# Define the raw URL of the main script (Replace with your actual GitHub username and repo name)
REPO_RAW_URL="https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO_NAME/main/pasarguard-tool.sh"

# Download the main script
echo "Downloading Pasarguard tool..."
mkdir -p /usr/local/bin
curl -s -o /usr/local/bin/pasarguard "$REPO_RAW_URL"

# If curl fails (e.g., running locally from cloned repo), try copying local file
if [ ! -s /usr/local/bin/pasarguard ]; then
    if [ -f "pasarguard-tool.sh" ]; then
        cp pasarguard-tool.sh /usr/local/bin/pasarguard
    else
        echo "Error: Could not download or find pasarguard-tool.sh."
        exit 1
    fi
fi

# Make the script executable
chmod +x /usr/local/bin/pasarguard

echo "========================================="
echo "  Installation Completed Successfully!   "
echo "========================================="
echo "You can now run the tool by typing: pasarguard"
echo "(Note: Run it with 'sudo pasarguard' to allow writing backups to /)"
