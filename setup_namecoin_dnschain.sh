#!/usr/bin/bash

# Install mandatory packets
yum -y install nodejs npm coffee-script vim htop git
cd /etc/yum.repos.d/
wget http://download.opensuse.org/repositories/home:p_conrad:coins/Fedora_21/home:p_conrad:coins.repo
yum -y install namecoin
cd
npm install -g dnschain
npm update -g dnschain
npm update -g coffee-script

# Setup system users namecoin and dnschain
useradd namecoin
useradd dnschain

runuser namecoin -c "mkdir /home/namecoin/.namecoin"
runuser dnschain -c "mkdir /home/dnschain/.dnschain"


# Create dnschain configuration file
cat << EOF > /usr/lib/systemd/system/dnschain.service
[Unit]
Description=dnschain
After=network.target
Wants=namecoin.service

[Service]
ExecStart=/usr/bin/dnschain
Environment=DNSCHAIN_SYSD_VER=0.0.1
PermissionsStartOnly=true
ExecStartPre=/sbin/sysctl -w net.ipv4.ip_forward=1
ExecStartPre=-/sbin/iptables -D INPUT -p udp --dport 5333 -j ACCEPT
ExecStartPre=-/sbin/iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5333
ExecStartPre=/sbin/iptables -A INPUT -p udp --dport 5333 -j ACCEPT
ExecStartPre=/sbin/iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5333
ExecStopPost=/sbin/iptables -D INPUT -p udp --dport 5333 -j ACCEPT
ExecStopPost=/sbin/iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5333
User=dnschain
Group=dnschain
Restart=always
RestartSec=5
WorkingDirectory=/home/dnschain
PrivateTmp=true
NoNewPrivileges=true
ReadOnlyDirectories=/etc


[Install]
WantedBy=multi-user.target
EOF

# Create namecoin configuration file
cat << EOF > /usr/lib/systemd/system/namecoin.service
[Unit]
Description=namecoin
After=network.target

[Service]
Type=forking
ExecStart=/usr/bin/namecoind
User=namecoin
Group=namecoin
WorkingDirectory=/home/namecoin

[Install]
WantedBy=multi-user.target


EOF

#Create namecoin configuration files
cat << EOF > /home/namecoin/.namecoin/namecoin.conf
rpcuser=dnschain
rpcpassword=9YCoZbajhHv4kqnwoeoqjuxtAikqjvhbQvtrWFtvH5h
rpcport=8336
daemon=1

EOF

#Create dnschain configuration files

cat << EOF > /home/dnschain/.dnschain/dnschain.conf
[namecoin]
config = /home/namecoin/.namecoin/namecoin.conf

[log]
level=info

[dns]
port = 5333
# no quotes around IP
oldDNS.address = 8.8.8.8

# disable traditional DNS resolution (default is NATIVE_DNS)
oldDNSMethod = NO_OLD_DNS

[http]
port=8088
tlsPort=4443

EOF

# Security corrections 
chcon -u system_u /usr/lib/systemd/system/{dnschain,namecoin}.service 

chown -R dnschain:dnschain /home/dnschain
chown -R namecoin:namecoin /home/namecoin

# adjust permission on namecoin home directory to permit dnschain access to it
chmod o+r /home/namecoin
chmod o+rwx -R /home/namecoin/.namecoin


systemctl enable dnschain
systemctl enable namecoin

systemctl start dnschain
systemctl start namecoin

# Hourra! Everything should be okay by now, let's test that

dig @localhost -p 5333 okturtles.bit

# This last command should print a message similar to this one : 
#
# ; <<>> DiG 9.9.6-RedHat-9.9.6-4.fc21 <<>> @localhost -p 5333 okturtles.bit
# ; (2 servers found)
# ;; global options: +cmd
# ;; Got answer:
# ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 27695
# ;; flags: qr rd; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 0
# ;; WARNING: recursion requested but not available
# 
# ;; QUESTION SECTION:
# ;okturtles.bit.                 IN      A
# 
# ;; ANSWER SECTION:
# okturtles.bit.          600     IN      A       192.184.93.146
# 
# ;; Query time: 251 msec
# ;; SERVER: 127.0.0.1#5333(127.0.0.1)
# ;; WHEN: mer. mai 06 15:54:49 CEST 2015
# ;; MSG SIZE  rcvd: 47
