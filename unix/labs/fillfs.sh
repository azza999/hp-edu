#!/usr/bin/sh

####################################################################
#
# FILLFS.SH
#
# This program fills the /home file system to approximately 100%
# capacity as a part of HP's file system management lab.  Having
# After running the program, students must determine which file
# system is full, and which directory within the file system is the
# culprit.
#
# WARNING: THIS IS NOT A SIMULATION!
#          THIS PROGRAM REALLY WILL FILL THE /home FILE SYSTEM!
#          THIS SCRIPT SHOULD ONLY BE RUN IN A CLASSROOM ENVIRONMENT!
#
# Having identified the problem, students should attempt to remove
# core files and perhaps extend the file system to alleviate the 
# file system full messages.
#
# The program requires the /home file system to be in a separate
# logical volume.  Ideally, the home file system should be fairly 
# small (i.e.: Ideally, no more than 100MB).  If /home is much 
# larger, the script may take an inordinate amount of time to 
# fill the file system.  /home may be either vxfs or hfs.
#
# This lab may also cause problems if root's home directory
# is under /home, since a full file system may cause problems
# for root's shell history log or CDE.
#
####################################################################

###
### Ensure that the /home file system is mounted.
### If it isn't, exit.
###

if ! mount -v | grep /home >/dev/null; then
   print "ERROR! /home must be mounted for this script to run."
   print "       Please mount the file system and run $0 again."
   exit 99
fi

###
### The program will fill user5's home directory.
### If user5's home directory doesn't exist, exit.
###

if [[ ! -d ~user5 ]]
then
   print "ERROR! user5 must have a home directory before this script will work!"
   exit 99
fi

###
### Begin filling user5's home directory.
### 

print "============================================================"
print "In the process of filling a file system."
print "This program may generate file system full messages."
print "Please be patient. This may take several minutes."
print "============================================================"
print

###
### Create a pseudo-core file in ~user5.
###

cp /usr/bin/ls ~user5/core

###
### Copy /stand/vmunix to ~user5 until the file system is full.
###

n=1
while 
   cp /stand/vmunix ~user5/bigfile$n 2>/dev/null
do
   ((n=n+1))
done

###
### Pause for a moment ...
###

sleep 2

###
### If there is more space in /home, but not enough for another
### copy of vmunix, finish the job with a few copies of /usr/bin/ls.
###

while 
   cp /usr/bin/ls ~user5/bigfile$n 2>/dev/null
do
   ((n+=1))
done

print
print "============================================================"
print "Done!"
print "============================================================"

