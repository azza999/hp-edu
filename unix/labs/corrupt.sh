#!/usr/bin/sh

PATH=/usr/bin:/usr/sbin:/sbin

############################################################
# 
# CORRUPT
#
# This script is designed for use in the HP's 
# System and Network Admin II class troubleshooting
# module.
#
# The script asks the students to choose a number
# between 1 and 5, then corrupts the student's 
# LAN configuration in one of five ways.
# After running the script, challenge the student to 
# do whatever is necessary to fix the corruption
# such that s/he can once again ping the
# instructor's machine (hostname=corp)
# successfully.
#
# Note that (1) is probably the easiest problem
# to solve, while (5) is the most challenging.
# Encourage the students to start with the easiest
# corruptions before proceding on to (4) or (5).
#
# NOTE: This script assumes that the student systems
#       have been configured using the IP addresses
#       and hostnames described in the Sys/Net Admin
#       II TCP/IP configuration chapter.  Other IP 
#       addressing schemes may or may not be
#       compatible with this lab.
#
############################################################

interfacename=$(ch_rc -lp INTERFACE_NAME[0] /etc/rc.config.d/netconf | sed 's/\"//g')
ipaddress=$(ch_rc -lp IP_ADDRESS[0] /etc/rc.config.d/netconf | sed 's/\"//g')
octet1=$(echo $ipaddress | awk -F. '{print $1}')
octet2=$(echo $ipaddress | awk -F. '{print $2}')

###
### Take down the host's LAN card
###
function DownLanCard
{
  ifconfig $interfacename down
}

###
### Remove the instructor's /etc/hosts table entry
###
function RemoveHostEntry
{
  grep -v corp /etc/hosts > /etc/hosts.tmp
  mv /etc/hosts.tmp /etc/hosts
}


###
### Change the third octet of corp's IP in /etc/hosts
###
function ChangeHostEntry
{
  awk -v octet1=$octet1 \
      -v octet2=$octet2 \
          '$2 == "corp" {$1=octet1"."octet2".1.0"}
                        {print}' /etc/hosts >/etc/hosts.tmp
  mv /etc/hosts.tmp /etc/hosts
}


###
### Change $interfacename's netmask to 255.255.255.0
###
function ChangeNetMask
{
  ifconfig $interfacename $ipaddress netmask 255.255.255.0
}


###
### Delete all routes to the host's local network, and the default route
###
function DeleteRoutes
{
  (
  for gateway in $(netstat -rn | grep $octet1.$octet2.0.0 | awk '{print $2}')
  do
     route delete net $octet1.$octet2.0.0 $gateway 
  done
  route delete default $(netstat -rn | awk '/default/ {print $2}')
  ) 2>/dev/null >/dev/null
}
   
print -n "Choose a number between 1 and 5: "
read choice
print    "==================================="
print    "Corrupting your LAN config ..."
print    "Now fix it! ..."
print

/sbin/init.d/dtlogin.rc stop
case "$choice" in
  1) DownLanCard;;
  2) RemoveHostEntry;;
  3) ChangeHostEntry;;
  4) ChangeNetMask;;
  5) DeleteRoutes;;
  *) print "Please choose a number between 1 and 5!";;
esac
