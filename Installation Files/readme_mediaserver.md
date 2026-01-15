# 📘 Python Media File Server (Flask)

Lightweight HTTP file server to expose `/home/pi/media/geburtstage` to local web applications (Pisignage/Browser).

This solution uses:

- **Python Flask** — lightweight web server framework
- **Flask-CORS** — allows access from local HTML files without CORS errors
- **systemd** — ensures the server starts automatically on boot
- **venv** — isolates Python dependencies in a dedicated virtual environment

This guide describes a small server intended to run on a Raspberry Pi alongside Pisignage.

---

## 📂 Directory layout

- Source folder (served): `/home/pi/media/geburtstage`
- Project folder: `/home/pi/media_server`
- Python script: `/home/pi/media_server/file_server.py`
- Virtual environment: `/home/pi/media_server/venv`
- Default port: `5000`
- Endpoints:
  - `GET /list-files` — returns JSON array of filenames
  - `GET /files/<filename>` — serves the file content

---
# 🚀 Installation & Setup

You can either use the automated installer or set it up manually.

## 🤖 Automated Installation (Recommended)
Die Installation kann automatisiert werden:
- Erstelle eine neue Datei auf dem Pi: 
```bash
nano install_mediaserver.sh
```
- Füge den Inhalt aus install_mediaserver.sh ein.
- Skript ausführbar machen
```bash
chmod +x install_mediaserver.sh
```
- Skript starten:
```bash
./install_mediaserver.sh
```
## 🚀 Manual installation

Follow the steps below on the Raspberry Pi (Raspbian / Raspberry Pi OS).

### 1. Install dependencies

Run the following commands to install Python 3, pip, and the venv module:

```bash
sudo apt update
sudo apt install -y python3-pip python3-venv
```

### 2. Set up the environment

Create the project folder, set up the virtual environment, and install the Flask libraries.

```bash
# Create project folder
mkdir -p /home/pi/media_server
cd /home/pi/media_server

# Create virtual environment (hidden folder 'venv')
python3 -m venv venv

# Activate environment
source venv/bin/activate

# Update Pip
pip install --upgrade pip

# Install libraries inside the environment
pip install flask flask-cors waitress
```

### 3. Create the Python server script

Create `/home/pi/media_server/file_server.py` (edit with `nano` or your preferred editor) and paste the following:

```python
import os
from flask import Flask, send_from_directory, jsonify
from flask_cors import CORS
from waitress import serve  # Production Server

app = Flask(__name__)
CORS(app)

# --- KONFIGURATION ---
# Ermittelt dynamisch das Home-Verzeichnis des aktuellen Users
HOME_DIR = os.path.expanduser("~")
# Pfad relativ zum Home bauen -> Funktioniert für User 'pi', 'admin', etc.
MEDIA_DIR = os.path.join(HOME_DIR, "media", "geburtstage")
PORT = 5000
# ---------------------

@app.route('/list-files')
def list_files():
    """Gibt eine JSON-Liste der Dateien zurück."""
    try:
        if not os.path.exists(MEDIA_DIR):
            return jsonify({"error": f"Directory not found: {MEDIA_DIR}"}), 404
        
        # Listet nur Dateien auf, ignoriert versteckte Dateien (starten mit .)
        files = [
            f for f in os.listdir(MEDIA_DIR)
            if os.path.isfile(os.path.join(MEDIA_DIR, f)) and not f.startswith('.')
        ]
        # Optional: Alphabetisch sortieren für konsistente Anzeige
        files.sort()
        return jsonify(files)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/files/<path:filename>')
def get_file(filename):
    """Liefert die Datei aus."""
    return send_from_directory(MEDIA_DIR, filename)

if __name__ == '__main__':
    print(f"🚀 Server startet auf Port {PORT} und serviert: {MEDIA_DIR}")
    # Waitress nutzen statt app.run() für Stabilität
    serve(app, host='0.0.0.0', port=PORT)
```

Save and exit.

### 4. Create a systemd service

Create `/etc/systemd/system/mediaserver.service` with the following content (requires root).
Note the use of the `venv` python executable in `ExecStart`.

```ini
[Unit]
Description=Python Media File Server
# Wartet, bis wirklich eine IP zugewiesen wurde
Wants=network-online.target
After=network-online.target

[Service]
# Ändere 'pi' hier, falls der User auf dem neuen System anders heisst!
User=pi
Group=pi

# Dynamischere Pfadstruktur ist in Systemd schwierig, 
# daher müssen hier absolute Pfade bleiben.
WorkingDirectory=/home/pi/media_server
ExecStart=/home/pi/media_server/venv/bin/python /home/pi/media_server/file_server.py

# Automatischer Neustart bei Absturz
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Reload systemd and enable the service to start at boot:

```bash
sudo systemctl daemon-reload
sudo systemctl enable mediaserver.service
sudo systemctl start mediaserver.service
```

---

## 🧪 Testing

Ensure there are files in `/home/pi/media/geburtstage` (for example images copied from the USB copy script). Then test:

```bash
curl http://localhost:5000/list-files
```

Expected: JSON array of filenames, e.g.:

```json
["photo1.jpg", "list.xlsx"]
```

Open a served file in a browser:

`http://<pi-ip or localhost>:5000/files/your-image-name.jpg`

---

## 🔍 Troubleshooting

- "Address already in use":

```bash
sudo lsof -i :5000
```

Change `PORT` in `/home/pi/media_server/file_server.py` if needed.

- Service fails to start: check logs

```bash
journalctl -u mediaserver.service -f
```

- Browser blocks access (CORS): make sure `CORS(app)` is present in the Python script.

## 📦 Uninstall / disable

```bash
sudo systemctl stop mediaserver.service
sudo systemctl disable mediaserver.service
sudo rm -r /home/pi/media_server
sudo systemctl daemon-reload
```

---

## ✅ Summary

- Server listens on port 5000 by default
- `GET /list-files` returns a JSON list of media files
- `GET /files/<filename>` serves the files
- Works with the USB auto-copy script used by this project





