# manjaro-post-install
# 15 Things to do after installing Manjaro Linux
# Run this file with sudo! 

#!/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run with sudo, sudo ./run.sh"
  exit
fi
echo "Welcome, just two questions to start!"
read -p 'What hostname should we use for this machine?: ' hostname
if [[ -z "$hostname" ]]; then
   printf '%s\n' "No hostname entered"
   exit 1
else
   printf "You entered %s " "$hostname"
   hostnamectl set-hostname $hostname ; echo ""
fi

while true; do
printf ""
read -p "Keep Manjaro XFCE GUI - do you need a screen? (y/n) " yn
    case $yn in
        [Yy]* ) gui="1"; break;;
        [Nn]* ) gui="2"; break;;
        * ) echo "Please answer yes(y) or no(n).";;
    esac
done

while true; do
printf ""
read -p "Do you need printer support? (y/n) " yn
    case $yn in
        [Yy]* ) print="1"; break;;
        [Nn]* ) print="2"; break;;
        * ) echo "Please answer yes(y) or no(n).";;
    esac
done

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

echo "GUI is set to $gui"

if [[ $gui == "2" ]]; then
echo "Removing the GUI"
yes | pacman -Rs xfce4 gtkhash-thunar libxfce4ui mousepad thunar-archive-plugin thunar-media-tags-plugin xfce4-taskmanager xfce4-battery-plugin xfce4-clipman-plugin xfce4-pulseaudio-plugin xfce4-screenshooter xfce4-whiskermenu-plugin xfce4-whiskermenu-plugin xfce4-xkb-plugin parole xfce4-notifyd lightdm light-locker lightdm-gtk-greeter lightdm-gtk-greeter-settings modemmanager 
else
echo "Keeping the GUI"
echo "Disable xfce power-manager/blanks screen by default etc"
xfce4-power-manager -q
fi

if [[ $print == "2" ]]; then
echo "No printer support required"
else
echo "Adding printer support"
yes | pacman -Rs system-config-printer manjaro-printer cups
cp /etc/cups/cupsd.conf.default /etc/cups/cupsd.conf
systemctl enable cups.service
fi

echo "4. Install goodies | ntp docker docker-compose glances htop bmon jq whois yay ufw fail2ban git bc nmap smartmontools gnome-disk-utility"
yes | pacman -Sy mdadm libqalculate dialog ncdu msr-tools ddrescue pigz screen haproxy net-tools ntp docker docker-compose glances htop bmon jq whois yay ufw fail2ban git bc nmap smartmontools qemu-guest-agent iotop gnome-disk-utility brave-browser discord steam

echo "5. Install base-devel for using yay and building packages with AUR"
yes | pacman -Sy autoconf automake binutils bison fakeroot patch file findutils flex gawk gcc gettext grep groff gzip libtool m4 make pacman patch pkgconf sed sudo systemd texinfo util-linux which netcat tree gum

echo "6. Enabling snap in package manager"
yes | pacman -Sy pamac-snap-plugin
1 | pacman -Sy --noconfirm pamac-flatpak-plugin

echo "7. Force colors in terminals"
sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/g' /root/.bashrc
sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/g' /home/$(cat user.log)/.bashrc

echo "8. Enable File Limits!"
echo fs.nr_open=2147483584 | tee /etc/sysctl.d/40-max-user-watches.conf
echo fs.file-max=100000 | tee /etc/sysctl.d/40-max-user-watches.conf
echo fs.inotify.max_user_watches=524288 | tee /etc/sysctl.d/40-max-user-watches.conf

echo "9. Docker user setup and better options"
groupadd docker
usermod -aG docker $(cat user.log)
sed -i 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cgroup_enable=memory swapaccount=1\"/g' /etc/default/grub
update-grub

echo "10. Allow SSH and limit it"
ufw allow ssh ; ufw limit ssh

echo "11. Rotate logs at 50M"
sed -i "/^#SystemMaxUse/s/#SystemMaxUse=/SystemMaxUse=50M/" /etc/systemd/journald.conf

#Add vaccum size to limit log sizes
journalctl --vacuum-size=1M

echo "12. Setup jail for naughty SSH attempts"
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

echo "13. Starting and enabling the jail/fail2ban"
systemctl start fail2ban.service
systemctl enable fail2ban.service

echo "14. Starting and enabling the docker"
systemctl start docker.service
systemctl enable docker.service

if [[ $(mount -l | grep "zfs") ]]; then
echo "Found ZFS!"
cat > /etc/docker/daemon.json << EOL
{
  "storage-driver": "zfs",
  "dns": ["1.0.0.1", "1.1.1.1"],
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 10,
  "log-opts": {
    "max-size": "1m",
    "max-file":"3"
  }
}
EOL
rm -rf /var/lib/docker
else
echo "No ZFS Found"
cat > /etc/docker/daemon.json << EOL
{
  "dns": ["1.0.0.1", "1.1.1.1"],
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 10,
  "log-opts": {
    "max-size": "1m",
    "max-file":"3"
  }
}
EOL
fi

echo "15. Enabling QEMU agent for proxmox"
systemctl start qemu-ga.service
systemctl enable qemu-ga.service

ufw --force enable
echo "You can login after this reboot"


## Pretty MOTD BANNER
if [ -z "${NO_MOTD_BANNER}" ] ; then
  if ! grep -q https "/etc/motd" ; then
    cat << 'EOF' > /etc/motd.new	   
  ___   ___         __           
 ( _ ) ( _ ) ___   / /__ __ ___ _
/ _  |/ _  |/ _ \ / // // // _ `/
\___/ \___// .__//_/ \_,_/ \_, / 
          /_/             /___/  
This system is optimised by: https://github.com/88plug/manjaro-post-install

UFW Enabled / Port 22 Open
EOF

    cat /etc/motd >> /etc/motd.new
    mv /etc/motd.new /etc/motd
  fi
fi

echo "Getting IP and Timezone info"
ip=$(dig +short myip.opendns.com @resolver1.opendns.com)
timezone=$(curl https://ipapi.co/$ip/timezone)
timedatectl set-timezone $timezone
timedatectl set-ntp true
echo "Got $timezone from $ip"

echo "All done - Rebooting"
reboot now
