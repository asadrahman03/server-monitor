#!/bin/bash

os=$(cat /etc/os-release | grep "^ID=" | cut -d'=' -f2)

if [ "$os" == "ubuntu" ]; then
    echo "Detected Ubuntu. Updating and installing packages..."
    sudo apt update -y
    sudo apt install -y nodejs npm curl ufw

    # Enable firewall rule for port 3901
    sudo ufw allow 3901/tcp
    sudo ufw reload
    sudo ufw enable

elif [ "$os" == "centos" ]; then
    echo "Detected CentOS. Updating and installing packages..."
    sudo yum update -y
    sudo yum install -y epel-release nodejs npm curl firewalld

    # Enable firewall rule for port 3901
    sudo systemctl start firewalld
    sudo systemctl enable firewalld
    sudo firewall-cmd --zone=public --add-port=3901/tcp --permanent
    sudo firewall-cmd --reload

else
    echo "Unsupported OS. Exiting."
    exit 1
fi

mkdir -p /home/$USER/sysinfo-api
cd /home/$USER/sysinfo-api

npm init -y
npm install express

cat <<EOF > index.js
const express = require('express');
const os = require('os');
const { networkInterfaces } = require('os');
const app = express();
const port = 3901;

function getServerIP() {
    const nets = networkInterfaces();
    let ip = 'Not found';
    for (const name of Object.keys(nets)) {
        for (const net of nets[name]) {
            if (net.family === 'IPv4' && !net.internal) {
                ip = net.address;
            }
        }
    }
    return ip;
}

app.get('/api/systeminfo', (req, res) => {
    const cpuUsage = os.loadavg()[0];
    const totalMemory = os.totalmem() / (1024 * 1024);
    const freeMemory = os.freemem() / (1024 * 1024);
    const usedMemory = totalMemory - freeMemory;
    const serverIP = getServerIP();

    res.json({
        cpuUsage: cpuUsage,
        totalMemoryMB: totalMemory.toFixed(2),
        usedMemoryMB: usedMemory.toFixed(2),
        freeMemoryMB: freeMemory.toFixed(2),
        serverIP: serverIP
    });
});

app.listen(port, () => {
    const serverIP = getServerIP();
    console.log(\`API is running on http://\${serverIP}:\${port}\`);
});
EOF

sudo npm install pm2 -g
pm2 start index.js
pm2 save
pm2 startup

server_ip=$(hostname -I | awk '{print $1}')
echo "API is set up and running on http://$server_ip:3901"
echo "Access the system information at http://$server_ip:3901/api/systeminfo"
