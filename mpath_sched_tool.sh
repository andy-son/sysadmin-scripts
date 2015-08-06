#!/bin/bash
#****************************************************************************
#
# Copyright 2015 Andy Son
# All rights reserved.
#
#****************************************************************************

#****************************************************************************
#
# File:        mpath_sched_tool.sh
# Description: changes the scheduler algorithm on the device files
#              corresponding to a given mpath label
#
#****************************************************************************
set -u

#----------------------------------------------------------------------------
# OS specific definitions
#----------------------------------------------------------------------------
AWK="/bin/awk"
CAT="/bin/cat"
GREP="/bin/grep"
MULTIPATH="/sbin/multipath"

#****************************************************************************
#       !!!!!!!!!!DO NOT ALTER ANYTHING BELOW THIS LINE!!!!!!!!!!
#****************************************************************************

#----------------------------------------------------------------------------
# Global Variables
#----------------------------------------------------------------------------
MPATH=""
ACTION=""
DEVLIST=""
ALGORITHM=""

PrintUsage()
{
  # Prints the usage of the script

  echo "Usage: $0 [--help] --mpath <multipath label> --display | --set <algorithm>"
  echo ""
  echo "  --help                    : Print usage"
  echo "  --mpath <multipath label> : The multipath label to use"
  echo "  --display                 : Display the current scheduler algorithm"
  echo "  --set <algorithm>         : Set scheduler to <algorithm> where <algorithm> is one of the following: noop, anticipatory, deadline or cfq"
  echo ""
}


while [ ${#} -ge 1 ]; do
  case ${1} in
    --help)    PrintUsage
               exit 1
               ;;

    --mpath)   shift
               MPATH=${1}
               ;;

    --display) ACTION="DISPLAY"
               ;;

    --set)     ACTION="SET"
               shift
               ALGORITHM=${1}
               ;;


    *)
               ACTION="UNKNOWN"
               echo 1>&2 "Error: Unknown option: ${1}"
               PrintUsage
               exit 1
               ;;
  esac
  shift
done

if [ -z "${MPATH}" ]
then
  echo ""
  echo "You must specify a multipath label"
  echo ""
  PrintUsage
  exit 1
fi

if [ -z ${ACTION} ]
then
  echo ""
  echo "Please specify either --display or --set <algorithm>"
  echo ""
  PrintUsage
  exit 1
fi

DEVLIST=`${MULTIPATH} -l ${MPATH} | ${GREP} -v invalid | ${GREP} : | ${AWK} '{print($3)}'`

if [ -z "${DEVLIST}" ]
then
  echo ""
  echo "ERROR: Unable to retrieve device paths for ${MPATH}. Exiting."
  echo ""
  exit 1
fi

case ${ACTION} in
  DISPLAY)
            for DEVICE in ${DEVLIST}
            do
              echo "${DEVICE}: `${CAT} /sys/block/${DEVICE}/queue/scheduler`"
            done
            exit 0
            ;;
  SET)
            if [ -z ${ALGORITHM} ]
            then
              echo ""
              echo "Please specify an algorithm"
              PrintUsage
              exit 1
            fi

            case ${ALGORITHM} in
              noop|anticipatory|deadline|cfq)
                                               for DEVICE in ${DEVLIST}
                                               do
                                                 echo "setting /sys/block/${DEVICE}/queue/scheduler to ${ALGORITHM}"
                                                 echo "${ALGORITHM}" > /sys/block/${DEVICE}/queue/scheduler
                                               done
                                               exit 0
                                               ;;
              *)
                                               echo ""
                                               echo "Unknown algorithm: ${ALGORITHM}"
                                               PrintUsage
                                               exit 1
                                               ;;
            esac
            ;;
  *)
            echo ""
            echo "Unknown action."
            PrintUsage
            exit 1
esac

exit 0


