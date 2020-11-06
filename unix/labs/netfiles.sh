#!/usr/bin/sh

# NAME
#   /labs/netfiles.sh - Save/Restore network config files
#
# PURPOSE
#   This script is intended to save and restore network and
#   system configuration information of systems in HP's
#   Unix and Internet security class.  After each lab exercise
#   in the course, students may run this script to restore
#   their systems to a (mostly) virgin state.  
#
# ACKNOWLEDGEMENTS
#   This is nothing more than a slightly modified version
#   of the sb_netfiles script created by Jeff Cowan of HPE
#   in Naperville, IL, USA.  The header info for Jeff's 
#   original script is shown below:
#
#     /opt/starburst/bin/sb_netfiles
#     A.04.07.00 990612
#     HP Education (Starburst-UX)
#     (c) Copyright 1999 Hewlett-Packard
#
#   Only three changes were made from Jeff's original script:
#     * The value of the ARCH_DIR variable
#       from /var/opt/starburst to /var/tmp/netfiles to make 
#       the script usable in non-starburst environments; and
#     * "sb_netfiles" was changed to "netfiles" in the
#       USAGE message to reflect the name of this modified script.
#     * several additional files have been added to the archive
#       list to accomodate changes in the OS.
# 
# SYNOPSIS
#   netfiles -l [archive_name]
#   netfiles -s archive_name
#   netfiles -r archive_name
#   netfiles -d
#
# DESCRIPTION
#   netfiles saves (-s) and restores (-r) network configuration files
#   of a system.  Files are saved to and restored from an archive by name.
#   System will automatically reboot when restoring a network configuration.
#   When run with the -l option (default), a list of archives is output.
#   Supplying an existing archive name with the -l option will obtain a
#   file listing of that archive.  The -d option is used to display the
#   list of file path names that would be saved to an archive when the -s
#   option is used.
#
#   The archive_name "INITIAL" is special.  It is the network files saved
#   immediately after the system install was completed.  When restored,
#   the default gateway is checked.  If one doesn't exist, the default
#   gateway is configured.
#
# WARNING
#   The system will automatically reboot when restoring from an archive.
#
#   This script is designed for a classroom "crash & burn" environment.
#   Do NOT run this script on a production machine!  There is no assurance
#   that this script will be successful in recovering a network
#   configuration in every situation.
#
# FILES
#   /var/tmp/netfiles/*.tar.gz
#   /sbin/rc1.d/S101restore


PATH=/usr/bin:/usr/sbin:/sbin:/usr/contrib/bin
PATH=$PATH:/opt/ignite/bin:/opt/starburst/bin

typeset -l RESP=

ARCH_DIR=/var/tmp/netfiles      
[[ ! -d $ARCH_DIR ]] && mkdir -p $ARCH_DIR

#  There are some likely situations where gzip/gunzip will be destroyed by
#  the student during labs.  Save a copy when we first run.  Use the
#  saved copy if ever they are found.

if [[ -x /usr/contrib/bin/gunzip ]]; then
    GUNZIP=/usr/contrib/bin/gunzip
    if [[ ! -x $ARCH_DIR/gunzip ]]; then
        cp $GUNZIP $ARCH_DIR/gunzip
        chown 2:2 $ARCH_DIR/gunzip
        chmod 0555 $ARCH_DIR/gunzip
    fi
elif [[ -x $ARCH_DIR/gunzip ]]; then
    GUNZIP=$ARCH_DIR/gunzip
else
    GUNZIP=
fi

if [[ -x /usr/contrib/bin/gzip ]]; then
    GZIP=/usr/contrib/bin/gzip
    if [[ ! -x $ARCH_DIR/gzip ]]; then
        cp $GZIP $ARCH_DIR/gzip
        chown 2:2 $ARCH_DIR/gzip
        chmod 0555 $ARCH_DIR/gzip
    fi
elif [[ -x $ARCH_DIR/gzip ]]; then
    GZIP=$ARCH_DIR/gzip
else
    GZIP=
fi

RCF=/sbin/rc1.d/S101restore   # RC script for restore commands.

function Cleanup {
    rm -rf $TMP*
    exit
}
trap "Cleanup" EXIT
TMP=$(mktemp)

USAGE='
Usage:  netfiles -l                  List existing archives
        netfiles -l archive_name     List content of an archive
        netfiles -s archive_name     Save to archive
        netfiles -r archive_name     Restore from archive
        netfiles -d                  Display master file list

        archive_name = Name composed of one or more characters "A-Z",
                       "a-z", "0-9", or "_".

                       The archive name "INITIAL" is special.  It is the
                       initial set of network files saved immediately after
                       the system install was completed.'


#  Create the list of files that is to be saved/restored.

FILES=' /*/*/.netrc
        /*/*/.rhosts
        /*/.netrc
        /*/.rhosts
        /.netrc
        /.rhosts
        /etc/auto*
        /etc/bootptab
        /etc/default/security
        /etc/dhcp*
	/etc/d_passwd
	/etc/dialups
        /etc/exports
        /etc/fstab
        /etc/ftp*
        /etc/gated.conf
        /etc/group
        /etc/hosts
        /etc/hosts.allow
        /etc/hosts.deny
        /etc/hosts.equiv
        /etc/inetd.conf
        /etc/inetsvcs.conf
        /etc/issue 
        /etc/mail*
	/etc/motd 
        /etc/mrouted.conf
        /etc/named*
        /etc/netgroup
        /etc/networks
        /etc/nsswitch.conf
        /etc/ntp*
        /etc/opt/dirsrv/
        /etc/opt/ipf/
        /etc/opt/ldapux/
        /etc/opt/ssh/
        /etc/pam.conf
        /etc/passwd
        /etc/pfs_fstab
        /etc/profile
        /etc/protocols
        /etc/rarpd.conf
        /etc/rc.config.d/Hp*
        /etc/rc.config.d/hp*
        /etc/rc.config.d/mailservs
        /etc/rc.config.d/namesvrs
        /etc/rc.config.d/namesvrs_dns
        /etc/rc.config.d/net
        /etc/rc.config.d/netconf
        /etc/rc.config.d/netdaemons
        /etc/rc.config.d/nettl
        /etc/rc.config.d/nfsconf
        /etc/rc.config.d/Nds*
        /etc/rc.config.d/pd
        /etc/rc.config.d/sshd
        /etc/resolv.conf
        /etc/rmtab
        /etc/rpc
	/etc/securenets    
	/etc/secureservers 
	/etc/securetty    
        /etc/services
	/etc/syslog.conf 
        /etc/xtab
	/home/ftp       
        /*/root/.dtprofile
        /*/root/.profile
        /*/root/.shrc
        /*/root/.ssh
	/home/tftpdir  
	/tcb          
	/usr/lbin/telnetd 
	/usr/lbin/ftpd
	/usr/local/etc/httpd/conf/srm.conf
	/usr/local/etc/httpd/htdocs/index.html 
	/usr/local/etc/httpd/cgi-bin          
        /var/adm/inetd.sec
        /var/adm/userdb/
        /var/nis
        /var/opt/dirsrv/
        /var/opt/pd
        /var/yp '


#  Parse command line.

if (( $# == 0 )); then
    print "$USAGE"
    exit
fi

ACTION=list
ARCH=
ARCH_F=
while (( $# > 0 ))
do
    case $1 in
    -d)
        if (( $# > 1 )); then
            print "Too many arguments.$USAGE"
            exit 1
        fi
        ACTION=display
        shift
        ;;
    -l)
        if (( $# > 2 )); then
            print "Too many arguments.$USAGE"
            exit 1
        fi
        ACTION=list
        if (( $# == 2 )); then
            ARCH=$2
            if print $ARCH | grep -Eqv "^[A-Za-z0-9_]+$"; then
                print "Archive name \"$ARCH\" contains illegal character(s).$USAGE"
                exit 1
            fi
            ARCH_F=$ARCH_DIR/$ARCH.tar.gz
            if [[ ! -f $ARCH_F ]]; then
                print "Archive \"$2\" does not exist.$USAGE"
                exit 1
            fi
            shift 2
        else
            shift
        fi
        ;;
    -s)
        if (( $# < 2 )); then
            print "\"-s\" requires archive_name.$USAGE"
            exit 1
        fi
        if (( $# > 2 )); then
            print "Too many arguments.$USAGE"
            exit 1
        fi
        ACTION=save
        ARCH=$2
        if print $ARCH | grep -Eqv "^[A-Za-z0-9_]+$"; then
            print "Archive name \"$ARCH\" contains illegal character(s).$USAGE"
            exit 1
        fi
        ARCH_F=$ARCH_DIR/$ARCH.tar.gz
        if [[ -f $ARCH_F && $ARCH = INITIAL ]]; then
            print "Archive name \"$ARCH\" is special.  Use another name.$USAGE"
            exit 1
        fi
        shift 2
        ;;
    -r)
        if (( $# < 2 )); then
            print "\"-r\" requires archive_name.$USAGE"
            exit 1
        fi
        if (( $# > 2 )); then
            print "Too many arguments.$USAGE"
            exit 1
        fi
        ACTION=restore
        ARCH=$2
        if print $ARCH | grep -Eqv "^[A-Za-z0-9_]+$"; then
            print "Archive name \"$ARCH\" contains illegal character(s).$USAGE"
            exit 1
        fi
        ARCH_F=$ARCH_DIR/$ARCH.tar.gz
        if [[ ! -f $ARCH_F ]]; then
            print "Archive \"$2\" does not exist.$USAGE"
            exit 1
        fi
        shift 2
        ;;
    *)
        print "\"$1\" not a recognized option.$USAGE"
        exit 1
        ;;
    esac
done


case $ACTION in

display)
    print "$FILES" | sed -e "s/^ *\([^ ]*\) *$/\1/"
    ;;

list)
    if [[ ${ARCH_F:-NULL} != NULL ]]; then

        if [[ ${GUNZIP:-NULL} = NULL ]]; then
            print "ERROR:   /usr/contrib/bin/gunzip missing."
            exit 1
        fi

        $GUNZIP -c $ARCH_F | tar -tf -
    else
        for F in $ARCH_DIR/*.tar.gz
        do
            [[ $F = "$ARCH_DIR/*.tar.gz" ]] && continue

            ls -l $F
        done | \
        awk '
            BEGIN { n=0 }
            {
                sub("^.*/","",$9)
                sub(".tar.gz$","",$9)
                printf("%-16s  %s %2s %s\n",$9,$6,$7,$8)
                n++
            }
            END {
                if (n > 0) exit 0
                else exit 1
            }

        ' || print "No archives found."
    fi
    ;;

save)
    if [[ -f $ARCH_F ]]; then
        while :
        do
            print -n "Archive \"$ARCH\" already exists.  Overwrite (yes|no)? "
            read RESP
            if [[ ${RESP:-NULL} = no ]]; then
                print "NOTE:    Network configuration NOT saved."
                exit
            elif [[ ${RESP:-NULL} = yes ]]; then
                break
            else
                continue
            fi
        done
    fi

    if [[ ${GZIP:-NULL} = NULL ]]; then
        print "ERROR:   /usr/contrib/bin/gzip missing."
        exit 1
    fi

    print "NOTE:    Saving network configuration..."
    tar -cf - $FILES 2>/dev/null | $GZIP -c >$ARCH_F &&
    NO_PROBLEMS=true || NO_PROBLEMS=false

    if $NO_PROBLEMS; then
        print "NOTE:    Network configuration saved in archive \"$ARCH\"."
    else
        rm -f $ARCH_F
        print "ERROR:   Save has FAILED!  Archive \"$ARCH\" not created."
    fi
    ;;

restore)
    print "You are about to restore a network configuration from"
    print "archive \"$ARCH\".  System will be rebooted automatically.\n"

    while :
    do
        print -n "Do you wish to continue (yes|no)? "
        read RESP
        if [[ ${RESP:-NULL} = no ]]; then
            print "NOTE:    Network configuration NOT restored."
            exit
        elif [[ ${RESP:-NULL} = yes ]]; then
            break
        else
            continue
        fi
    done


    print "NOTE:    Preparing system for restore..."

    if [[ ${GUNZIP:-NULL} = NULL ]]; then
        print "ERROR:   /usr/contrib/bin/gunzip missing."
        exit 1
    fi

    $GUNZIP -c $ARCH_F | tar -xf - /etc/fstab

    #  Create a run-level 1 RC script to remove/restore network
    #  configuration files during a reboot.  There's no conflicts
    #  with naming services and NFS at that time.  Have the script
    #  remove itself once it's been executed.

    cat <<!EOF >$RCF
#!/sbin/sh
PATH=$PATH
export PATH
rval=0
function set_return {
    x=\$?
    if [[ \$x -ne 0 ]]; then
        print "EXIT CODE: \$x (\$1)"
        rval=1
    fi
}
case \$1 in
start_msg)
    print "Restore network configuration ($ARCH)"
    ;;
stop_msg)
    print
    ;;
start)
    echo "passwd: files"  >/etc/nsswitch.conf
    echo "group:  files" >>/etc/nsswitch.conf
    rm -rf $(print "$FILES" | awk '{list=list " " $1} END {print list}')
    set_return rm
    $GUNZIP -c $ARCH_F | tar -xf -
    set_return gunzip/tar
!EOF

    #  If restoring initial network files, make sure there's a default
    #  gateway defined in /etc/rc.config.d/netconf.  Lab configuration
    #  may have removed this.  We absolutely want it so that we are able
    #  to communicate to external networks.

    if [[ $ARCH = INITIAL ]]; then

        cat <<!EOF >>$RCF
    F=/etc/rc.config.d/netconf
    eval \$(grep "^HOSTNAME=" \$F)
    IP=\$(awk '\$2 == "'\$HOSTNAME'" { print \$1 }' /etc/hosts)
    eval \$(grep "^ROUTE_.*\\[0\\]=" \$F)
    if [[ \${ROUTE_GATEWAY[0]:-NULL} = NULL ]]; then
        awk '
            /^ROUTE_DESTINATION.*\\[0\\]=/ {
                printf("ROUTE_DESTINATION[0]=default\\n")
                printf("ROUTE_MASK[0]=\\"\\"\\n")
                printf("ROUTE_GATEWAY[0]='\$IP'\\n")
                printf("ROUTE_COUNT[0]=0\\n")
                printf("ROUTE_ARGS[0]=\\"\\"\\n")
            }
            /^ROUTE_.*\\[0\\]=/ { next }
            { print }
        ' \$F >\$F.new &&
        [[ -s \$F.new ]] && cp \$F.new \$F
        rm \$F.new
    fi
!EOF
    fi

    cat <<!EOF >>$RCF
    rm $RCF   # Remove this script after start.
    ;;
esac
exit \$rval
!EOF

    chown 2:2 $RCF
    chmod 0555 $RCF


    #  Reboot the system to initiate the restore.

    print "NOTE:    Rebooting system..."
    reboot -q
    ;;

esac

exit
