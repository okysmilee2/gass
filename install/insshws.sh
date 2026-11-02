#!/bin/bash
# Proxy For Edukasi & Imclass
file_path="/etc/handeling"

# Cek apakah file ada
if [ ! -f "$file_path" ]; then
    # Jika file tidak ada, buat file dan isi dengan dua baris
    echo -e "TOKO FAIZ CONNECTED\nGreen" | sudo tee "$file_path" > /dev/null
    echo "File '$file_path' berhasil dibuat."
else
    # Jika file ada, cek apakah isinya kosong
    if [ ! -s "$file_path" ]; then
        # Jika file ada tetapi kosong, isi dengan dua baris
        echo -e "TOKO FAIZ COONECTED\nGreen" | sudo tee "$file_path" > /dev/null
        echo "File '$file_path' kosong dan telah diisi."
    else
        # Jika file ada dan berisi data, tidak lakukan apapun
        echo "File '$file_path' sudah ada dan berisi data."
    fi
fi
# Link Hosting Kalian
sudo apt install python3

wget -O /usr/local/bin/ws "https://raw.githubusercontent.com/diah082/vip/main/sshws/ws"
wget -O /usr/local/bin/config.conf "https://raw.githubusercontent.com/diah082/vip/main/sshws/config.conf"
chmod +x /usr/local/bin/ws

# Installing Service
cat > /etc/systemd/system/ws.service << END
[Unit]
Description=Proxy Mod By Newbie Store 
Documentation=https://t.me/newbie_store24
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
NoNewPrivileges=true
ExecStart=/usr/local/bin/ws -f /usr/local/bin/config.conf
Restart=on-failure

[Install]
WantedBy=multi-user.target
END

systemctl daemon-reload
systemctl enable ws.service
systemctl start ws.service
systemctl restart ws.service
rm insshws.sh
