## Docker Homelab Setup

### Install Debian as barebones server (no root, only sudo)

Optional proxy url: https://golden-centaur-20b77e.netlify.app/

### Configure server

```bash
# set timezone
sudo timedatectl set-timezone Asia/Manila

# install packages
sudo apt update
sudo apt install cockpit tlp vim git curl upower ncdu

# enable power saving
sudo systemctl enable powertop --now
sudo systemctl enable tlp --now

# add lines to .bashrc
alias v="vim"
alias compose="cd /home/$USER/docker-homelab && vim compose.yaml"
alias bat='upower -i /org/freedesktop/UPower/devices/battery_BAT0| grep -E "state|to full|percentage"'
alias wbat='watch upower -i /org/freedesktop/UPower/devices/battery_BAT0'
alias .bashrc="nvim /home/$USER/.bashrc"
alias dockerup="cd /home/$USER/docker-homelab && docker compose up -d"
alias ncdu="cd / && sudo ncdu"
#alias code="docker exec ubuntu /bin/bash -c code-server"
bat

# edit logind.conf
echo 'HandlePowerKey=suspend' | sudo tee -a /etc/systemd/logind.conf
echo 'HandleSuspendKey=suspend' | sudo tee -a /etc/systemd/logind.conf
echo 'HandleHibernateKey=suspend' | sudo tee -a /etc/systemd/logind.conf
echo 'HandleLidSwitch=ignore' | sudo tee -a /etc/systemd/logind.conf
echo 'HandleLidSwitchExternalPower=ignore' | sudo tee -a /etc/systemd/logind.conf
echo 'HandleLidSwitchDocked=ignore' | sudo tee -a /etc/systemd/logind.conf
sudo systemctl restart systemd-logind

# set static ip
sudo cp /etc/network/interfaces ~/interfaces.bak
sudo vim /etc/network/interfaces # remove dhcp and allow-hotplug line, change to auto [interface]
sudo systemctl restart networking

# update grub
sudo sed -i -E 's/^GRUB_CMDLINE_LINUX_DEFAULT=/#GRUB_CMDLINE_LINUX_DEFAULT=/' /etc/default/grub
echo 'GRUB_CMDLINE_LINUX_DEFAULT="consoleblank=120"' | sudo tee -a /etc/default/grub
sudo update-grub
```

### Secure server

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

# disable bash history
sed -i -E 's/^HISTSIZE=/#HISTSIZE=/' ~/.bashrc
sed -i -E 's/^HISTFILESIZE=/#HISTFILESIZE=/' ~/.bashrc
echo "HISTFILESIZE=0" >> ~/.bashrc
history -c; history -w
source ~/.bashrc

# secure ssh
mkdir /home/$USER/.ssh
#sed -i -E 's/^(#)?Port 22/Port 9/' /etc/ssh/sshd_config
sudo sed -i -E 's/^(#)?PermitRootLogin (prohibit-password|yes)/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i -E 's/^(#)?PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh

# configure sysctl for IPv4-only network
sudo cp /etc/sysctl.conf /etc/sysctl.conf.backup
sudo cat << "EOF" >> /etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
sudo sysctl -p

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
```

### Install Docker Engine

```bash
# clean install preparation 
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg; done
sudo apt-get purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd

# preview
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh ./get-docker.sh --dry-run

# final
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

### Host server applications

```bash
git config --global user.name "ken"
git config --global user.email "ken@homelab.com"
git clone https://github.com/devken0/docker-homelab.git
```

### Setup Samba

---

Credits

https://sunknudsen.com/privacy-guides
https://sunknudsen.com/privacy-guides/how-to-configure-hardened-debian-server
https://www.cyberciti.biz/faq/add-configure-set-up-static-ip-address-on-debianlinux/
