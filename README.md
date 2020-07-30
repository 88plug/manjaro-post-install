# manjaro-post-install
# 15 Things to do after installing Manjaro Linux
```
#!/bin/bash
# 15 things to do after installing Manjaro

echo "1. Updating mirrors and Manjaro"
pacman-mirrors --geoip ; yes | pacman -Syyu

echo "Remember current user $u before reboot"
u=$(logname)
echo "${u}" > user.log

echo "2. Enable SSH"
systemctl enable sshd.service; systemctl start sshd.service

echo "3. Make .ssh folder for keys, make 4096 ssh keys, add authorized_key file and chmod!"
mkdir ~/.ssh
HOSTNAME=`hostname` ssh-keygen -t rsa -b 4096 -C "$HOSTNAME" -f "$HOME/.ssh/id_rsa" -P "" && cat ~/.ssh/id_rsa.pub
touch ~/.ssh/authorized_keys
chmod 700 ~/.ssh && chmod 600 ~/.ssh/*

echo "4. Install goodies | ntp docker docker-compose glances htop bmon jq whois yay ufw fail2ban git bc nmap smartmontools"
yes | pacman -Sy ntp docker docker-compose glances htop bmon jq whois yay ufw fail2ban git bc nmap smartmontools qemu-guest-agent iotop

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

ufw --force enable
echo "You can login after this reboot - don't forget to set your hostname with : sudo hostnamectl set-hostname deathstar"

reboot now
```
