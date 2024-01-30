## Docker Homelab Setup

1. Install Debian as barebones server (no root, only sudo)

Optional proxy url: https://golden-centaur-20b77e.netlify.app/

2. Configure server

```bash
# set timezone
sudo timedatectl set-timezone Asia/Manila

# install packages
sudo apt update
sudo apt install cockpit tlp vim git curl

# enable power saving
sudo systemctl enable powertop --now
sudo systemctl enable tlp --now

# add lines to .bashrc

# edit logind.conf

# set static ip


```

3. Secure server

### Secure SSH

On client/pc:

```bash
# generate 32 characters random passphrase for ssh key passphrase
openssl rand -base64 24

# windows
ssh-keygen -t ed25519 -f $HOME\.ssh\id_ed25519

# linux
ssh-keygen -t ed25519

# create ~/.ssh/config
Host server-hostname
  Hostname ip addr
  User username
```

On server:

```bash
# update server
sudo apt-get update && sudo apt dist-upgrade

# secure ssh
#sed -i -E 's/^(#)?Port 22/Port 9/' /etc/ssh/sshd_config
sed -i -E 's/^(#)?PermitRootLogin (prohibit-password|yes)/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i -E 's/^(#)?PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh

# enable and configure firewall
sudo apt install nftables
sudo systemctl enable nftables --now

# set firewall rules
sudo nft flush ruleset
sudo nft add table ip firewall
sudo nft add chain ip firewall input { type filter hook input priority 0 \; policy drop \; }
sudo nft add rule ip firewall input iif lo accept
sudo nft add rule ip firewall input iif != lo ip daddr 127.0.0.0/8 drop
sudo nft add rule ip firewall input tcp dport ssh accept
sudo nft add rule ip firewall input ct state established,related accept
sudo nft add chain ip firewall forward { type filter hook forward priority 0 \; policy drop \; }
sudo nft add chain ip firewall output { type filter hook output priority 0 \; policy drop \; }
sudo nft add rule ip firewall output oif lo accept
sudo nft add rule ip firewall output tcp dport { http, https } accept
sudo nft add rule ip firewall output udp dport { domain, ntp } accept
sudo nft add rule ip firewall output ct state established,related accept

# for ipv4 only network
sudo nft add table ip6 firewall
sudo nft add chain ip6 firewall input { type filter hook input priority 0 \; policy drop \; }
sudo nft add chain ip6 firewall forward { type filter hook forward priority 0 \; policy drop \; }
sudo nft add chain ip6 firewall output { type filter hook output priority 0 \; policy drop \; }

# make rules persistent
sudo cat << "EOF" > /etc/nftables.conf
#!/usr/sbin/nft -f

flush ruleset

EOF

sudo nft list ruleset >> /etc/nftables.conf

# disable bash history
sed -i -E 's/^HISTSIZE=/#HISTSIZE=/' ~/.bashrc
sed -i -E 's/^HISTFILESIZE=/#HISTFILESIZE=/' ~/.bashrc
echo "HISTFILESIZE=0" >> ~/.bashrc
history -c; history -w
source ~/.bashrc
```

4. Install Docker Engine

5. Host server applications

6. Setup Samba

## Credits

https://sunknudsen.com/privacy-guides
https://sunknudsen.com/privacy-guides/how-to-configure-hardened-debian-server