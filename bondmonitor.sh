#!/bin/bash
#****************************************************************************
#
# Copyright 2015 Andy Son
# All rights reserved.
#
#****************************************************************************

#****************************************************************************
#
# File:        bondmonitor.sh
# Description: Checks /proc/net/bonding for changes to the primary bond
#              Initial revision relied on /var/log/messages but the need to
#              schedule this from a non-privileged account necessitated an
#              alternative solution. This monitor is specifically only for
#              active-backup setups
#
#              The utility of this script relies on it being scheduled on
#              a fairly frequent basis as it will only alert on changes from
#              the previous check
#
#              This script relies on being able to keep a record of its last
#              state in a persistent file defined in ${JOURNAL} variable
#
#
#****************************************************************************
set -u

#----------------------------------------------------------------------------
# Customizable variable settings
#----------------------------------------------------------------------------

# bonding proc directory
BONDPROCPATH="/proc/net/bonding"

# journal to track position in the messages file
JOURNALPATH="/var/run/bondmonitor"
JOURNAL="${JOURNALPATH}/bondmonitor.journal"

#----------------------------------------------------------------------------
# OS specific definitions
#----------------------------------------------------------------------------

AWK="/bin/awk"
GREP="/bin/grep"
LS="/bin/ls"
TAIL="/usr/bin/tail"

CMDLIST="${AWK} ${GREP} ${LS} ${TAIL}"


#****************************************************************************
#       !!!!!!!!!!!!!!END OF CUSTOMIZABLE VARIABLES!!!!!!!!!!!!!!
#       !!!!!!!!!!DO NOT ALTER ANYTHING BELOW THIS LINE!!!!!!!!!!
#****************************************************************************

#----------------------------------------------------------------------------
# Global Variables
#----------------------------------------------------------------------------

BONDMODESTRING="Bonding Mode: fault-tolerance (active-backup)"
BONDACTIVESTRING="Currently Active Slave:"
PREVBONDSTATE=""
CURRBONDSTATE=""

RETVAL=""

# Exit states
EXITERROR=100
EXITFODETECTED=1
EXITSUCCESS=0


#----------------------------------------------------------------------------
# Main
#----------------------------------------------------------------------------

# Check configurable OS paths
OSVARERROR="FALSE"

# verify that all external executables are available
for CMD in ${CMDLIST}
do
  if [[ ! -x ${CMD} ]]
  then
    echo 1>&2 "Error: Can not locate OS command: ${CMD}"
    OSVARERROR="TRUE"
  fi
done

if [[ "${OSVARERROR}" = "TRUE" ]]
then
  echo 1>&2 "FATAL: Required external OS commands can not be located!"
  exit ${EXITERROR}  # exit with error
fi

# Read in previous state
if [[ -f ${JOURNAL} ]]
then
  if [[ -r ${JOURNAL} ]]
  then
    PREVBONDSTATE=`${TAIL} -1 ${JOURNAL}`
  else
    echo 1>&2 "FATAL: ${JOURNAL} exists but is unreadable. This state file is integral to the proper function of the script. Please correct and re-run."
    exit ${EXITERROR}
  fi
else
  echo "Initial state" > ${JOURNAL}
  if [[ $? -ne 0 ]]
  then
    echo 1>&2 "FATAL: ${JOURNAL} unwritable. This state file is integral to the proper function of the script. Please correct and re-run."
    exit ${EXITERROR}
  fi
fi


if [[ ! -d ${BONDPROCPATH} ]]
then
  echo 1>&2 "Error: Unable to find ${BONDPROCPATH}. Please ensure bonding is enabled in this enviornment."
  exit ${EXITERROR}
fi

RETURNSTATUS=${EXITSUCCESS}
for BONDDEV in `${LS} ${BONDPROCPATH}`
do
  BONDACTIVEINT=""
  if [[ ! -z "`${GREP} \"${BONDMODESTRING}\" ${BONDPROCPATH}/${BONDDEV}`" ]]
  then
    BONDACTIVEINT="`${GREP} \"${BONDACTIVESTRING}\" ${BONDPROCPATH}/${BONDDEV} | ${AWK} '{print($4)}'`"
    CURRBONDSTATE="${BONDDEV}:${BONDACTIVEINT} ${CURRBONDSTATE}"

    if [[ "${PREVBONDSTATE}" =~ "${BONDDEV}" ]]
    then

      FAILOVERDETECTED="FALSE"

      for STATE in ${PREVBONDSTATE}
      do
        STATEDEV=`echo ${STATE} | ${AWK} -F: '{print($1)}'`
        if [[ "${STATEDEV}" = "${BONDDEV}" ]]
        then
          STATEINT=`echo ${STATE} | ${AWK} -F: '{print($2)}'`
          if [[ "${STATEINT}" != "${BONDACTIVEINT}" ]]
          then
            FAILOVERDETECTED="TRUE"
            echo 1>&2 "Failover detected on ${BONDDEV}: Current active interface: ${BONDACTIVEINT} Previous active interface: ${STATEINT}"
          fi
        fi
      done

      if [[ "${FAILOVERDETECTED}" = "TRUE" ]]
      then
        RETURNSTATUS=${EXITFODETECTED}
      fi
    fi
  fi
done

# Make note of current state
echo "${CURRBONDSTATE}" > ${JOURNAL}


exit ${RETURNSTATUS}

