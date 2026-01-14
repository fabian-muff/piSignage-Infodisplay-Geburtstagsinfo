#!/bin/bash

# ==========================================
# Automated Installer for Python Media Server
# ==========================================

# Exit immediately if a command exits with a non-zero status
set -e

# --- Configuration ---
CURRENT_USER=$USER
CURRENT_GROUP=$(id -gn)
HOME_DIR=$HOME
PROJECT_DIR="$HOME_DIR/media_server"
MEDIA_DIR="$HOME_DIR/media/geburtstage"
SERVICE_NAME="mediaserver.service"

# --- Checks ---
if [ "$EUID" -eq 0 ]; then
  echo "❌ Please do not run this script as root (sudo)."
  echo "   Run it as your normal user. The script will ask for sudo password when needed."
  exit 1
fi

echo "🚀 Starting installation for user: $CURRENT_USER"

# 1. Update and Install System Dependencies
echo "📦 Installing system dependencies..."
sudo apt update
sudo apt install -y python3-pip python3-venv

# 2. Create Directory Structure
echo "📂 Creating directories..."
mkdir -p "$PROJECT_DIR"
mkdir -p "$MEDIA_DIR"
echo "   - Project: $PROJECT_DIR"
echo "   - Media:   $MEDIA_DIR"

# 3. Setup Virtual Environment
echo "🐍 Setting up Python Virtual Environment..."
if [ ! -d "$PROJECT_DIR/venv" ]; then
    python3 -m venv "$PROJECT_DIR/venv"
fi

# Upgrade pip and install libraries
"$PROJECT_DIR/venv/bin/pip" install --upgrade pip
"$PROJECT_DIR/venv/bin/pip" install flask flask-cors waitress

# 4. Create Python Script (file_server.py)
echo "📝 Writing Python server script..."
cat << EOF > "$PROJECT_DIR/file_server.py"
import os
from flask import Flask, send_from_directory, jsonify
from flask_cors import CORS
from waitress import serve

app = Flask(__name__)
CORS(app)

# --- CONFIGURATION ---
# Dynamically determine user home directory
HOME_DIR = os.path.expanduser("~")
MEDIA_DIR = os.path.join(HOME_DIR, "media", "geburtstage")
PORT = 5000
# ---------------------

@app.route('/list-files')
def list_files():
    """Returns a JSON list of filenames."""
    try:
        if not os.path.exists(MEDIA_DIR):
            return jsonify({"error": f"Directory not found: {MEDIA_DIR}"}), 404
        
        # List files only, ignore hidden files (starting with .)
        files = [
            f for f in os.listdir(MEDIA_DIR)
            if os.path.isfile(os.path.join(MEDIA_DIR, f)) and not f.startswith('.')
        ]
        files.sort()
        return jsonify(files)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/files/<path:filename>')
def get_file(filename):
    """Serves the requested file."""
    return send_from_directory(MEDIA_DIR, filename)

if __name__ == '__main__':
    print(f"🚀 Server starting on port {PORT}, serving: {MEDIA_DIR}")
    serve(app, host='0.0.0.0', port=PORT)
EOF

# 5. Create Systemd Service
echo "⚙️ Creating Systemd service..."

# Create a temporary service file with dynamic paths
cat << EOF > "/tmp/$SERVICE_NAME"
[Unit]
Description=Python Media File Server
Wants=network-online.target
After=network-online.target

[Service]
User=$CURRENT_USER
Group=$CURRENT_GROUP
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/venv/bin/python $PROJECT_DIR/file_server.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Move to systemd directory (requires sudo)
sudo mv "/tmp/$SERVICE_NAME" "/etc/systemd/system/$SERVICE_NAME"

# 6. Enable and Start Service
echo "🔌 Enabling and starting service..."
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME
sudo systemctl restart $SERVICE_NAME

echo ""
echo "✅ Installation complete!"
echo "---------------------------------------------------"
echo "📂 Media Folder: $MEDIA_DIR"
echo "🌐 Test URL:     http://localhost:5000/list-files"
echo "📜 Check Logs:   journalctl -u $SERVICE_NAME -f"
echo "---------------------------------------------------"