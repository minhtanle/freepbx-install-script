#UPDATE 
yum update -y
yum groupinstall core base "Development Tools" -y

#Install Additional Required Dependencies
yum -y install lynx mariadb-server mariadb php php-mysql php-mbstring tftp-server httpd ncurses-devel sendmail sendmail-cf sox newt-devel libxml2-devel libtiff-devel audiofile-devel gtk2-devel subversion kernel-devel git php-process crontabs cronie cronie-anacron wget vim php-xml uuid-devel sqlite-devel net-tools gnutls-devel php-pear unixODBC mysql-connector-odbc vim

#Install Legacy pear requirements
pear install Console_Getopt

#Enable and Start MariaDB
systemctl enable mariadb.service
systemctl start mariadb

#Enable and Start Apache
systemctl enable httpd.service
systemctl start httpd.service

#Add the Asterisk User
adduser asterisk -m -c "Asterisk User"

#Install and Configure Asterisk
cd /usr/src
wget http://downloads.asterisk.org/pub/telephony/dahdi-linux-complete/dahdi-linux-complete-2.11.1+2.11.1.tar.gz
wget http://downloads.asterisk.org/pub/telephony/libpri/libpri-1.6.0.tar.gz
wget http://downloads.asterisk.org/pub/telephony/asterisk/old-releases/asterisk-13.21.1.tar.gz
wget -O jansson.tar.gz https://github.com/akheron/jansson/archive/v2.7.tar.gz
wget http://www.pjsip.org/release/2.4/pjproject-2.4.tar.bz2

#Compile and install DAHDI
cd /usr/src
tar xvfz dahdi-linux-complete-2.11.1+2.11.1.tar.gz
tar xvfz libpri-1.6.0.tar.gz
rm -f dahdi-linux-complete-2.11.1+2.11.1.tar.gz libpri-1.6.0.tar.gz
cd dahdi-linux-complete-2.11.1+2.11.1
make all
make install
make config
cd /usr/src/libpri-*
make
make install

#Compile and install pjproject
cd /usr/src
tar -xjvf pjproject-2.4.tar.bz2
rm -f pjproject-2.4.tar.bz2
cd pjproject-2.4
CFLAGS='-DPJ_HAS_IPV6=1' ./configure --prefix=/usr --enable-shared --disable-sound --disable-resample --disable-video --disable-opencore-amr --libdir=/usr/lib64
make dep
make
make install

#Compile and Install jansson 
cd /usr/src
tar vxfz jansson.tar.gz
rm -f jansson.tar.gz
cd jansson-*
autoreconf -i
./configure --libdir=/usr/lib64
make
make install

#Compile and install Asterisk
cd /usr/src
tar xvfz asterisk-13.21.1.tar.gz
rm -f asterisk-13.21.1.tar.gz
cd asterisk-*
contrib/scripts/install_prereq install
contrib/scripts/get_mp3_source.sh
./configure --libdir=/usr/lib64
make menuselect.makeopts
menuselect/menuselect --enable format_mp3 --enable res_config_mysql --enable app_mysql --enable cdr_mysql menuselect.makeopts
make
make install
make config
ldconfig
chkconfig asterisk off

#Install Asterisk Soundfiles.
cd /var/lib/asterisk/sounds
wget http://downloads.asterisk.org/pub/telephony/sounds/asterisk-core-sounds-en-wav-current.tar.gz
wget http://downloads.asterisk.org/pub/telephony/sounds/asterisk-extra-sounds-en-wav-current.tar.gz
tar xvf asterisk-core-sounds-en-wav-current.tar.gz
rm -f asterisk-core-sounds-en-wav-current.tar.gz
tar xfz asterisk-extra-sounds-en-wav-current.tar.gz
rm -f asterisk-extra-sounds-en-wav-current.tar.gz
wget http://downloads.asterisk.org/pub/telephony/sounds/asterisk-core-sounds-en-g722-current.tar.gz
wget http://downloads.asterisk.org/pub/telephony/sounds/asterisk-extra-sounds-en-g722-current.tar.gz
tar xfz asterisk-extra-sounds-en-g722-current.tar.gz
rm -f asterisk-extra-sounds-en-g722-current.tar.gz
tar xfz asterisk-core-sounds-en-g722-current.tar.gz
rm -f asterisk-core-sounds-en-g722-current.tar.gz

#Set Asterisk ownership permissions.
chown asterisk. /var/run/asterisk
chown -R asterisk. /etc/asterisk
chown -R asterisk. /var/{lib,log,spool}/asterisk
chown -R asterisk. /usr/lib64/asterisk
chown -R asterisk. /var/www/

#Install and Configure FreePBX
sed -i 's/\(^upload_max_filesize = \).*/\128M/' /etc/php.ini
sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/httpd/conf/httpd.conf
sed -i 's/AllowOverride None/AllowOverride All/' /etc/httpd/conf/httpd.conf
systemctl restart httpd.service

#Download and install FreePBX.
cd /usr/src
wget http://mirror.freepbx.org/modules/packages/freepbx/freepbx-13.0.195.4.tgz
tar xfz freepbx-13.0.195.4.tgz
rm -f freepbx-13.0.195.4.tgz
cd freepbx
./start_asterisk start
./install -n
fwconsole chown
fwconsole restart

#Auto on boot
cat >> /etc/systemd/system/freepbx.service << EOF
[Unit] 
Description=FreePBX VoIP Server
After=mariadb.service
[Service] 
Type=oneshot 
RemainAfterExit=yes 
ExecStart=/usr/sbin/fwconsole start -q 
ExecStop=/usr/sbin/fwconsole stop -q 
[Install] 
WantedBy=multi-user.target 

EOF

#Enable FreePBX 
systemctl enable freepbx.service

ln -s '/etc/systemd/system/freepbx.service' '/etc/systemd/system/multi-user.target.wants/freepbx.service'
systemctl start freepbx

#Install FAIL2BAN
yum install iptables-services -y
systemctl mask firewalld
systemctl enable iptables
systemctl stop firewalld
systemctl start iptables
yum install epel-release -y
yum install fail2ban -y
cat >> /etc/sysconfig/iptables << EOF
*filter
:INPUT DROP [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -s 192.168.1.2/32 -j ACCEPT
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 21 -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 80 -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 443 -j ACCEPT
-A INPUT -p udp -m state --state NEW -m udp --dport 5060 -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 5060 -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 10050 -j ACCEPT
-A INPUT -p udp --match multiport --dports 10000:60000 -j ACCEPT
-A INPUT -j REJECT --reject-with icmp-host-prohibited
-A FORWARD -j REJECT --reject-with icmp-host-prohibited
COMMIT

EOF

cat >> /etc/fail2ban/jail.local << EOF
[ssh-iptables]
enabled  = true
filter   = sshd
action   = iptables[name=SSH, port=22, protocol=tcp]
logpath  = /var/log/secure
maxretry = 5

[asterisk-iptables]
enabled  = true
filter   = asterisk
port    = 5060,5080
action   = iptables-allports[name=ASTERISK, protocol=all]
sendmail-whois[name=ASTERISK, dest=root, sender=asterisk@fail2ban.local]
logpath  = /var/log/asterisk/full
maxretry = 5
bantime = 86400

[pbx-gui]
enabled = true
filter = webmin-auth
action = iptables-allports[name=SIP, protocol=all]
logpath = /var/log/asterisk/freepbx_security.log

[apache-badbots]
enabled = true
filter = apache-badbots
action = iptables-multiport[name=BadBots, protocol=tcp, port="http,https"]
logpath = /var/log/httpd/*access_log

[recidive]
enabled  = true
filter   = recidive
#logpath  = /var/log/fail2ban.log*
action   = iptables-allports[name=recidive, protocol=all]
bantime  = 604800  ; 1 week
findtime = 86400   ; 1 day
maxretry = 20

EOF

touch /var/log/asterisk/freepbx_security.log
touch /var/log/fail2ban.log

#Restart fail2ban
systemctl enable fail2ban
systemctl restart fail2ban

service iptables restart
