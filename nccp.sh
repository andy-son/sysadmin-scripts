#!/bin/bash
#****************************************************************************
#
# Copyright 2015 Andy Son
# All rights reserved.
#
#****************************************************************************

#****************************************************************************
#
# File:        netcat_tarpipe.sh
# Description: Copies files through the use of a tar pipe using netcat
#
#
#****************************************************************************
set -u

FILELIST=""
SOURCEIP=""
DESTIP=""
PORT=""
DESTDIR=""


#----------------------------------------------------------------------------
# Global Variables
#----------------------------------------------------------------------------

NETCAT_TIMEOUT="30"

#----------------------------------------------------------------------------
# OS specific definitions
#----------------------------------------------------------------------------
#
# Ensure these paths are correct for the respective side

HOST_TAR="/opt/csw/bin/gtar"
HOST_PIGZ="/opt/csw/bin/pigz"
HOST_NETCAT="/opt/csw/bin/netcat"
HOST_CAT="/usr/bin/cat"
HOST_SSH="/usr/bin/ssh"


DEST_TAR="/bin/tar"
DEST_PIGZ="/usr/bin/pigz"
DEST_NETCAT="/usr/bin/nc"

#****************************************************************************
#       !!!!!!!!!!DO NOT ALTER ANYTHING BELOW THIS LINE!!!!!!!!!!
#****************************************************************************

PrintUsage()
{
  # Prints the usage of the script

  echo ""
  echo "Usage: ${0} [--help] --list <listfile> --sourceip <source_ip> --destip <destination_ip> --port <port> --destdir <destinpation_dir>"
  echo ""
  echo "  --help     : Print usage"
  echo "  --list     : List of files to copy"
  echo "  --sourceip : IP address of the source server"
  echo "  --destip   : IP address of the destination Server"
  echo "  --port     : TCP port to use"
  echo "  --destdir  : destination path"
  echo ""
}


while [ $# -ge 1 ]; do
  case ${1} in
    --help)     PrintUsage
                exit 1
                ;;

    --list)     shift
                FILELIST=${1}
                ;;

    --sourceip) shift
                SOURCEIP=${1}
                ;;

    --destip)   shift
                DESTIP=${1}
                ;;

    --port)     shift
                PORT=${1}
                ;;

    --destdir)  shift
                DESTDIR=${1}
                ;;

    *)
               echo 1>&2 "Error: Unknown option: ${1}"
               PrintUsage
               exit 1
               ;;
  esac
  shift
done

if [ -z "${FILELIST}" ] || [ -z "${SOURCEIP}" ] || [ -z "${DESTIP}" ] || [ -z "${PORT}" ] || [ -z "${DESTDIR}" ]
then
  echo "Missing parameters"
  PrintUsage
  exit 1
fi

#echo "${HOST_TAR} cf - `${HOST_CAT} ${FILELIST}` | ${HOST_PIGZ} | ${HOST_NETCAT} -l -p ${PORT} & ${HOST_SSH} -o StrictHostKeyChecking=no ${DESTIP} \"${DEST_NETCAT} -w ${NETCAT_TIMEOUT} -s ${DESTIP} ${SOURCEIP} ${PORT} | ${DEST_PIGZ} -d | ${DEST_TAR} xf - -C ${DESTDIR}\""
${HOST_TAR} cf - `${HOST_CAT} ${FILELIST}` | ${HOST_PIGZ} | ${HOST_NETCAT} -l -p ${PORT} & ${HOST_SSH} -o StrictHostKeyChecking=no ${DESTIP} "${DEST_NETCAT} -w ${NETCAT_TIMEOUT} -s ${DESTIP} ${SOURCEIP} ${PORT} | ${DEST_PIGZ} -d | ${DEST_TAR} xf - -C ${DESTDIR}"

