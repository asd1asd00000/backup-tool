#!/bin/bash

# Pasarguard Panel Management Tool (Advanced)
CONFIG_FILE="/root/.pasarguard_config"
SCRIPT_PATH="/usr/local/bin/pasarguard"

# Load configuration if exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Error: This tool requires root privileges. Please run with: sudo pasarguard"
    exit 1
fi

# ==========================================
# CORE FUNCTIONS
# ==========================================

save_config() {
    cat <<EOF > "$CONFIG_FILE"
TG_TOKEN="$TG_TOKEN"
TG_CHAT_ID="$TG_CHAT_ID"
BACKUP_PASS="$BACKUP_PASS"
BACKUP_INTERVAL="$BACKUP_INTERVAL"
EOF
}

send_telegram_message() {
    local text="$1"
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d chat_id="$TG_CHAT_ID" \
        -d text="$text" \
        -d parse_mode="HTML" > /dev/null
}

send_telegram_file() {
    local file="$1"
    local caption="$2"
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendDocument" \
        -F chat_id="$TG_CHAT_ID" \
        -F document=@"$file" \
        -F caption="$caption" > /dev/null
}

do_local_backup() {
    echo "------------------------------------------------"
    echo "Starting Local Backup..."
    
    read -s -p "Enter a password for the ZIP file: " ZIP_PASS
    echo
    read -s -p "Confirm password: " ZIP_PASS_CONFIRM
    echo
    
    if [ "$ZIP_PASS" != "$ZIP_PASS_CONFIRM" ]; then
        echo "Error: Passwords do not match!"
        read -p "Press Enter to continue..."
        return
    fi

    local TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    local BACKUP_FILE="/root/pasarguard_backup_${TIMESTAMP}.zip"

    echo "Creating ZIP archive with password, please wait..."
    zip -P "$ZIP_PASS" -r -q "$BACKUP_FILE" "/opt/pasarguard" "/var/lib/pasarguard" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "------------------------------------------------"
        echo "Success! Local backup created."
        ls -lh "$BACKUP_FILE"
    else
        echo "Error: Backup failed."
    fi
    echo "------------------------------------------------"
    read -p "Press Enter to return to the menu..."
}

do_telegram_backup() {
    local is_auto="$1" # 1 for auto (cron), 0 for manual
    
    if [ -z "$TG_TOKEN" ] || [ -z "$TG_CHAT_ID" ] || [ -z "$BACKUP_PASS" ]; then
        if [ "$is_auto" -eq 0 ]; then
            echo "Error: Telegram is not configured or password is not set."
            echo "Please go to 'Telegram Settings' in the main menu first."
            read -p "Press Enter to return..."
        fi
        return 1
    fi

    if [ "$is_auto" -eq 0 ]; then
        echo "------------------------------------------------"
        echo "Starting Telegram Backup..."
    fi

    local TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    local TEMP_FILE="/tmp/pasarguard_backup_${TIMESTAMP}.zip"
    local FINAL_FILE="/root/pasarguard_backup_${TIMESTAMP}.zip"

    # Create zip with configured password
    zip -P "$BACKUP_PASS" -r -q "$TEMP_FILE" "/opt/pasarguard" "/var/lib/pasarguard" 2>/dev/null

    if [ $? -ne 0 ]; then
        send_telegram_message "❌ <b>Pasarguard Backup Failed!</b>\nServer: $(hostname)"
        [ "$is_auto" -eq 0 ] && read -p "Press Enter..."
        return 1
    fi

    local FILE_SIZE_MB=$(du -m "$TEMP_FILE" | cut -f1)
    local MSG_SUCCESS="✅ <b>Pasarguard Backup Successful!</b>\n📅 Time: $(date)\n💾 Size: ${FILE_SIZE_MB}MB\n🖥 Server: $(hostname)"

    # Telegram limit is 50MB, we use 45MB to be safe
    if [ "$FILE_SIZE_MB" -le 45 ]; then
        send_telegram_file "$TEMP_FILE" "Pasarguard Backup - $(date)"
        send_telegram_message "$MSG_SUCCESS\n📁 File sent to this chat."
        # Move to root for history, or just delete. Let's keep a small log or delete to save space.
        rm -f "$TEMP_FILE"
    else
        # File too large for Telegram API
        mv "$TEMP_FILE" "$FINAL_FILE"
        send_telegram_message "$MSG_SUCCESS\n⚠️ <b>Warning:</b> File is larger than 45MB and couldn't be sent via Telegram.\n📁 Saved locally at: $FINAL_FILE"
    fi

    if [ "$is_auto" -eq 0 ]; then
        echo "------------------------------------------------"
        echo "Success! Backup sent to Telegram (or saved locally if >45MB)."
        echo "------------------------------------------------"
        read -p "Press Enter to return to the menu..."
    fi
}

# ==========================================
# MENUS
# ==========================================

show_main_menu() {
    clear
    echo "================================================"
    echo "       Pasarguard Panel Management Tool         "
    echo "================================================"
    echo "  1) Backup Pasarguard Panel"
    echo "  2) Telegram & Auto-Backup Settings"
    echo "  3) Exit"
    echo "================================================"
    read -p "Please select an option [1-3]: " main_choice
}

show_backup_menu() {
    clear
    echo "================================================"
    echo "           Backup Pasarguard Panel              "
    echo "================================================"
    echo "  1) Local Backup (Save to /root/)"
    echo "  2) Auto Backup to Telegram"
    echo "  3) Back to Main Menu"
    echo "================================================"
    read -p "Please select an option [1-3]: " backup_choice
}

show_telegram_menu() {
    clear
    echo "================================================"
    echo "         Telegram & Auto-Backup Settings        "
    echo "================================================"
    echo "  Current Bot Token: ${TG_TOKEN:0:10}...${TG_TOKEN: -5}"
    echo "  Current Chat ID:   ${TG_CHAT_ID:-Not Set}"
    echo "  Backup Password:   ${BACKUP_PASS:+********}"
    echo "  Auto Interval:     Every ${BACKUP_INTERVAL:-Not Set} Hours"
    echo "------------------------------------------------"
    echo "  1) Set Bot Token"
    echo "  2) Set Chat ID"
    echo "  3) Set Default Backup Password"
    echo "  4) Set Auto-Backup Interval (Hours)"
    echo "  5) Test Connection & Send Success Message"
    echo "  6) Back to Main Menu"
    echo "================================================"
    read -p "Please select an option [1-6]: " tg_choice
}

# ==========================================
# MAIN LOGIC
# ==========================================

# Handle Auto-Backup via Cron (Hidden argument)
if [ "$1" == "--auto-backup" ]; then
    do_telegram_backup 1
    exit 0
fi

while true; do
    show_main_menu
    case $main_choice in
        1)
            while true; do
                show_backup_menu
                case $backup_choice in
                    1) do_local_backup ;;
                    2) do_telegram_backup 0 ;;
                    3) break ;;
                    *) echo "Invalid option." ; sleep 1 ;;
                esac
            done
            ;;
        2)
            while true; do
                show_telegram_menu
                case $tg_choice in
                    1) read -p "Enter Bot Token: " TG_TOKEN ; save_config ;;
                    2) read -p "Enter Chat ID: " TG_CHAT_ID ; save_config ;;
                    3) 
                        read -s -p "Enter Default Password for Telegram Backups: " BACKUP_PASS
                        echo
                        save_config 
                        ;;
                    4)
                        read -p "Enter interval in hours (e.g., 1, 6, 12, 24): " BACKUP_INTERVAL
                        if [[ "$BACKUP_INTERVAL" =~ ^[0-9]+$ ]] && [ "$BACKUP_INTERVAL" -gt 0 ]; then
                            # Remove old cron jobs for this script
                            crontab -l 2>/dev/null | grep -v "pasarguard --auto-backup" | crontab -
                            # Add new cron job
                            (crontab -l 2>/dev/null; echo "0 */$BACKUP_INTERVAL * * * $SCRIPT_PATH --auto-backup >> /var/log/pasarguard-backup.log 2>&1") | crontab -
                            save_config
                            echo "Cron job set successfully! Backup will run every $BACKUP_INTERVAL hours."
                        else
                            echo "Invalid number. Please enter a valid hour (e.g., 12)."
                        fi
                        read -p "Press Enter to continue..."
                        ;;
                    5)
                        if [ -z "$TG_TOKEN" ] || [ -z "$TG_CHAT_ID" ]; then
                            echo "Error: Please set Token and Chat ID first."
                        else
                            send_telegram_message "✅ <b>Setup Successful!</b>\nPasarguard Tool is connected to this chat.\n🖥 Server: $(hostname)"
                            echo "Success message sent to Telegram!"
                        fi
                        read -p "Press Enter to continue..."
                        ;;
                    6) break ;;
                    *) echo "Invalid option." ; sleep 1 ;;
                esac
            done
            ;;
        3)
            echo "Exiting Pasarguard Tool. Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid option. Please try again."
            sleep 1
            ;;
    esac
done
