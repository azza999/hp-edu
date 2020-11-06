#!/usr/bin/sh

PATH=/usr/bin:/sbin:/usr/sbin

###############################################################
###############################################################
#
# netsetup
#
# This script is designed for use in HP's
# HPUX system and network administration classes.
# The script automatically determines, and optionally 
# configures, a hostname and IP address for student
# and instructor systems used in HP's H3065S class.
#
# The script prompts the user for a hostname matching
# one of the hostnames in the IP address assignment
# table in the H3065S TCP/IP configuration lab.
# The program then prompts for the first two octets
# that should be prepended on the beginning of each
# host IP address.  It is recommended that instructors 
# use non-routable IP addresses in the range 172.16-31.*.*.
# If multiple instances of H3065S are delivered concurrently,
# it is important to choose different network addresses
# for each class to avoid IP address conflicts.  (eg:  
# class instance one uses 172.16, class instance two uses
# 172.17, etc.)
#
# The program supports several options:
#
#  netsetup       Calculates recommended settings for this host, 
#                 but doesn't change your configuration.
#                 the recommended config is recorded in /tmp/hosts.
#                 This is the recommended usage for students doing
#                 the TCP/IP configuration lab.
#
#  netsetup -ip   Calculates recommended settings for this host, 
#                 then changes your TCP/IP configuration accordingly.
#                 Instructors may use this to configure the 
#                 instructor system as hostname corp during
#                 the TCP/IP configuration lab.  If a student
#                 misconfigures their system during labs, this 
#                 option also provides a convenient mechanism 
#                 to restore a network configuration that 
#                 complies with the network addresses that are            
#                 expected in the H3065S labs.
#
#  netsetup -dns  Configures this host as hostname corp,
#                 and as a root level name server.
#                 This option should only be used by
#                 the instructor, and only during the 
#                 DNS lab exercise.
#
#  netsetup -h    Displays a help message.
#
# REVISION HISTORY
#   
#  2007-05-18     -ip option copies /etc/nsswitch.files
#                 to /etc/nsswitch.conf instead of clobbering
#                 the file entirely.
#
#  2007-05-18     Added resolv.conf, named.data, and named.conf
#                 to the list of files to backup.
#  
#  2007-05-23     Changed /etc/rc.config.d/namesvrs to 
#                 /etc/rc.config.d/namesvrs_dns
#
#  2008-09-19     Added lots of error checking, added code
#                 to accomodate HPVL systems with multiple
#                 pre-configured LAN interfaces.
#
#  2009-03-06     Added "grep -v $interfacename" to GetIndex
#                 function so the script works properly on 
#                 a system with multiplexed interfaces.
#
###############################################################
###############################################################

function CountRoutes
{
numroutes=$(ch_rc -l -A  -p ROUTE_DESTINATION /etc/rc.config.d/netconf | wc -l)
if [[ "$numroutes" > 1 ]]
then
   echo "ERROR: This program assumes that there is at most one route"
   echo "       defined in /etc/rc.config.d/netconf.  You have $numroutes"
   echo "       routes.  Please comment out the additional route(s)" 
   echo "       and run the script again."
   exit 99
fi
}

###############################################################
###############################################################
#
# GetIndex
# Determine the INTERFACE_NAME array index associated
# with the interface name specified by the user.
#
# Approach:
# 1) use ch_rc to generate a list of all the INTERFACE_NAME defs
# 2) use grep to find the one associated with the iface specified by the user
# 3) use grep -v to exclude any multiplexed interfaces
# 4) use sed to delete everything preceding the "[" in the line
# 5) use sed to delete everything following the "]" in the line
# 6) what's left is the array index#
#
###############################################################
###############################################################

function GetIndex
{
   echo $(
      ch_rc -l -A -v -p INTERFACE_NAME /etc/rc.config.d/netconf |
      grep "$interfacename" | 
      grep -v "$interfacename:" |
      sed "s/^.*\[//" | 
      sed "s/\].*$//"
   )
}

###############################################################
###############################################################
#
# BackupConfig
#
###############################################################
###############################################################

function BackupConfig
{
filename="/tmp/dns.lab.backup.$(date +%Y%m%d%H%M).tar"
print "NOTE:  Tar'ing config files to $filename..."
tar -cvf $filename /etc/nsswitch.conf \
                   /etc/rc.config.d/netconf \
                   /etc/rc.config.d/namesvrs_dns \
                   /etc/resolv.conf \
                   /etc/named.data \
                   /etc/named.conf \
                   /etc/hosts >/dev/null 2>/dev/null
}

###############################################################
###############################################################
#
# /etc/nsswitch.conf
#
###############################################################
###############################################################

function ClobberNsswitch
{
print "NOTE:  Clobbering /etc/nsswitch.conf..."
rm -f /etc/nsswitch.conf
}

function SetNsswitchToFiles
{
if [[ -f /etc/nsswitch.files ]]; then
   print "NOTE:  Copying /etc/nsswitch.files to /etc/nsswitch.conf..."
   cat /etc/nsswitch.files > /etc/nsswitch.conf
else
   print "ERROR: Couldn't find /etc/nsswitch.files.  Exiting..."
fi
}

###############################################################
###############################################################
#
# /etc/rc.config.d/netconf
#
###############################################################
###############################################################

function UpdateNetconf
{
print "NOTE:  Updating /etc/rc.config.d/netconf..."

ch_rc -a -p HOSTNAME="'$hostname'"                    /etc/rc.config.d/netconf
ch_rc -a -p INTERFACE_NAME[$index]="'$interfacename'" /etc/rc.config.d/netconf
ch_rc -a -p IP_ADDRESS[$index]="'$ipaddress'"         /etc/rc.config.d/netconf
ch_rc -a -p SUBNET_MASK[$index]="'$subnetmask'"       /etc/rc.config.d/netconf
ch_rc -a -p BROADCAST_ADDRESS[$index]="''"            /etc/rc.config.d/netconf
ch_rc -a -p INTERFACE_STATE[$index]="''"              /etc/rc.config.d/netconf
ch_rc -a -p DHCP_ENABLE[$index]="0"                   /etc/rc.config.d/netconf
ch_rc -a -p INTERFACE_MODULES[$index]="''"            /etc/rc.config.d/netconf

ch_rc -a -p ROUTE_DESTINATION[0]="'default'"          /etc/rc.config.d/netconf
ch_rc -a -p ROUTE_MASK[0]="''"                        /etc/rc.config.d/netconf
ch_rc -a -p ROUTE_GATEWAY[0]="''"                     /etc/rc.config.d/netconf
ch_rc -a -p ROUTE_COUNT[0]="''"                       /etc/rc.config.d/netconf
ch_rc -a -p ROUTE_ARGS[0]="''"                        /etc/rc.config.d/netconf
ch_rc -a -p ROUTE_SOURCE[0]="''"                      /etc/rc.config.d/netconf

}

###############################################################
###############################################################
#
# /etc/hosts
#
###############################################################
###############################################################

function CreateHosts
{
cat <<EOF
# /etc/hosts 
#
# The form for each entry is:
# <internet address>    <official hostname> <aliases>
#
# See the hosts(4) manual page for more information.
# Note: The entries cannot be preceded by a space.
#       The format described in this file is the correct format.
#       The original Berkeley manual page contains an error in
#       the format description.
#

#
# ===================================
# Recommended settings for this host:
# ===================================
# 
# Hostname:       $hostname
# Interface:      $interfacename
# IP address:     $ipaddress
# Subnet Mask:    $subnetmask 
# Default Route:  $defaultroute
#
# DNS Domain:     $dnsdomain
# DNS Master:     $dnsmaster
# DNS Slave:      $dnsslave
# 
# ===================================
#

#
# local loopback
#

127.0.0.1       localhost

#
# other addresses
#

# DNS domain: hp.com
$octet1.$octet2.0.1     corp

# DNS domain: ca.hp.com
$octet1.$octet2.1.1     sanfran   # master
$octet1.$octet2.1.2     oakland   # slave
$octet1.$octet2.1.3     la        # client

# DNS domain: il.hp.com
$octet1.$octet2.2.1     chicago   # master
$octet1.$octet2.2.2     peoria    # slave
$octet1.$octet2.2.3     rockford  # client

# DNS domain: ga.hp.com
$octet1.$octet2.3.1     atlanta   # master
$octet1.$octet2.3.2     athens    # slave
$octet1.$octet2.3.3     macon     # client

# DNS domain: ny.hp.com
$octet1.$octet2.4.1     nyc       # master
$octet1.$octet2.4.2     albany    # slave
$octet1.$octet2.4.3     buffalo   # client

# DNS domain: fr.hp.com
$octet1.$octet2.5.1     paris     # master
$octet1.$octet2.5.2     lyon      # slave
$octet1.$octet2.5.3     grenoble  # client

# DNS domain: uk.hp.com
$octet1.$octet2.6.1     london    # master
$octet1.$octet2.6.2     leeds     # slave
$octet1.$octet2.6.3     ipswich   # client

# DNS domain: de.hp.com
$octet1.$octet2.7.1     bonn      # master
$octet1.$octet2.7.2     berlin    # slave
$octet1.$octet2.7.3     hamburg   # client

# DNS domain: jp.hp.com
$octet1.$octet2.8.1     tokyo     # master
$octet1.$octet2.8.2     kyoto     # slave
$octet1.$octet2.8.3     osaka     # client

EOF
}

################################################################################
################################################################################
#
# /etc/hosts for corp
#
################################################################################
################################################################################

function CreateRootHosts
{
print "NOTE:  Creating a new /etc/hosts file for corp..."
cat >/etc/hosts <<EOF
127.0.0.1  localhost   loopback
$octet1.$octet2.0.1  corp.hp.com corp
EOF
}

################################################################################
################################################################################
#
# /etc/named.conf for corp
#
################################################################################
################################################################################

function CreateNamedConf
{
print "NOTE:  Creating /etc/named.conf"
cat >/etc/named.conf <<EOF
// these are general options for named.
// the check-names lines force named to check the syntax of hostnames in the db files.
// the directory line identifies the directory where the db files are kept.

options { check-names response fail   ; 
          check-names slave warn      ;
          directory "/etc/named.data" ; };

// this name server has authoritative records
// for the ".", "com" and "hp.com" domains 

zone "."                    { type master; file "db.root"   ; };
zone "com"                  { type master; file "db.com"    ; };
zone "hp.com"               { type master; file "db.hp"     ; };

// these lines tell named where to go to find reverse 
// name resolution information for the in-addr.arpa domain.

zone "arpa"                 { type master; file "db.arpa"    ; };
zone "in-addr.arpa"         { type master; file "db.in-addr" ; };
zone "$octet1.in-addr.arpa"     { type master; file "db.$octet1"     ; };
zone "$octet2.$octet1.in-addr.arpa"   { type master; file "db.$octet1.$octet2"   ; };
zone "0.$octet2.$octet1.in-addr.arpa" { type master; file "db.$octet1.$octet2.0" ; };
zone "0.0.127.in-addr.arpa" { type master; file "db.127.0.0" ; };
EOF
}

###############################################################################
###############################################################################

function CreateNamedData
{
print "NOTE:  Creating a new /etc/named.data directory ..."
rm -rf /etc/named.data
mkdir /etc/named.data

###############################################################################
###############################################################################

print "NOTE:  Creating /etc/named.data/db.cache"
cat >/etc/named.data/db.cache <<EOF
;
; this file contains the address(es) of the root
; level name servers.  it is used to initialize 
; the contents of cache on non-root level name 
; servers.
;
; this file is maintained by the internic.
; other name servers must download this file 
; as changes are made.
;
; name servers that use the "forwarder" directive
; in /etc/named.conf don't need a db.cache file.

; for the purpose of our lab exercises,
; there is only one root name server.

.              99999999 IN NS corp.hp.com.
corp.hp.com.   99999999 IN A  $octet1.$octet2.0.1
EOF

###############################################################################
###############################################################################

print "NOTE:  Creating /etc/named.data/db.root"
cat >/etc/named.data/db.root <<EOF
;
; this file contains the address(es) of the root
; level name servers.  it is used to initialize 
; the contents of cache on the root level name
; server.
;

; for the purpose of our lab exercises,
; there is only one root name server.
;

.             IN SOA  corp.hp.com. root.corp.hp.com. (
                             1	        ; Serial
                             10800	; Refresh every 3 hours
                             3600	; Retry every hour
                             604800	; Expire after a week
                             86400 )	; Minimum ttl of 1 day

.             IN NS   corp.hp.com.
corp.hp.com.  IN A    $octet1.$octet2.0.1
EOF

###############################################################################
###############################################################################

print "NOTE:  Creating /etc/named.data/db.com"
cat >/etc/named.data/db.com <<EOF
;
; this file resolves addresses in the com. domain.
; actually, there aren't any hosts directly in the
; com domain so this file really does nothing but 
; forward inquiries to the name server for the
; sole subdomain, hp.com.
;

com.           IN SOA	com. root.corp.hp.com. (
					1	; Serial
					10800	; Refresh every 3 hours
					3600	; Retry every hour
					604800	; Expire after a week
					86400 )	; Minimum ttl of 1 day
com.            IN NS   corp.hp.com.
hp.com.         IN NS   corp.hp.com.
corp.hp.com.    IN A    $octet1.$octet2.0.1
EOF

###############################################################################
###############################################################################

print "NOTE:  Creating /etc/named.data/db.hp"
cat >/etc/named.data/db.hp <<EOF
hp.com.            IN SOA    corp.hp.com. root.corp.hp.com. (
                             1	        ; Serial
                             10800	; Refresh every 3 hours
                             3600	; Retry every hour
                             604800	; Expire after a week
                             86400 )	; Minimum ttl of 1 day

;
; define the name server for the  hp.com domain
;

hp.com.            IN NS     corp.hp.com.

;
; define addresses and mail exchangers for hosts
; in the hp.com domain
;

localhost.hp.com.  IN A	     127.0.0.1
corp.hp.com.       IN A      $octet1.$octet2.0.1
localhost.hp.com.  IN MX $octet1  localhost.hp.com.
corp.hp.com.       IN MX $octet1  corp.hp.com.

;
; delegate responsibility for subdomains to each subdomain's master server
;

ca.hp.com.         IN NS     sanfran.ca.hp.com. 
il.hp.com.         IN NS     chicago.il.hp.com. 
ga.hp.com.         IN NS     atlanta.ga.hp.com.
ny.hp.com.         IN NS     nyc.ny.hp.com.
fr.hp.com.         IN NS     paris.fr.hp.com.
uk.hp.com.         IN NS     london.uk.hp.com.
de.hp.com.         IN NS     bonn.de.hp.com.
jp.hp.com.         IN NS     tokyo.jp.hp.com.

;
; identify the slave server for each subdomain, too
;

ca.hp.com.         IN NS     oakland.ca.hp.com.
il.hp.com.         IN NS     peoria.il.hp.com. 
ga.hp.com.         IN NS     athens.ga.hp.com.
ny.hp.com.         IN NS     albany.ny.hp.com.
fr.hp.com.         IN NS     lyon.fr.hp.com.
uk.hp.com.         IN NS     leeds.uk.hp.com.
de.hp.com.         IN NS     berlin.de.hp.com.
jp.hp.com.         IN NS     kyoto.jp.hp.com.

;
; must know ip addresses for the subdomain master servers
;

sanfran.ca.hp.com. IN A      $octet1.$octet2.1.1
chicago.il.hp.com. IN A      $octet1.$octet2.2.1
atlanta.ga.hp.com. IN A      $octet1.$octet2.3.1
nyc.ny.hp.com.     IN A      $octet1.$octet2.4.1
paris.fr.hp.com.   IN A      $octet1.$octet2.5.1
london.uk.hp.com.  IN A      $octet1.$octet2.6.1
bonn.de.hp.com.    IN A      $octet1.$octet2.7.1
tokyo.jp.hp.com.   IN A      $octet1.$octet2.8.1

;
; ... and the ip addresses for the subdomain slave servers
;

oakland.ca.hp.com. IN A      $octet1.$octet2.1.2
peoria.il.hp.com.  IN A      $octet1.$octet2.2.2
athens.ga.hp.com.  IN A      $octet1.$octet2.3.2
albany.ny.hp.com.  IN A      $octet1.$octet2.4.2
lyon.fr.hp.com.    IN A      $octet1.$octet2.5.2
leeds.uk.hp.com.   IN A      $octet1.$octet2.6.2
berlin.de.hp.com.  IN A      $octet1.$octet2.7.2
kyoto.jp.hp.com.   IN A      $octet1.$octet2.8.2
EOF

###############################################################################
###############################################################################

print "NOTE:  Creating /etc/named.data/db.arpa"
cat >/etc/named.data/db.arpa <<EOF
;
; this file allows ip to name resolution for ip addresses 
; in the arpa. domain.
;

arpa.      		IN	SOA	corp.hp.com. root.corp.hp.com. (
					1	; Serial
					10800	; Refresh every 3 hours
					3600	; Retry every hour
					604800	; Expire after a week
					86400 )	; Minimum ttl of 1 day

; 
; corp.hp.com (this name server) is responsible for the arpa. doamin.
;

arpa.			IN	NS	corp.hp.com.
EOF

###############################################################################
###############################################################################

print "NOTE:  Creating /etc/named.data/db.in-addr"
cat >/etc/named.data/db.in-addr <<EOF
;
; this file allows ip to name resolution for ip addresses 
; in the in-addr.arpa. domain.
;

in-addr.arpa.           IN	SOA	corp.hp.com. root.corp.hp.com. (
					1	; Serial
					10800	; Refresh every 3 hours
					3600	; Retry every hour
					604800	; Expire after a week
					86400 )	; Minimum ttl of 1 day

; 
; corp.hp.com (this name server) is responsible for in-addr.arpa. domain
;

in-addr.arpa.		IN	NS	corp.hp.com.
EOF


###############################################################################
###############################################################################

print "NOTE:  Creating /etc/named.data/db.127.0.0"
cat >/etc/named.data/db.127.0.0 <<EOF
;
; this file allows the root server to resolve the
; loopback address (127.0.0.1) to hostname "localhost"
; 

0.0.127.in-addr.arpa.  IN	SOA	corp.hp.com. root.corp.hp.com. (
					1	; Serial
					10800	; Refresh every 3 hours
					3600	; Retry every hour
					604800	; Expire after a week
					86400 )	; Minimum ttl of 1 day

0.0.127.in-addr.arpa.   IN	NS	corp.hp.com.
1.0.0.127.in-addr.arpa. IN      PTR     localhost.
EOF

###############################################################################
###############################################################################

print "NOTE:  Creating /etc/named.data/db.$octet1"
cat >/etc/named.data/db.$octet1 <<EOF
;
; this file allows ip to name resolution for ip addresses $octet1.*.*.*.
;

$octet1.in-addr.arpa.       IN	SOA	corp.hp.com. root.corp.hp.com. (
					1	; Serial
					10800	; Refresh every 3 hours
					3600	; Retry every hour
					604800	; Expire after a week
					86400 )	; Minimum ttl of 1 day

; 
; corp.hp.com (this name server) is responsible for $octet1.$octet2.0
;

$octet1.in-addr.arpa.	IN	NS	corp.hp.com.
EOF

###############################################################################
###############################################################################

print "NOTE:  Creating /etc/named.data/db.$octet1.$octet2"
cat >/etc/named.data/db.$octet1.$octet2 <<EOF
;
; this file allows ip to name resolution for ip addresses $octet1.$octet2.*.*
; note that only $octet1.$octet2.0.* is resolved authoritatively by this server.
; responsibility for addresses $octet1.$octet2.[1-5] is delegated
; out to the students' name servers in the sub domains.
;

$octet2.$octet1.in-addr.arpa.    IN	SOA	corp.hp.com. root.corp.hp.com. (
					1	; Serial
					10800	; Refresh every 3 hours
					3600	; Retry every hour
					604800	; Expire after a week
					86400 )	; Minimum ttl of 1 day

; 
; corp.hp.com (this name server) is responsible for
; both $octet1.$octet2 and $octet1.$octet2.0
;

$octet2.$octet1.in-addr.arpa.	IN	NS	corp.hp.com.
0.$octet2.$octet1.in-addr.arpa.	IN	NS	corp.hp.com.

;
; delegate responsibility for all the other subdomains
; to the students' name servers.
;

1.$octet2.$octet1.in-addr.arpa.	IN	NS	sanfran.ca.hp.com.
2.$octet2.$octet1.in-addr.arpa.	IN	NS	chicago.il.hp.com.
3.$octet2.$octet1.in-addr.arpa.	IN	NS	atlanta.ga.hp.com.
4.$octet2.$octet1.in-addr.arpa.	IN	NS	nyc.ny.hp.com.
5.$octet2.$octet1.in-addr.arpa.	IN	NS	paris.fr.hp.com.
6.$octet2.$octet1.in-addr.arpa.	IN	NS	london.uk.hp.com.
7.$octet2.$octet1.in-addr.arpa.	IN	NS	bonn.de.hp.com.
8.$octet2.$octet1.in-addr.arpa.	IN	NS	tokyo.jp.hp.com.

;
; if a subdomain's primary server is down, we need to know
; where to find the secondary.
;

1.$octet2.$octet1.in-addr.arpa.	IN	NS	oakland.ca.hp.com.
2.$octet2.$octet1.in-addr.arpa.	IN	NS	peoria.il.hp.com.
3.$octet2.$octet1.in-addr.arpa.	IN	NS	athens.ga.hp.com.
4.$octet2.$octet1.in-addr.arpa.	IN	NS	albany.ny.hp.com.
5.$octet2.$octet1.in-addr.arpa.	IN	NS	lyon.fr.hp.com.
6.$octet2.$octet1.in-addr.arpa.	IN	NS	leeds.uk.hp.com.
7.$octet2.$octet1.in-addr.arpa.	IN	NS	berlin.de.hp.com.
8.$octet2.$octet1.in-addr.arpa.	IN	NS	kyoto.jp.hp.com.
EOF

###############################################################################
###############################################################################

print "NOTE:  Creating /etc/named.data/db.$octet1.$octet2.0"
cat >/etc/named.data/db.$octet1.$octet2.0 <<EOF
;
; this file allows ip to name resolution for ip addresses $octet1.$octet2.*.*
; note that only $octet1.$octet2.0.* is resolved authoritatively by this server.
; responsibility for addresses $octet1.$octet2.[1-5] is delegated
; out to the students' name servers in the sub domains.
;

0.$octet2.$octet1.in-addr.arpa.   IN	SOA	corp.hp.com. root.corp.hp.com. (
					1	; Serial
					10800	; Refresh every 3 hours
					3600	; Retry every hour
					604800	; Expire after a week
					86400 )	; Minimum ttl of 1 day

; 
; corp.hp.com (this name server) is responsible for $octet1.$octet2.0
;

0.$octet2.$octet1.in-addr.arpa.	IN	NS	corp.hp.com.

;
; resolve 1.0.$octet2.$octet1.in-addr.arpa to corp.hp.com
;

1.0.$octet2.$octet1.in-addr.arpa. IN      PTR     corp.hp.com.
EOF

###############################################################################
###############################################################################

chmod -R 555 /etc/named.*
}

################################################################################
################################################################################
#
# /etc/named.data/resolv.conf for corp
#
################################################################################
################################################################################

function CreateResolvConf
{
print "NOTE:  Creating a new /etc/resolv.conf file ..."
cat >/etc/resolv.conf <<EOF
search     hp.com
nameserver $octet1.$octet2.0.1
EOF
}

################################################################################
################################################################################
#
# /etc/rc.config.d/namesvrs_dns for corp
#
################################################################################
################################################################################

function CreateNamesvrs
{
print "NOTE:  Creating a new /etc/rc.config.d/namesvrs_dns file ..."
cat /usr/newconfig/etc/rc.config.d/namesvrs_dns >/tmp/namesvrs_dns
awk '/^NAMED/  {$0 = "NAMED=1"}
               {print}' /tmp/namesvrs_dns >/etc/rc.config.d/namesvrs_dns
}

################################################################################
################################################################################
#
# RESOLVER
# Given a hostname from the new name space, returns an IP
# Given an IP from the new name space, returns a hostname
# 
################################################################################
################################################################################

function Resolver
{
CreateHosts | grep -v -e '^#' -e '^$' > /tmp/$$
if [[ "$1" = [0-9]* ]]; then
   awk -v ip="$1" '$1 == ip {print $2}' /tmp/$$
else
   awk -v hostname="$1" '$2 == hostname {print $1}' /tmp/$$
fi
rm /tmp/$$
}

################################################################################
################################################################################
#
# DETERMINE IP
#
################################################################################
################################################################################

function DetermineIP
{
CreateHosts | grep -v -e '^#' -e '^$' > /tmp/$$
}

################################################################################
################################################################################
#
# DETERMINE DNS
#
################################################################################
################################################################################

function DetermineDNS
{
CreateHosts | grep -v -e '^#' -e '^$' > /tmp/$$

octet3=$(echo $ipaddress | awk -F. '{print $3}')
if [[ "$hostname" = corp ]]; then
   dnsmaster="$octet1.$octet2.$octet3.1 (corp)"
   dnsslave="n/a"
else
   dnsmaster="$octet1.$octet2.$octet3.1 $(Resolver $octet1.$octet2.$octet3.1)"
   dnsslave="$octet1.$octet2.$octet3.2 $(Resolver $octet1.$octet2.$octet3.2)"
fi

case $octet3 in
   0) dnsdomain=hp.com;;
   1) dnsdomain=ca.hp.com;;
   2) dnsdomain=il.hp.com;;
   3) dnsdomain=ga.hp.com;;
   4) dnsdomain=ny.hp.com;;
   5) dnsdomain=fr.hp.com;;
   6) dnsdomain=uk.hp.com;;
   7) dnsdomain=de.hp.com;;
   8) dnsdomain=jp.hp.com;;
esac
}

################################################################################
################################################################################
#
# PrintUsage   
#
################################################################################
################################################################################

function PrintUsage
{
cat <<EOF

USAGE:

  netsetup       Calculates recommended settings for this host, 
                 but doesn't change your configuration.
                 the recommended config is recorded in /tmp/hosts.
                 This is the recommended usage for students doing
                 the TCP/IP configuration lab.

  netsetup -ip   Calculates recommended settings for this host, 
                 then changes your TCP/IP configuration accordingly.
                 Instructors may use this to configure the 
                 instructor system as hostname corp during
                 the TCP/IP configuration lab.  If a student
                 misconfigures their system during labs, this 
                 option also provides a convenient mechanism 
                 to restore a network configuration that 
                 complies with the network addresses that are            
                 expected in the H3065S labs.

  netsetup -dns  Configures this host as hostname corp,
                 and as a root level name server.
                 This option should only be used by
                 the instructor, and only during the 
                 DNS lab exercise.
 
  netsetup -h    Displays this help message.

EOF
}

################################################################################
#
# MAIN
#
################################################################################
################################################################################

if [[ "$1" = -dns ]]; then
   print    "Assigned hostname        : corp"; hostname=corp
elif [[ "$1" = -ip ]]; then
   print -n "Assigned hostname        : "; read hostname
elif [[ $# -eq 0 ]]; then
   print -n "Assigned hostname        : "; read hostname
else
   PrintUsage
   exit
fi

print -n "LAN interface (eg: lan1) : "; read interfacename
print -n "First octet   (eg: 172)  : "; read octet1
print -n "Second octet  (eg: 17)   : "; read octet2
print
index=$(GetIndex $interfacename)
ipaddress=$(Resolver $hostname)
subnetmask=255.255.0.0
defaultroute=$octet1.$octet2.0.1

# validate interface name
if [[ "$interfacename" != lan[0-9] ]]; 
then
   echo "ERROR: '$interfacename' is an invalid interface name."
   exit 99
fi

# validate octet1
if [[ "$octet1" != [1-9] && \
      "$octet1" != [1-9][0-9] && \
      "$octet1" != [1-2][0-9][0-9] ]]; 
then
   echo "ERROR: '$octet1' is an invalid first octet."
   exit 99
fi 

# validate octet2
if [[ "$octet2" != [1-9] && \
      "$octet2" != [1-9][0-9] && \
      "$octet2" != [1-2][0-9][0-9] ]]; 
then
   echo "ERROR: '$interfacename' is an invalid interface name."
   exit 99
fi 

# validate index
if [[ "$index" != [0-9] ]]; 
then
   echo "ERROR: couldn't find '$interfacename' in /etc/rc.config.d/netconf"
   exit
fi


# validate new ipaddress
if [[ "$ipaddress" = "" ]]; 
then
   echo "ERROR: couldn't find an IP address for '$hostname'"
   exit
fi

DetermineDNS
CreateHosts >/tmp/hosts

cat <<EOF
===================================
Recommended Settings for this host:
===================================

Hostname:       $hostname
Interface:      $interfacename
IP address:     $ipaddress
Subnet Mask:    $subnetmask 
Default Route:  $defaultroute

DNS domain:     $dnsdomain
DNS master:     $dnsmaster
DNS slave:      $dnsslave

===================================

EOF

if [[ $# = 0 ]]; then
   print "Please proceed to configure your system using these parameters."
   print "This information is also recorded in /tmp/hosts for future reference."
elif [[ "$1" = -ip ]]; then
   CountRoutes
   BackupConfig
   SetNsswitchToFiles
   UpdateNetconf
   CreateHosts >/etc/hosts
   print "NOTE:  Rebooting..."
   reboot -q
elif [[ "$1" = -dns ]]; then
   CountRoutes
   BackupConfig
   ClobberNsswitch
   UpdateNetconf
   CreateRootHosts
   CreateNamedConf
   CreateNamedData
   CreateResolvConf
   CreateNamesvrs
   print "NOTE:  Rebooting..."
   reboot -q
fi
