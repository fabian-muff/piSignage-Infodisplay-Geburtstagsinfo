#!/bin/bash

# ==============================================================================
# AUTOMATED INSTALLER: USB Auto-Copy (Generic User Version)
# ==============================================================================

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root. Please run with sudo." 
   exit 1
fi

# --- 1️⃣ Detect the actual user behind sudo ---
# If run via sudo, SUDO_USER is set. Otherwise, use current user (root).
ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_GROUP=$(id -gn "$ACTUAL_USER")

# Get the home directory of that user (safer than assuming /home/$USER)
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)

echo "🚀 Starting installation..."
echo "👤 Target User:  $ACTUAL_USER"
echo "🏠 Target Home:  $ACTUAL_HOME"

# --- Configuration Variables ---
SCRIPT_PATH="/usr/local/bin/usb_copy.sh"
SERVICE_PATH="/etc/systemd/system/usbcopy@.service"
RULE_PATH="/etc/udev/rules.d/99-usbcopy.rules"
# We now use the detected home directory
TARGET_DIR="${ACTUAL_HOME}/media/geburtstage"
LOG_FILE="/var/log/usbcopy.log"

# ------------------------------------------------------------------------------
# 2️⃣ Create the USB copy script
# ------------------------------------------------------------------------------
echo "📝 Creating main script at $SCRIPT_PATH..."

# NOTE: We use unquoted EOF to allow expanding variables like $TARGET_DIR.
# We must escape internal script variables (like \$1, \$?) with a backslash.

cat << EOF > "$SCRIPT_PATH"
#!/bin/bash
# Script to copy files from /copy on USB to $TARGET_DIR

LOGFILE="$LOG_FILE"
DEVICE="\$1"
MOUNTPOINT="/mnt/usb"
DEST_DIR="$TARGET_DIR"
TARGET_USER="$ACTUAL_USER"
TARGET_GROUP="$ACTUAL_GROUP"

log() {
    echo "\$(date): \$1" >> "\$LOGFILE"
}

log "=== Script started ==="
log "Device argument: \$DEVICE"

# Ensure mountpoint exists
mkdir -p "\$MOUNTPOINT"

# Wait a moment for device to initialize
sleep 2

# Attempt to mount with partition (e.g., /dev/sda1)
/bin/mount "\${DEVICE}1" "\$MOUNTPOINT" 2>>"\$LOGFILE"

# If failed, try mounting without partition (e.g., /dev/sda)
if [ \$? -ne 0 ]; then
    log "Mounting partition failed. Trying raw device..."
    /bin/mount "\$DEVICE" "\$MOUNTPOINT" 2>>"\$LOGFILE"
fi

# Check if mount succeeded
if mountpoint -q "\$MOUNTPOINT"; then
    log "Mount successful at \$MOUNTPOINT."

    # Check for /copy folder
    if [ -d "\$MOUNTPOINT/copy" ]; then
        log "Found /copy folder. Starting file copy..."

        # Create destination if it doesn't exist
        mkdir -p "\$DEST_DIR"
        
        # Copy files
        cp -rf "\$MOUNTPOINT/copy/"* "\$DEST_DIR" 2>>"\$LOGFILE"
        
        if [ \$? -eq 0 ]; then
            log "File copy completed."
            
            # Fix permissions for the target user (Dynamic)
            chown -R \$TARGET_USER:\$TARGET_GROUP "\$DEST_DIR"
            chmod -R 755 "\$DEST_DIR"
            log "Permissions updated for user: \$TARGET_USER"
        else
            log "ERROR: File copy encountered issues."
        fi
    else
        log "No /copy directory found on USB."
    fi

    log "Syncing and Unmounting..."
    sync
    /bin/umount "\$MOUNTPOINT"
else
    log "ERROR: Mount failed. Cannot continue."
fi

log "=== Finished ==="
EOF

# Make executable
chmod +x "$SCRIPT_PATH"
echo "✅ Script created and made executable."

# ------------------------------------------------------------------------------
# 3️⃣ Create the systemd service template
# ------------------------------------------------------------------------------
echo "⚙️ Creating systemd service at $SERVICE_PATH..."

cat <<EOF > "$SERVICE_PATH"
[Unit]
Description=USB Copy Handler

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH /dev/%i
EOF

echo "✅ Systemd service created."

# ------------------------------------------------------------------------------
# 4️⃣ Create the udev rule
# ------------------------------------------------------------------------------
echo "🔌 Creating udev rule at $RULE_PATH..."

cat <<EOF > "$RULE_PATH"
KERNEL=="sd[a-z]", SUBSYSTEM=="block", ACTION=="add", \\
    RUN+="/bin/systemctl start usbcopy@%k.service"
EOF

echo "✅ Udev rule created."

# ------------------------------------------------------------------------------
# 5️⃣ Create directories and set permissions
# ------------------------------------------------------------------------------
echo "📂 Setting up target directory..."

# Create target directory
mkdir -p "$TARGET_DIR"

# Set ownership to the detected real user
chown -R "$ACTUAL_USER:$ACTUAL_GROUP" "${ACTUAL_HOME}/media"
chmod -R 755 "$TARGET_DIR"
echo "✅ Directory $TARGET_DIR configured for user '$ACTUAL_USER'."

# Initialize log file
touch "$LOG_FILE"
chmod 666 "$LOG_FILE"

# ------------------------------------------------------------------------------
# 6️⃣ Reload and Activate
# ------------------------------------------------------------------------------
echo "🔄 Reloading system daemons..."

udevadm control --reload-rules
systemctl daemon-reload

echo "========================================================"
echo "🎉 Installation Complete!"
echo "--------------------------------------------------------"
echo "1. Prepare a USB stick with a folder named '/copy'."
echo "2. Put files inside that folder."
echo "3. Plug it in."
echo "4. Files will be copied to: $TARGET_DIR"
echo "5. Check logs with: cat $LOG_FILE"
echo "========================================================"