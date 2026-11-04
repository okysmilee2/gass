#!/bin/bash
# Update hanya file script menu, tanpa menyentuh service VPN (nginx/haproxy)
# Deploy ke /usr/local/sbin sesuai setup-main.sh (bukan /usr/bin).
DEST=/usr/local/sbin
echo "Sedang mengunduh pembaruan skrip..."
wget -qO /tmp/update.zip "https://github.com/okysmilee2/gass/main/install/menu.zip"
if [ $? -ne 0 ]; then
    echo "Gagal mengunduh menu.zip. Abort (layanan VPN aman)."
    rm -f /tmp/update.zip
    exit 1
fi
rm -rf /tmp/menu-extracted
mkdir -p /tmp/menu-extracted

# Cek alat ekstraksi yang tersedia (Prioritas 7z/7zz karena menggunakan password terenkripsi)
if command -v 7z >/dev/null 2>&1; then
    7z x -pDswara123 /tmp/update.zip -o/tmp/menu-extracted/ -y >/dev/null 2>&1
elif command -v 7zz >/dev/null 2>&1; then
    7zz x -pDswara123 /tmp/update.zip -o/tmp/menu-extracted/ -y >/dev/null 2>&1
else
    if ! command -v unzip >/dev/null 2>&1; then
        echo "Alat ekstraksi tidak ditemukan, menginstall p7zip/unzip..."
        apt-get update -y >/dev/null 2>&1
        apt-get install -y p7zip-full unzip >/dev/null 2>&1 || apt install -y p7zip-full unzip >/dev/null 2>&1
    fi
    # Fallback ke unzip (jika file zip tidak berpassword)
    unzip -q -o /tmp/update.zip -d /tmp/menu-extracted/ >/dev/null 2>&1
fi

if [ ! -f /tmp/menu-extracted/menu/menu ]; then
    echo "Ekstraksi gagal (menu/menu tidak ditemukan). Abort."
    rm -rf /tmp/update.zip /tmp/menu-extracted
    exit 1
fi

chmod +x /tmp/menu-extracted/menu/*
mkdir -p "$DEST"
cp -f /tmp/menu-extracted/menu/* "$DEST/"

# Self-update: pastikan versi terbaru script ini ikut tersebar ke VPS lama
wget -qO "$DEST/update1.sh" "https://raw.githubusercontent.com/okysmilee2/gass/main/update1.sh" >/dev/null 2>&1 || true
chmod +x "$DEST/update1.sh" 2>/dev/null || true

rm -rf /tmp/update.zip /tmp/menu-extracted
echo "Update skrip berhasil! Layanan VPN tetap aman."
