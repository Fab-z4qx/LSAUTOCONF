#!/bin/bash
set -e #Arret du script en cas d'erreur

###### VALUE OF CONFIGURATION ######
SERVERNAME="debserv" # TO CHANGE
TYPE_OF_DNS="1" # 1 FOR MASTER DNS || 2 FOR SLAVE DNS
DNSNAME="fab-tim.lan" # Domaine Name For cnfiguration 
SERVERNAME_DNS="dns1" #dns name serv 1
SERVERNAME_DNS_SEC="dns2" #dns name serv 2 
IP_OF_DEFAULT_DOMAINE="192.168.77.140" #IP OF DOMAINE
IP_OF_SEC_DNS="192.168.77.141" #IP OF 2ND DNS SERVER
SUBNET_DHCP_IP="192.168.77.0" #SUBNETWORK FOR DHCP
NETMASK_DHCP_IP="255.255.255.0" #DHCP NETMASK
START_DHCP_IP="192.168.77.145" #START OF IP RANGE
END_DHCP_IP="192.168.77.200" #END OF IP RANGE
LAST_IP_OF_DNS="140" #FOR REVERSE DNS
LAST_IP_OF_SEC_DNS="141" #FOR REVERSE THE SECOND DNS

function_error(){
  echo -e "\033[31m [ERROR]: $1 \033[0m"
}

function info(){
  echo -e "\033[32m [INFO]: $1 \033[0m" 
}

function check_root(){
if [ $USER != 'root' ]  ;then 
   error "Executer le script en root"
else
   info "Check Root User : OK"
fi
}

function sys_update(){
  apt-get update
} 

function install_ssh(){
   apt-get install ssh
}

function install_dhcp(){
   apt-get install isc-dhcp-server 
}

function install_dns(){
   apt-get install bind9
}

function install_web(){
   apt-get install apache2 apache2-utils php5 php5-dev php5-gd mysql-server
}

function install_tools(){
   apt-get install wireshark nmap tcpdump etthercap
}

function config_ssh(){
echo 
}

function dhcp_config(){
mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.save

info "Configuration du serveur DHCP"
echo " 
option domain-name \"$DNSNAME\";
option domain-name-servers $IP_OF_DEFAULT_DOMAINE, $IP_OF_SEC_DNS, 192.168.77.2;
option routers 192.168.77.2; #Routeur VmWare
default-lease-time 3600;

subnet $SUBNET_DHCP_IP netmask $NETMASK_DHCP_IP {
 range $START_DHCP_IP $END_DHCP_IP;
 authoritative;
} " > /etc/dhcp/dhcpd.conf

echo 'INTERFACES="eth0"' > /etc/default/isc-dhcp-server
service isc-dhcp-server restart
}

function config_sys(){
echo "$1" >> /etc/hostname
alias ls='ls --color=auto'
alias vi="vim"
echo "PS1='\
\[\033[00m\][\
\[\033[31m\]\u\
\[\033[00m\]@\
\[\033[35m\]\h\
\[\033[00m\]:\
\[\033[34m\]\w\
\[\033[00m\]]\
\[\033[00m\]\$\
 '" >> /root/.bashrc
sys_update
}

function config_interfaces(){
PATH_TO_NETWORK_CONFIG="/etc/network/interfaces"

echo "
# The loopback network interface
auto lo
iface lo inet loopback

#IP
auto eth0
iface eth0 inet static
" > $PATH_TO_NETWORK_CONFIG

if [ $TYPE_OF_DNS == "1" ] ;then
        info "IP ADRESSE CONFIGURATION = $IP_OF_DEFAULT_DOMAINE"
echo "address $IP_OF_DEFAULT_DOMAINE
network $SUBNET_DHCP_IP/24
netmask $NETMASK_DHCP_IP
gateway 192.168.77.2 " >> $PATH_TO_NETWORK_CONFIG
else
        info "IP ADDRESS CONFIGURATION = $IP_OF_SEC_DNS"
echo "address $IP_OF_SEC_DNS
netmask 255.255.255.0
gateway 192.168.77.2" >> $PATH_TO_NETWORK_CONFIG

fi
echo "
# The primary network interface
#allow-hotplug eth0
#iface eth0 inet dhcp" >> $PATH_TO_NETWORK_CONFIG
service networking restart
}

function config_dns(){
if [ $TYPE_OF_DNS == "1" ] ;then
	info "CONFIG DNS SERVER IN MASTER MODE"
	config_bind_master
else
	info "CONFIG DNS SERVER IN SLAVE MODE"
	config_bind_slave
fi
}

function config_bind_slave(){
# Configuration du DNS de base
#Configuration du fichier named.conf.local
echo "zone \"$DNSNAME\" {
             type slave;
	     masters{$IP_OF_DEFAULT_DOMAINE;};
             file \"/etc/bind/db.$DNSNAME\";
  	     allow-query { any; };
};

zone \"77.168.192.in-addr.arpa\" {
        type slave;
        masters {$IP_OF_DEFAULT_DOMAINE;} ;
        file \"/etc/bind/db.192\";
};" > /etc/bind/named.conf.local

#Reboot de bind 
service bind9 restart
info "Pensez à verifier la configuration de votre serveur DNS (resolv.conf)"
}

function config_bind_master(){
# Configuration du DNS de base
#Configuration du fichier named.conf.local
echo "zone \"$DNSNAME\" {
             type master;
	     notify yes;
	     allow-transfer { $IP_OF_SEC_DNS; };
             file \"/etc/bind/db.$DNSNAME\";
  	     allow-query { any; };
};

zone \"77.168.192.in-addr.arpa\" {
        type master;
        notify yes;
	allow-transfer {$IP_OF_SEC_DNS; };
        file \"/etc/bind/db.192\";
};" > /etc/bind/named.conf.local

#Configuration de la Zone DNS
echo '$TTL    86400' > /etc/bind/db.$DNSNAME
echo "@       IN      SOA     $SERVERNAME.$DNSNAME. contact.$DNSNAME. (
                       30112014         ; Serial
                          86400         ; Refresh
                            600         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;Name server for domains
        IN      NS      $SERVERNAME.$DNSNAME.
	IN	NS	$SERVERNAME_DNS.$DNSNAME.
	IN	NS	$SERVERNAME_DNS_SEC.$DNSNAME.

;Default ip of the Domaine
	IN	A	$IP_OF_DEFAULT_DOMAINE

;Node of domains
@	IN	A	$IP_OF_DEFAULT_DOMAINE
$SERVERNAME IN      A       $IP_OF_DEFAULT_DOMAINE
$SERVERNAME_DNS	IN	A	$IP_OF_DEFAULT_DOMAINE
$SERVERNAME_DNS_SEC	IN	A	$IP_OF_SEC_DNS
www     IN      A       $IP_OF_DEFAULT_DOMAINE" >> /etc/bind/db.$DNSNAME

#Configuration de la zone de cherche inverse
echo "@       IN      SOA    $SERVERNAME.$DNSNAME. contact.$DNSNAME. (
                       30112014         ; Serial
                          86400         ; Refresh
                            600         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      $SERVERNAME.$DNSNAME.
@	IN	NS	$SERVERNAME_DNS_SEC.$DNSNAME.
$LAST_IP_OF_DNS     IN      PTR     $SERVERNAME.$DNSNAME.
$LAST_IP_OF_SEC_DNS     IN      PTR     $SERVERNAME_DNS_SEC.$DNSNAME." > /etc/bind/db.192

#Reboot de bind 
service bind9 restart
info "Pensez à verifier la configuration de votre fichier (resolv.conf)"
}

function main(){
   check_root
   config_interfaces   
   #config_sys $SERVERNAME #Configuration du nom de la machine
   #install_ssh
   #install_dns
   #install_dhcp
   #install_web
 
#---- CONFIGURATION ---- 
   #config_bind
   #config_dns
   #config_ssh #NOT IMPLEMENTED
   #config_web #NOT IMPLEMENTED
}

main

