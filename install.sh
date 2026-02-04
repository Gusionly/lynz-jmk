#!/bin/bash
# =========================================
# Pterodactyl Security Patch Installer
# Menu Version (Install / Restore)
# FULL FINAL FIXED VERSION
# =========================================

set -e

PANEL_DIR="/var/www/pterodactyl"
BASE_BACKUP_DIR="/var/backups/ptero-security"
TMP_DIR="/tmp/ptero-security"
ZIP_URL="https://raw.githubusercontent.com/USERNAME/REPO/main/security.zip"

# ===============================
# CHECK ROOT
# ===============================
if [ "$EUID" -ne 0 ]; then
  echo "[ERROR] Run as root!"
  exit 1
fi

# ===============================
# CHECK PANEL
# ===============================
if [ ! -d "$PANEL_DIR" ]; then
  echo "[ERROR] Pterodactyl panel not found!"
  exit 1
fi

# ===============================
# DEPENDENCIES
# ===============================
apt install -y wget unzip >/dev/null 2>&1

# ===============================
# FUNCTIONS
# ===============================
backup_file() {
  if [ -f "$1" ]; then
    mkdir -p "$BACKUP_DIR$(dirname "$1")"
    cp "$1" "$BACKUP_DIR$1"
  fi
}

clear_cache() {
  cd "$PANEL_DIR"
  php artisan view:clear
  php artisan config:clear
  php artisan route:clear
}

download_and_extract() {
  echo "[INFO] Downloading security.zip..."
  rm -rf "$TMP_DIR"
  mkdir -p "$TMP_DIR"
  cd "$TMP_DIR"

  if ! wget "$ZIP_URL" -O security.zip; then
    echo "[ERROR] Failed to download security.zip"
    exit 1
  fi

  if ! unzip -o security.zip >/dev/null; then
    echo "[ERROR] Failed to extract security.zip"
    exit 1
  fi

  # ===============================
  # VALIDATE FILES
  # ===============================
  REQUIRED_FILES=(
    "FileController.php"
    "ServerController.php"
    "UserController.php"
    "delete.blade.php"
    "new.blade.php"
    "view.blade.php"
    "nodes/index.blade.php"
    "settings/index.blade.php"
  )

  for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
      echo "[ERROR] Missing file in security.zip: $file"
      exit 1
    fi
  done

  echo "[INFO] security.zip validated successfully"
}

install_security() {
  BACKUP_DIR="$BASE_BACKUP_DIR/$(date +%Y%m%d-%H%M%S)"
  echo "[INFO] Creating backup at $BACKUP_DIR"
  mkdir -p "$BACKUP_DIR"

  download_and_extract

  echo "[INFO] Backing up original files..."
  backup_file "$PANEL_DIR/app/Http/Controllers/Api/Client/Servers/FileController.php"
  backup_file "$PANEL_DIR/app/Http/Controllers/Api/Application/Servers/ServerController.php"
  backup_file "$PANEL_DIR/app/Http/Controllers/Api/Application/Users/UserController.php"
  backup_file "$PANEL_DIR/resources/views/admin/servers/delete.blade.php"
  backup_file "$PANEL_DIR/resources/views/admin/users/new.blade.php"
  backup_file "$PANEL_DIR/resources/views/admin/users/view.blade.php"
  backup_file "$PANEL_DIR/resources/views/admin/nodes/index.blade.php"
  backup_file "$PANEL_DIR/resources/views/admin/settings/index.blade.php"

  echo "[INFO] Installing security patch..."
  cp FileController.php "$PANEL_DIR/app/Http/Controllers/Api/Client/Servers/FileController.php"
  cp ServerController.php "$PANEL_DIR/app/Http/Controllers/Api/Application/Servers/ServerController.php"
  cp UserController.php "$PANEL_DIR/app/Http/Controllers/Api/Application/Users/UserController.php"
  cp delete.blade.php "$PANEL_DIR/resources/views/admin/servers/delete.blade.php"
  cp new.blade.php "$PANEL_DIR/resources/views/admin/users/new.blade.php"
  cp view.blade.php "$PANEL_DIR/resources/views/admin/users/view.blade.php"
  cp nodes/index.blade.php "$PANEL_DIR/resources/views/admin/nodes/index.blade.php"
  cp settings/index.blade.php "$PANEL_DIR/resources/views/admin/settings/index.blade.php"

  chown -R www-data:www-data "$PANEL_DIR"

  echo "[INFO] Clearing cache..."
  clear_cache

  echo "====================================="
  echo "[SUCCESS] Security installed!"
  echo "[BACKUP] $BACKUP_DIR"
}

restore_security() {
  echo "=== AVAILABLE BACKUPS ==="
  ls -1 "$BASE_BACKUP_DIR" || {
    echo "[ERROR] No backup found!"
    exit 1
  }

  echo "Masukkan nama folder backup (contoh: 20260204-231845)"
  read -rp "> " RESTORE_DIR

  FULL_BACKUP_PATH="$BASE_BACKUP_DIR/$RESTORE_DIR"

  if [ ! -d "$FULL_BACKUP_PATH" ]; then
    echo "[ERROR] Backup not found!"
    exit 1
  fi

  echo "[INFO] Restoring backup..."
  cp -r "$FULL_BACKUP_PATH/var/www/pterodactyl/"* "$PANEL_DIR/"

  chown -R www-data:www-data "$PANEL_DIR"

  echo "[INFO] Clearing cache..."
  clear_cache

  echo "====================================="
  echo "[SUCCESS] Security removed (restored)"
}

# ===============================
# MENU
# ===============================
clear
echo "====================================="
echo " PTERODACTYL SECURITY INSTALLER"
echo "====================================="
echo "1) Pasang Security"
echo "2) Hapus Security (Restore Backup)"
echo "0) Keluar"
echo "====================================="
read -rp "Pilih menu : " MENU

case "$MENU" in
  1) install_security ;;
  2) restore_security ;;
  0) exit 0 ;;
  *) echo "[ERROR] Pilihan tidak valid!" ;;
esac
