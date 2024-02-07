## Docker Homelab Setup

### Install Debian as barebones server (no root, only sudo) / Ubuntu Server

Optional proxy url: https://golden-centaur-20b77e.netlify.app/

### Configure server

```bash
# set timezone
sudo timedatectl set-timezone Asia/Manila

# change password
passwd

# set hosts
sudo sed -i -E 's/^127.0.1.1./#127.0.1.1/' /etc/hosts
echo '127.0.1.1     homesc3.duckdns.org     sc3' | sudo tee -a /etc/hosts

# install packages
sudo apt update
sudo apt install cockpit tlp vim git curl upower ncdu glances htop lm-sensors iotop

# install netdata
wget -O /tmp/netdata-kickstart.sh https://get.netdata.cloud/kickstart.sh && sh /tmp/netdata-kickstart.sh --stable-channel --disable-telemetry
echo 'bind socket to IP = 192.168.1.100' | sudo tee -a /etc/netdata/netdata.conf
sudo systemctl restart netdata

sudo sensors-detect

# webmin
curl -o setup-repos.sh https://raw.githubusercontent.com/webmin/webmin/master/setup-repos.sh
sudo sh setup-repos.sh
sudo apt-get install webmin --install-recommends

# battop
wget -O $HOME/battop https://github.com/svartalf/rust-battop/releases/download/v0.2.4/battop-v0.2.4-x86_64-unknown-linux-gnu
sudo install battop $HOME/.local/bin/battop

# lazydocker
curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

# disable packagekit
sudo systemctl stop packagekit
sudo systemctl mask packagekit
dpkg-divert --divert /etc/PackageKit/20packagekit.distrib --rename  /etc/apt/apt.conf.d/20packagekit

# enable power saving
sudo systemctl enable powertop --now
sudo systemctl enable tlp --now

# add lines to .bashrc

# edit logind.conf
echo 'HandlePowerKey=suspend
HandleSuspendKey=suspend
HandleHibernateKey=suspend
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore' | sudo tee -a /etc/systemd/logind.conf
sudo systemctl restart systemd-logind

# set static ip
sudo cp /etc/network/interfaces ~/interfaces.bak
sudo vim /etc/network/interfaces # remove dhcp and allow-hotplug line, change to auto [interface]
sudo systemctl restart networking

# enable hibernation
sudo fallocate -l 6144m /swapfile
sudo mkswap /swapfile
sudo chmod 600 /swapfile
echo '/swapfile   swap    swap    defaults        0       0 ' | sudo tee -a /etc/fstab
sudo sysctl -w vm.swappiness=1
echo 'vm.swappiness=1' | sudo tee -a /etc/sysctl.d/local.conf
sudo swapon /swapfile
# get root UUID
sudo findmnt / -o UUID -n
# get swap offset
sudo filefrag -v /swapfile|awk 'NR==4{gsub(/\./,"");print $4;}'

# update grub
sudo sed -i -E 's/^GRUB_CMDLINE_LINUX_DEFAULT=/#GRUB_CMDLINE_LINUX_DEFAULT=/' /etc/default/grub
# set proper resume and resume_offset values first
echo 'GRUB_CMDLINE_LINUX_DEFAULT="consoleblank=120 resume=UUID=xxxx resume_offset=yyyy"' | sudo tee -a /etc/default/grub
sudo sed -i 's/RESUME=UUID.*/RESUME=UUID=xxxx/' /etc/initramfs-tools/conf.d/resume
sudo update-grub
sudo update-initramfs -k all -u
sudo systemctl hibernate # testing

sudo vim /etc/UPower/UPower.conf
# replicate this settings for power management  
#UsePercentageForPolicy=true
#PercentageLow=20
#PercentageCritical=10
#PercentageAction=10
#CriticalPowerAction=Hibernate
sudo systemctl restart upower
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
# sudo apt install nftables
# sudo systemctl enable nftables --now
sudo nft flush ruleset
sudo apt autoremove --purge nftables
sudo apt install firewalld 
sudo systemctl enable firewalld --now

# set firewall rules 
sudo firewall-cmd 
# sudo nft flush ruleset
# sudo nft add table ip firewall
# sudo nft add chain ip firewall input { type filter hook input priority 0 \; policy drop \; }
# sudo nft add rule ip firewall input iif lo accept
# sudo nft add rule ip firewall input iif != lo ip daddr 127.0.0.0/8 drop
# sudo nft add rule ip firewall input tcp dport ssh accept
# sudo nft add rule ip firewall input ct state established,related accept
# sudo nft add chain ip firewall forward { type filter hook forward priority 0 \; policy drop \; }
# sudo nft add chain ip firewall output { type filter hook output priority 0 \; policy drop \; }
# sudo nft add rule ip firewall output oif lo accept
# sudo nft add rule ip firewall output tcp dport { http, https } accept
# sudo nft add rule ip firewall output udp dport { domain, ntp } accept
# sudo nft add rule ip firewall output ct state established,related accept
# 
# for ipv4 only network
# sudo nft add table ip6 firewall
# sudo nft add chain ip6 firewall input { type filter hook input priority 0 \; policy drop \; }
# sudo nft add chain ip6 firewall forward { type filter hook forward priority 0 \; policy drop \; }
# sudo nft add chain ip6 firewall output { type filter hook output priority 0 \; policy drop \; }

# make rules persistent
#sudo cat << "EOF" > /etc/nftables.conf
#!/usr/sbin/nft -f
#
#flush ruleset
#
#EOF
#
#sudo nft list ruleset >> /etc/nftables.conf
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

sudo usermod -aG docker $USER
newgrp docker
```

### Host server applications

```bash
git config --global user.name "ken"
git config --global user.email "ken@homelab.com"
git clone https://github.com/devken0/docker-homelab.git
compose
dockerup

# set dns to pi-hole
sudo sed -i '/nameserver/I d' /etc/resolv.conf
echo 'nameserver 127.0.0.1' | sudo tee -a /etc/resolv.conf 

# modify cockpit.conf for nginx
echo '[WebService]
AllowUnencrypted = True
Origins=http://cockpit.lan http://cockpit.homesc3.duckdns.org http://homesc3.duckdns.org:9090 ' | sudo tee -a /etc/cockpit/cockpit.conf 
```

### Setup Samba

Install cockpit-file-sharing, cockpit-file-navigator, cockpit-identities by [45Drives](https://github.com/45Drives).

---

Credits

https://sunknudsen.com/privacy-guides
https://sunknudsen.com/privacy-guides/how-to-configure-hardened-debian-server
https://www.cyberciti.biz/faq/add-configure-set-up-static-ip-address-on-debianlinux/
https://github.com/45Drives
https://webmin.com/download/
https://www.digitalocean.com/community/tutorials/how-to-set-up-a-firewall-using-firewalld-on-centos-7
https://learn.netdata.cloud/docs/installing/one-line-installer-for-all-linux-systems
https://wiki.debian.org/nftables
https://medium.com/opsops/how-to-disable-packagekit-f935207044c1
