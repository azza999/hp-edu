#!/usr/bin/sh

###########################################################################
### 
### dslabsetup.sh
###
###########################################################################
#
# Automatically configures HP Directory Server as described in 
# HP Education's H3065S course.
#
# No arguments required.
# 
# Script is currently unable to register the hpeDS directory
# server instance with the admin console GUI due to a defect in the
# non-interactive versions of the setup-ds-admin.pl and register-ds.pl
# scripts.  If you wish to use the GUI console interface after running 
# this script, execute /opt/dirsrv/sbin/register-ds-admin.pl interactively.
#

###
### establish necessary path variables
###

export PATH=/usr/bin:/usr/sbin:/opt/ldapux/bin:/opt/ldapux/migrate

###
### verify that there isn't already a DS instance running
###

echo "NOTE: Removing any existing admin and directory server instances"
/opt/dirsrv/sbin/remove-ds-admin.pl -f -y

echo "NOTE: Verifying that there are no existing directory server instances"
if netstat -an | grep -q -e "*.388 "; then
   echo "ERROR: There seems to be a daemon already running on port 388"
   echo "       Did you already do the lab, or execute this script previously?"
   exit
else 
   echo "NOTE: Good! No server instance found on port 388"
fi
if netstat -an | grep -q -e "*.389 "; then
   echo "ERROR: There seems to be a daemon already running on port 389"
   echo "       Did you already do the lab, or execute this script previously?"
   exit
else 
   echo "NOTE: Good! No server instance found on port 389"
fi
if [[ -d /var/opt/dirsrv/slapd-hpeDS ]]; then
   echo "ERROR: Looks like /var/opt/dirsrv/slapd-hpeDS already exists"
   exit  
else 
   echo "NOTE: Good! No existing slapd-hpeDS server instance found"
fi
if [[ -d /var/opt/dirsrv/slapd-hpeDS ]]; then
   echo "ERROR: Looks like /var/opt/dirsrv/slapd-ConfigDS already exists"
   exit  
else 
   echo "NOTE: Good! No existing slapd-ConfigDS server instance found"
fi

###
### establish hard coded directory parameters
###

echo "NOTE: Establishing the directory parameters" 
CONFIGPORT=388
CONFIGDN="o=hp.com"
CONFIGID="ConfigDS"
DATAPORT=389
DATADN="ou=hpe,o=hp.com"
DATAID="hpeDS"
DIRMGR="cn=Directory Manager"
DIRMGRPWD="Directory"
ADMIN="admin"
ADMINPWD="admin"

###
### find an available port>50000 to use for the admin GUI
###

echo "NOTE: Finding an available port for the admin interface" 
ADMINPORT=9830
while netstat -nf inet | awk '{print $4}' | sed s/.*[.]// | grep $ADMINPORT >/dev/null 2>/dev/null
do
   let "ADMINPORT=ADMINPORT+1"  
done
echo "NOTE: Found an available port for the admin interface: $ADMINPORT"

###
### determine the hostname and DNS domain
###

echo "NOTE: Determining the system hostname"
HOSTNAME=$(hostname | awk -F. '{print $1}' | head -1)
if [[ $HOSTNAME = "" ]]
then
   echo "ERROR: Couldn't determine your hostname"
   exit
else
   echo "NOTE: Determined that your hostname is '$HOSTNAME'"
fi

echo "NOTE: Determining your FQDN and admin domain"
if grep -q -e search -e domain /etc/resolv.conf 2>/dev/null
then
   DNSDOMAIN=$(awk '/^search|domain/ {print $2}' /etc/resolv.conf | head -1)
   FQDN="$HOSTNAME.$DNSDOMAIN"
   ADMINDOMAIN="$DNSDOMAIN"
else
   FQDN=$(awk -v HOSTNAME="$HOSTNAME" '$2~HOSTNAME {print $2}' /etc/hosts | head -1)
   DNSDOMAIN=$(echo $FQDN | cut -d\. -f2-)
   ADMINDOMAIN="$DNSDOMAIN"
   if [[ "$ADMINDOMAIN" = "" || "$ADMINDOMAIN" = "$HOSTNAME" ]]
   then 
      FQDN="$HOSTNAME"
      ADMINDOMAIN="hp.com"
   fi
fi
echo "NOTE: Using '$FQDN' as your FQDN"
echo "NOTE: Using '$ADMINDOMAIN' as your admin domain"

###
### check software versions
###

echo "NOTE: Verifying existence of LdapUxClient B.04.20.00 or greater" 
if swlist -l product "LdapUxClient,r>=B.04.20.00" >/dev/null 2>/dev/null
then
   echo "NOTE: Good! Found it!"
else
   echo "ERROR: Please install the current version of LdapUxClient"
   exit
fi

echo "NOTE: Verifying existence of HPDirSvr B.08.10.01 or greater"
if swlist -l product "HPDirSvr,r>=B.08.10.01" >/dev/null 2>/dev/null
then
   echo "NOTE: Good! Found it!"
else
   echo "ERROR: Please install the current version of NetscapeDirSvr7" 
   exit
fi

###
### ask the user to verify the parameters
###

cat <<EOF
=====================================================================
PLEASE NOTE THE PARAMETERS BELOW AND CONFIRM THAT YOU WISH TO PROCEED
=====================================================================
HP Directory Server System User:       www
HP Directory Server System Group:      other
Configuration Server Network Port# :   $CONFIGPORT
Configuration Server ServerID:         $CONFIGID
Configuration Server Administrator:    $ADMIN
Configuration Server Admin Password:   $ADMINPWD
Configuration Server BaseDN:           $CONFIGDN
Configuration Server Dir Mgr:          $DIRMGR
Configuration Server Dir Mgr Password: $DIRMGRPWD
Administration Domain:                 $ADMINDOMAIN
Administration GUI Network Port#:      $ADMINPORT
Administration GUI runs as:            root
Data Directory Server ServerID:        $DATAID
Data Directory Server Port#:           $DATAPORT
Data Directory BaseDN:                 $DATADN
Data Directory Manager:                $DIRMGR
Data Directory Manager Password:       $DIRMGRPWD
Data Directory Server Process UID:     www
=====================================================================
EOF
echo "Press [Return] if you wish to continue..." 
read continue

###
### backup the directory server directories
###

BACKUPFILE="/var/tmp/dirsrv.$(date +%Y%m%d%H%M).tar"
echo "NOTE: Backing up /var/opt/dirsrv/ and /etc/opt/dirsrv/ to $BACKUPFILE"
if tar -cf $BACKUPFILE /var/opt/dirsrv/ /etc/opt/dirsrv/; then
   echo "NOTE: Backup complete. If anything goes wrong during "
   echo "      this server setup, do the following to return "
   echo "      the directory server to its initial state"
   echo "      /opt/dirsrv/sbin/remove-ds-admin.pl -f -y"
else
   echo "ERROR: Backup failed.  Perhaps check disk space in /var/tmp?"
   exit 99
fi

###
### just to be official, run dsktune (but ignore the output)
###

echo "NOTE: Executing /opt/dirsrv/bin/dsktune" 
if ! /opt/dirsrv/bin/dsktune >/dev/null
then
   echo "ERROR: dsktune failed"
   exit
fi

###
### build an ConfigDS.inf file,
### and run the server setup script in silent mode
###

echo "NOTE: Building /root/ConfigDS.inf" 
cat >/root/ConfigDS.inf <<EOF

[General]
AdminDomain = $FQDN
SuiteSpotGroup = other
ConfigDirectoryLdapURL = ldap://$FQDN:$CONFIGPORT/o=NetscapeRoot
ConfigDirectoryAdminID = $ADMIN
SuiteSpotUserID = www
ConfigDirectoryAdminPwd = $ADMINPWD
FullMachineName = $FQDN

[admin]
ServerAdminID = $ADMIN
ServerAdminPwd = $ADMINPWD
SysUser = www
ServerIpAddress = 0.0.0.0
Port = $ADMINPORT

[slapd]
InstallLdifFile = suggest
ServerIdentifier = $CONFIGID
ServerPort = $CONFIGPORT
AddOrgEntries = Yes
RootDN = $DIRMGR
RootDNPwd = $DIRMGRPWD
SlapdConfigForMC = yes
Suffix = $CONFIGDS
UseExistingMC = 0
AddSampleEntries = No
EOF

echo "NOTE: Verifying that /root/ConfigDS.inf exists"
if [[ ! -s /root/ConfigDS.inf ]]; then
   echo "ERROR: Couldn't create /root/ConfigDS.inf"
   exit
else
   echo "NOTE: Good! /root/ConfigDS.inf seems to exist"
fi

echo "NOTE: Running /opt/dirsrv/sbin/setup-ds-admin.pl -s -f /root/ConfigDS.inf" 
if !  /opt/dirsrv/sbin/setup-ds-admin.pl -s -f /root/ConfigDS.inf
then
   echo "ERROR: setup failed" 
   exit
fi

###
### create a directory instance for the user data
###

echo "NOTE: Building /root/hpeDS.inf" 
cat >/root/hpeDS.inf <<EOF

[General]
SuiteSpotGroup = other
SuiteSpotUserID = www
FullMachineName = $FQDN

[slapd]
InstallLdifFile = suggest
ServerIdentifier = $DATAID
ServerPort = $DATAPORT
AddOrgEntries = No
RootDN = $DIRMGR
RootDNPwd = $DIRMGRPWD
Suffix = $DATADN
AddSampleEntries = No
EOF

echo "NOTE: Running /opt/dirsrv/sbin/setup-ds.pl -s -f /root/hpeDS.inf" 
if ! /opt/dirsrv/sbin/setup-ds.pl -s -f /root/hpeDS.inf 
then
   echo "ERROR: hpeDS setup failed" 
   exit
fi

###
### migrate passwd and group data to the directory server
###

echo "NOTE: Setting LDAP_BASEDN" 
export LDAP_BASEDN="$DATADN"

echo "NOTE: Executing migrate_base.pl" 
if ! /opt/ldapux/migrate/migrate_base.pl >/tmp/base.ldif
then
   echo "ERROR: migrate_base.pl failed" 
   exit
fi

echo "NOTE: Executing migrate_passwd.pl" 
pwunconv 2>$LOGFILE
awk -F: '$3 != 0 {print}' /etc/passwd > /tmp/passwd
if ! /opt/ldapux/migrate/migrate_passwd.pl /tmp/passwd /tmp/passwd.ldif 
then
   echo "ERROR: migrate_passwd.pl failed" 
   exit
fi

echo "NOTE: Executing migrate_group.pl" 
if ! /opt/ldapux/migrate/migrate_group.pl /etc/group /tmp/group.ldif
then
   echo "ERROR: migrate_group.pl failed" 
   exit
fi

echo "NOTE: Uploading /tmp/base.ldif" 
ldapmodify -a \
           -c \
           -h localhost \
           -p "$DATAPORT" \
           -D "$DIRMGR" \
           -w "$DIRMGRPWD" \
           -f /tmp/base.ldif 

echo "NOTE: Uploading /tmp/passwd.ldif" 
ldapmodify -a \
           -c \
           -h localhost \
           -p "$DATAPORT" \
           -D "$DIRMGR" \
           -w "$DIRMGRPWD" \
           -f /tmp/passwd.ldif

echo "NOTE: Uploading /tmp/group.ldif" 
ldapmodify -a \
           -c \
           -h localhost \
           -p "$DATAPORT" \
           -D "$DIRMGR" \
           -w "$DIRMGRPWD" \
           -f /tmp/group.ldif

echo "NOTE: Done!" 

###
### suggest command for testing
###

echo '
NOTE: Try the following commands to verify your server:

      /opt/ldapux/bin/ldapsearch \
           -h 127.0.0.1 \
           -b "ou=People,ou=hpe,o=hp.com" \
           uid=*

      /opt/ldapux/bin/ldapsearch \
           -h 127.0.0.1 \
           -b "ou=Groups,ou=hpe,o=hp.com" \
           cn=*
'

