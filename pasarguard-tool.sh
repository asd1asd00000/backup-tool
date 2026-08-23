#!/bin/bash

# Pasarguard Panel Management Tool

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Error: This tool requires root privileges. Please run with: sudo pasarguard"
    exit 1
fi

# Function to show the menu
show_menu() {
    clear
    echo "================================================"
    echo "       Pasarguard Panel Management Tool         "
    echo "================================================"
    echo "  1) Backup Pasarguard Panel"
    echo "  2) Exit"
    echo "================================================"
    read -p "Please select an option [1-2]: " choice
}

# Function to perform the backup
backup_panel() {
    echo "------------------------------------------------"
    echo "Starting Pasarguard Panel Backup..."
    
    DIR1="/opt/pasarguard"
    DIR2="/var/lib/pasarguard"
    
    # Check if at least one directory exists
    if [ ! -d "$DIR1" ] && [ ! -d "$DIR2" ]; then
        echo "Error: Neither $DIR1 nor $DIR2 exists on this server!"
        read -p "Press Enter to return to the menu..."
        return
    fi

    # Generate timestamp and backup file path in /root/
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_DIR="/root"
    BACKUP_FILE="${BACKUP_DIR}/pasarguard_backup_${TIMESTAMP}.zip"

    echo "Target directories:"
    [ -d "$DIR1" ] && echo " - $DIR1"
    [ -d "$DIR2" ] && echo " - $DIR2"
    echo "Backup destination: $BACKUP_FILE"
    echo ""
    echo "Creating ZIP archive, please wait..."
    
    # Create the zip file (Removed 2>/dev/null to show potential errors)
    zip -r -q "$BACKUP_FILE" "$DIR1" "$DIR2"

    if [ $? -eq 0 ]; then
        echo "------------------------------------------------"
        echo "Success! Backup created successfully."
        echo "File location: $BACKUP_FILE"
        echo "File details:"
        ls -lh "$BACKUP_FILE"
    else
        echo "------------------------------------------------"
        echo "Error: Backup failed. Check the errors above."
    fi
    
    echo "------------------------------------------------"
    read -p "Press Enter to return to the menu..."
}

# Main loop
while true; do
    show_menu
    case $choice in
        1)
            backup_panel
            ;;
        2)
            echo "Exiting Pasarguard Tool. Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid option. Please try again."
            sleep 2
            ;;
    esac
done
