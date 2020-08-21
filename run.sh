# manjaro-post-install
# 15 Things to do after installing Manjaro Linux
# Run this file with sudo! 

#!/bin/bash

echo "Remember current user $u before reboot"
u=$(logname)
echo "${u}" > user.log


echo "1. Updating mirrors and Manjaro"
#pacman-mirrors --geoip ; yes | pacman -Syyu #OLD WAY Max retries exceeded with url: /v1/ip/country/full
#pacman-mirrors --fasttrack 
pacman-mirrors --country United_States
yes | pacman -Syyu

echo "2. Enable SSH"
systemctl enable sshd.service; systemctl start sshd.service

echo "3. Make .ssh folder for keys, make 4096 ssh keys, add authorized_key file and chmod!"
mkdir ~/.ssh
HOSTNAME=`hostname` ssh-keygen -t rsa -b 4096 -C "$HOSTNAME" -f "$HOME/.ssh/id_rsa" -P "" && cat ~/.ssh/id_rsa.pub
touch ~/.ssh/authorized_keys
chmod 700 ~/.ssh && chmod 600 ~/.ssh/*
cp -r /root/.ssh /home/$u/
chown $u:$u /home/$u/.ssh -R

echo "4. Install goodies | ntp docker docker-compose glances htop bmon jq whois yay ufw fail2ban git bc nmap smartmontools gnome-disk-utility"
yes | pacman -Sy pigz screen haproxy net-tools ntp docker docker-compose glances htop bmon jq whois yay ufw fail2ban git bc nmap smartmontools qemu-guest-agent iotop gnome-disk-utility

echo "5. Install base-devel for using yay and building packages with AUR"
yes | pacman -Sy autoconf automake binutils bison fakeroot file findutils flex gawk gcc gettext grep groff gzip libtool m4 make pacman patch pkgconf sed sudo systemd texinfo util-linux which 

echo "6. Enabling snap in package manager"
yes | pacman -Sy pamac-snap-plugin
1 | pacman -Sy --noconfirm pamac-flatpak-plugin

echo "7. Force colors in terminals"
sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/g' /root/.bashrc
sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/g' /home/$(cat user.log)/.bashrc

echo "8. Enable NTP!"
timedatectl set-ntp true

echo "9. Docker user setup"
groupadd docker
usermod -aG docker $(cat user.log)
sed -i 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cgroup_enable=memory swapaccount=1\"/g' /etc/default/grub
update-grub

if [[ $(mount -l | grep "zfs") ]]; then
echo "Found ZFS!"
cat <<EOT >> /etc/docker/daemon.json
{
  "storage-driver": "zfs",
  "dns": ["1.0.0.1", "1.1.1.1"],
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 10,
  "log-opts": {
    "max-size": "1m",
    "max-file":"3",
  }
}
EOT
rm -rf /var/lib/docker
else
echo "No ZFS Found"
cat <<EOT >> /etc/docker/daemon.json
{
  "dns": ["1.0.0.1", "1.1.1.1"],
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 10,
  "log-opts": {
    "max-size": "1m",
    "max-file":"3",
  }
}
EOT
fi

echo "10. Allow SSH"
ufw allow ssh

echo "11. Limit SSH"
ufw limit ssh

echo "12. Rotate logs at 50M"
sed -i "/^#SystemMaxUse/s/#SystemMaxUse=/SystemMaxUse=50M/" /etc/systemd/journald.conf

echo "13. Setup jail for naughty SSH attempts"
cat <<EOT > /etc/fail2ban/jail.d/sshd.local
[sshd]
enabled   = true
filter    = sshd
banaction = ufw
backend   = systemd
maxretry  = 5
findtime  = 1d
bantime   = 52w
EOT

echo "14. Starting and enabling the jail/fail2ban"
systemctl start fail2ban.service
systemctl enable fail2ban.service

echo "15. Starting and enabling the docker"
systemctl start docker.service
systemctl enable docker.service

echo "Enabling QEMU agent for proxmox"
systemctl start qemu-ga.service ; systemctl enable qemu-ga.service

ufw --force enable
echo "You can login after this reboot - don't forget to set your hostname with : sudo hostnamectl set-hostname deathstar"


## Pretty MOTD BANNER
if [ -z "${NO_MOTD_BANNER}" ] ; then
  if ! grep -q https "/etc/motd" ; then
    cat << 'EOF' > /etc/motd.new
	   This system is optimised by:            https://eXtremeSHOK.com
	     __   ___                            _____ _    _  ____  _  __
	     \ \ / / |                          / ____| |  | |/ __ \| |/ /
	  ___ \ V /| |_ _ __ ___ _ __ ___   ___| (___ | |__| | |  | | ' /
	 / _ \ > < | __| '__/ _ \ '_ ` _ \ / _ \\___ \|  __  | |  | |  <
	|  __// . \| |_| | |  __/ | | | | |  __/____) | |  | | |__| | . \
	 \___/_/ \_\\__|_|  \___|_| |_| |_|\___|_____/|_|  |_|\____/|_|\_\
EOF

    cat /etc/motd >> /etc/motd.new
    mv /etc/motd.new /etc/motd
  fi
fi

reboot now
