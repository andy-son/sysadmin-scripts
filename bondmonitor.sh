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
# Description: Checks /var/log/messages for bonding failover events
#
#****************************************************************************
set -u

#----------------------------------------------------------------------------
# Customizable variable settings
#----------------------------------------------------------------------------

# messages log file
MESSAGES=/var/log/messages

# journal to track position in the messages file
JOURNAL=/var/run/bondmonitor.journal

#----------------------------------------------------------------------------
# OS specific definitions
#----------------------------------------------------------------------------

AWK=/usr/bin/awk
EXPR=/usr/bin/expr
GREP=/usr/bin/grep
TAIL=/usr/bin/tail
WC=/usr/bin/wc

#----------------------------------------------------------------------------
# Global Variables
#----------------------------------------------------------------------------

FAILOVERSTRING="the new active one"

# Main 

LASTLINE=0

# Extract the last read position
if [ -e ${JOURNAL} ] 
then
  LASTLINE=`${TAIL} -1 ${JOURNAL}`
else
  echo "0" > ${JOURNAL}
fi

# check filesize in case of log rotation
CURRENTSIZE=`${WC} -l ${MESSAGES} | ${AWK} '{print($1)}'`
if [ ${CURRENTSIZE} -lt ${LASTLINE} ]
then
  LASTLINE=0
fi

NUMLINES=`${EXPR} ${CURRENTSIZE} - ${LASTLINE}`

FAILOVERFOUND=`${TAIL} -n ${NUMLINES} ${MESSAGES} | ${GREP} bonding | ${GREP} "${FAILOVERSTRING}"`
if [ ! -z "${FAILOVERFOUND}" ]
then
  echo "Failover detected: ${FAILOVERFOUND}"
else
  echo "No failovers detected"
fi

echo "${CURRENTSIZE}" > ${JOURNAL}
