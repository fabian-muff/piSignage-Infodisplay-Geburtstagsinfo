# 📘 USB Auto-Copy on Raspberry Pi (Pisignage/Raspbian)

Automatically copy contents of `/copy` folder on any USB drive into `/home/<user>/media` when the drive is plugged in.

This solution uses:

* **udev** → detects USB insertion
* **systemd** → runs the copy script with proper permissions
* **bash script** → mounts USB, copies files, logs operations

This version is stable, safe, and works on any Linux system with systemd/udev (e.g. Raspberry Pi OS).

---

# 📂 Directory Structure Used

* USB stick must contain a folder: **`/copy`**
* Files from USB `/copy/*` → copied to **`/home/<user>/media/geburtstage`** (e.g. `/home/pi/media/geburtstage`)
* Existing files in the target directory are **not deleted**, only overwritten if names match.
* Logs stored at **`/var/log/usbcopy.log`**

---

# 🚀 Installation & Setup

You can either use the automated installer or set it up manually.

## 🤖 Automated Installation (Recommended)

1. Download or create the installer script on the device:
   ```bash
   nano install_usb_copy.sh
   # Paste content of install_usb_copy.sh here
   ```
2. Make it executable:
   ```bash
   chmod +x install_usb_copy.sh
   ```
3. Run it:
   ```bash
   sudo ./install_usb_copy.sh
   ```
   *The script automatically detects your user/home directory and sets up everything.*

---

## 🛠 Manual Installation

Follow these steps if you prefer to set it up manually. 
**Note:** valid for user `pi`. If your user is different, adjust paths accordingly.

### 1️⃣ Create the USB copy script

Create the main script:

```
sudo nano /usr/local/bin/usb_copy.sh
```

Paste the full script below: !!! adapt user pi to your user if pi is not right.

```bash
#!/bin/bash
# Script to copy files from /copy on USB to target directory

LOGFILE="/var/log/usbcopy.log"
DEVICE="$1"
MOUNTPOINT="/mnt/usb"
DEST_DIR="/home/pi/media/geburtstage"  # ADJUST IF NEEDED
TARGET_USER="pi"                       # ADJUST IF NEEDED
TARGET_GROUP="pi"                      # ADJUST IF NEEDED

log() {
    echo "$(date): $1" >> "$LOGFILE"
}

log "=== Script started ==="
log "Device argument: $DEVICE"

# Ensure mountpoint exists
mkdir -p "$MOUNTPOINT"

# Wait a moment for device to initialize
sleep 2

# Attempt to mount with partition (e.g., /dev/sda1)
/bin/mount "${DEVICE}1" "$MOUNTPOINT" 2>>"$LOGFILE"

# If failed, try mounting without partition (e.g., /dev/sda)
if [ $? -ne 0 ]; then
    log "Mounting partition failed. Trying raw device..."
    /bin/mount "$DEVICE" "$MOUNTPOINT" 2>>"$LOGFILE"
fi

# Check if mount succeeded
if mountpoint -q "$MOUNTPOINT"; then
    log "Mount successful at $MOUNTPOINT."

    # Check for /copy folder
    if [ -d "$MOUNTPOINT/copy" ]; then
        log "Found /copy folder. Starting file copy..."

        # Create destination if it doesn't exist
        mkdir -p "$DEST_DIR"
        
        # Copy files
        cp -rf "$MOUNTPOINT/copy/"* "$DEST_DIR" 2>>"$LOGFILE"
        
        if [ $? -eq 0 ]; then
            log "File copy completed."
            
            # Fix permissions for the target user
            chown -R $TARGET_USER:$TARGET_GROUP "$DEST_DIR"
            chmod -R 755 "$DEST_DIR"
            log "Permissions updated for user: $TARGET_USER"
        else
            log "ERROR: File copy encountered issues."
        fi
    else
        log "No /copy directory found on USB."
    fi

    log "Syncing and Unmounting..."
    sync
    /bin/umount "$MOUNTPOINT"
else
    log "ERROR: Mount failed. Cannot continue."
fi

log "=== Finished ==="
```

Make it executable:

```
sudo chmod +x /usr/local/bin/usb_copy.sh
```

---

## 2️⃣ Create the systemd service template

Create:

```
sudo nano /etc/systemd/system/usbcopy@.service
```

Paste:

```ini
[Unit]
Description=USB Copy Handler

[Service]
Type=oneshot
ExecStart=/usr/local/bin/usb_copy.sh /dev/%i
```

---

## 3️⃣ Create the udev rule that triggers the systemd service

Create:

```
sudo nano /etc/udev/rules.d/99-usbcopy.rules
```

Paste:

```udev
KERNEL=="sd[a-z]", SUBSYSTEM=="block", ACTION=="add", \
    RUN+="/bin/systemctl start usbcopy@%k.service"
```

---

## 4️⃣ Reload and activate

Reload udev rules:

```
sudo udevadm control --reload-rules
```

Reload systemd:

```
sudo systemctl daemon-reload
```

No reboot required — the system is now active.

---


## ✅ Create the target directory

Create the destination and set ownership/permissions: replace pi with your user if pi is not your user.

```bash
mkdir -p /home/pi/media/geburtstage
# No sudo needed if running as user pi, otherwise use sudo chown
```

Verify:

```bash
ls -ld /home/pi/media/geburtstage
```


# 🧪 Testing the Setup

1. Prepare a USB stick with:

   ```
   /copy/
       profile_photo_user1.jpg
       profile_photo_user2.jpg
       geburtstage.xlsx
   ```

2. Plug the USB stick into the Raspberry Pi.

3. Expected behavior:

* System detects USB
* Script runs automatically
* USB is mounted under `/mnt/usb`
* Files inside `/copy` are copied to `/home/<user>/media/geburtstage`
* Permissions are fixed so user `<user>`, (e.g., pi)  can access them
* USB is unmounted
* Log entry written in `/var/log/usbcopy.log`

4. Check logs:

```
cat /var/log/usbcopy.log
```

---

# 🔍 Troubleshooting

### ❌ USB does not mount

Check log:

```
tail -n 50 /var/log/usbcopy.log
```

Likely causes:

* Filesystem unsupported
* USB slow → increase wait time (change `sleep 2` to `sleep 4`)
* USB inserted into hub without enough power

---

### ❌ Script runs twice

Udev sometimes fires multiple events on some Pis.
We can add a debounce rule if needed.

---

### ❌ USB not detected at all

Check rule syntax:

```
sudo udevadm test /sys/block/sda
```

---

# 📦 Uninstall

To disable:

```
sudo rm /etc/udev/rules.d/99-usbcopy.rules
sudo systemctl daemon-reload
```

Optional remove script:

```
sudo rm /usr/local/bin/usb_copy.sh
```

---

# 🎉 Summary

After completing this setup:

✔ USB drive insertion triggers the script automatically
✔ `/copy/*` is copied to `/home/<user>/media/geburtstage`
✔ Existing files are overwritten
✔ Permissions are automatically fixed
✔ Works reliably with Pisignage/Raspbian
