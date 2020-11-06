#!/usr/bin/sh

##########################################################
#
# This program configures an instructor station to support
# the AutoFS lab in HP's System and Network Administration
# class.  
#
# ASSUMPTIONS:
# requires hostname/IP addresses as defined in the
# IP connectivity lab in H3065S.  requires instructor
# system to be configured as hostname corp with an IP
# address ending in *.*.0.1.  assumes that user1-6 exist
# in /etc/passwd.  assumes that corp's LAN interface
# can be multiplexed with logical interfaces 12,13,14. 
#
# CHANGE LOG:
# 2009-03-06 Changed line 81 from $user$n to $username
# 2008-09-19 Added a bunch of error checking
# 2008-09-19 Modified code to accomodate HPVL systems w/ multiple LANs
#
##########################################################

PATH=/usr/bin:/usr/sbin

###
### Verify that user1-6 exist in /etc/passwd
###

function VerifyPasswordEntries
{
echo "NOTE: Verifying user1-6 entries in /etc/passwd"
if ! grep -q "^user1:" /etc/passwd; then
   echo "ERROR: user1 doesn't exist in /etc/passwd"
   exit
fi
if ! grep -q "^user2:" /etc/passwd; then
   echo "ERROR: user2 doesn't exist in /etc/passwd"
   exit
fi
if ! grep -q "^user3:" /etc/passwd; then
   echo "ERROR: user3 doesn't exist in /etc/passwd"
   exit
fi
if ! grep -q "^user4:" /etc/passwd; then
   echo "ERROR: user4 doesn't exist in /etc/passwd"
   exit
fi
if ! grep -q "^user5:" /etc/passwd; then
   echo "ERROR: user5 doesn't exist in /etc/passwd"
   exit
fi
if ! grep -q "^user6:" /etc/passwd; then
   echo "ERROR: user6 doesn't exist in /etc/passwd"
   exit
fi
}

function ModifyHomeDirs
{
echo "NOTE: Modifying user1-6 entries in /etc/passwd"
usermod -d "/home/finance/user1"   user1
usermod -d "/home/finance/user2"   user2 
usermod -d "/home/business/user3"  user3 
usermod -d "/home/business/user4"  user4 
usermod -d "/home/sales/user5"     user5 
usermod -d "/home/sales/user6"     user6 
}

###
### Create new user home directories
###
function CreateHomeDirs
{
echo "NOTE: Creating home directories for user1-6"
for n in 1 2 3 4 5 6 
do 
   username=user$n
   homedir=$(grep $username: /etc/passwd | cut -d: -f6)
   mkdir -p $homedir
   cp /etc/skel/.[!.]* $homedir
   chown -R $username $homedir
done
}

###
### Remove the directories we just created if on 
### a student system.
### 
function RemoveHomeDirs
{
echo "NOTE: Removing user1-6 /home/finance, /home/business, /home/sales"
rm -rf /home/finance/user1
rm -rf /home/finance/user2
rm -rf /home/business/user3
rm -rf /home/business/user4
rm -rf /home/sales/user5
rm -rf /home/sales/user6
}

###
### Create 3 multiplexed IP's on the instructor station
###

function ConfigureNewIPs
{

# determine corp's IP address
echo "NOTE: Attempting to determine corp's IP address"
ipaddress=$(awk '$1 ~ /\.0\.1$/ && $2 ~ "^corp" {print $1}' /etc/hosts)
if [[ "$ipaddress" = "" ]]; then
   echo "ERROR: Couldn't determine corp's IP address"
   exit
fi
if [[ "$ipaddress" != +([0-9]).+([0-9]).+([0-9]).+([0-9]) ]]; then
   echo "ERROR: '$ipaddress' isn't a valid address for corp"
   exit
fi
echo "NOTE: Found IP address '$ipaddress'"

# determine corp's interface name
echo "NOTE: Attempting to determine corp's interface name"
ifname=$(netstat -in | \
   awk -v ipaddress=$ipaddress '$4 == ipaddress {print $1}')
if [[ "$ifname" != lan[0-9] ]]; then
   echo "ERROR: couldn't determine corp's interface name"
   exit
fi
echo "NOTE: Found interface name '$ifname'"

# determine the first second octets of corp's IP address
octet1=$(echo $ipaddress | awk -F. '{print $1}')
octet2=$(echo $ipaddress | awk -F. '{print $2}')

# configure the additional LAN interfaces
echo "NOTE: Configuring $ifname:12 as $octet1.$octet2.0.2"
ifconfig $ifname:12 $octet1.$octet2.0.2 netmask 255.255.0.0 up
echo "NOTE: Configuring $ifname:13 as $octet1.$octet2.0.3"
ifconfig $ifname:13 $octet1.$octet2.0.3 netmask 255.255.0.0 up
echo "NOTE: Configuring $ifname:14 as $octet1.$octet2.0.4"
ifconfig $ifname:14 $octet1.$octet2.0.4 netmask 255.255.0.0 up
}

function AddHostEntries
{

# determine corp's IP address
echo "NOTE: Attempting to determine corp's IP address"
ipaddress=$(awk '$1 ~ /\.0\.1$/ && $2 ~ "^corp" {print $1}' /etc/hosts)
if [[ "$ipaddress" = "" ]]; then
   echo "ERROR: couldn't determine corp's IP address"
   exit
fi
if [[ "$ipaddress" != +([0-9]).+([0-9]).+([0-9]).+([0-9]) ]]; then
   echo "ERROR: '$ipaddress' isn't a valid address for corp"
   exit
fi

# determine the first second octets of corp's IP address
octet1=$(echo $ipaddress | awk -F. '{print $1}')
octet2=$(echo $ipaddress | awk -F. '{print $2}')

# add entries to /etc/hosts
echo "NOTE: Adding new entries to /etc/hosts"
echo "# Entries added for AutoFS lab" >>/etc/hosts
echo "NOTE: Adding '$octet1.$octet2.0.2 finance' to /etc/hosts"
echo "$octet1.$octet2.0.2 finance" >>/etc/hosts
echo "NOTE: Adding '$octet1.$octet2.0.3 business' to /etc/hosts"
echo "$octet1.$octet2.0.3 business" >>/etc/hosts
echo "NOTE: Adding '$octet1.$octet2.0.4 sales' to /etc/hosts"
echo "$octet1.$octet2.0.4 sales" >>/etc/hosts
}

###
### Build the /data directory structure
###

function CreateDataDir
{
echo "NOTE: Creating a /data/ directory structure"
mkdir -p /data/contacts/americas/ \
         /data/contacts/europe/ \
         /data/contacts/asia/ \
         /data/contacts/africa/ \
         /data/contacts/australia/
chmod -R 755 /data
}

###
### Share file systems required by students
###

function ShareFileSystems
{
echo "NOTE: Adding /home, /usr, and /data to /etc/dfs/dfstab"
cat >/etc/dfs/dfstab <<EOF
share -F nfs /home
share -F nfs /usr
share -F nfs /data
EOF
echo "NOTE: Executing unshareall/shareall to share file systems"
unshareall 2>/dev/null #unshareall has a defect that causes a false error
shareall   
}

###
### MAIN
###

case $(hostname) in
   corp) VerifyPasswordEntries
         CreateHomeDirs
         ModifyHomeDirs
         ConfigureNewIPs
         AddHostEntries
         CreateDataDir
         ShareFileSystems;;
   *)    VerifyPasswordEntries
         CreateHomeDirs
         ModifyHomeDirs
         RemoveHomeDirs
         AddHostEntries;;
esac
