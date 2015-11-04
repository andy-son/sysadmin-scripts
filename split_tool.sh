#!/bin/bash
#****************************************************************************
#
# Copyright 2015 Andy Son
# All rights reserved.
#
#****************************************************************************

#****************************************************************************
#
# File:        split_tool.sh
# Description: Splits a large file into several files using the split 
#              command. Also generates MD5 sums for the split files.
#              The script can be used to check two sets of MD5 sum files
#              for any differences. Finally, the script can be used to 
#              join the split files back together.
#
#****************************************************************************
set -u 

#----------------------------------------------------------------------------
# Customizable variable settings
#----------------------------------------------------------------------------


#----------------------------------------------------------------------------
# OS specific definitions
#----------------------------------------------------------------------------
AWK="/usr/bin/awk"
CAT="/bin/cat"
DIFF="/usr/bin/diff"
HOSTNAME="/bin/hostname"
MD5SUM="/usr/bin/md5sum"
SED="/bin/sed"
SPLIT="/usr/bin/split"

#****************************************************************************
#       !!!!!!!!!!DO NOT ALTER ANYTHING BELOW THIS LINE!!!!!!!!!!
#****************************************************************************

#----------------------------------------------------------------------------
# Global Variables
#----------------------------------------------------------------------------
ACTION=""
DEFAULTSPLITSIZE=10000
SPLITSIZE=""
INPUTFILE=""
OUTPUTFILE=""
SUFFIX1=""
SUFFIX2=""

CheckOsVars()
{
  VARERROR="FALSE"

  # verify that all external executables are available
  for CMD in ${AWK} ${CAT} ${DIFF} ${HOSTNAME} ${MD5SUM} ${SED} ${SPLIT}
  do
    if [ ! -x ${CMD} ]
    then
      echo 1>&2 "Error: Can not locate OS command: ${CMD}"
      VARERROR="TRUE"
    fi
  done

  if [ "${VARERROR}" = "TRUE" ]
  then
    echo 1>&2 "FATAL: Required external OS commands can not be located!"
    exit 1  # exit with error
  fi
}


PrintUsage()
{
  # Prints the usage of the script

  echo "Usage: ${0} [--help|--split|--sum|--check|--join] [--splitsize size] [--input_file filename] [--output_file filename] [--suffix1 string] [--suffix1 string]"
  echo ""
  echo "Actions: One of the following must be specified"
  echo "  --split                 : Perform split"
  echo "  --sum                   : Generate md5 sum files"
  echo "  --check                 : Compares md5 sum file sets. This requires both --suffix1 and --suffix2 be set"
  echo "  --join                  : Join the split files"
  echo "  --help                  : Print usage"
  echo ""
  echo "  --input_file filename   : The filename to provide any input to the script"
  echo "  --output_file filename  : The filename to write any output from the script"
  echo "  --splitsize size        : The size of the split files in megabytes (default is ${DEFAULTSPLITSIZE} megabytes)"
  echo "  --suffix1 string        : Used to append to the MD5 sum files if --sum is the action. If not specified, "
  echo "                          :   the hosname is used. If --check is the action, it's used in conjunction with "
  echo "                          :   --suffix2 to differentiate the 2 sets of MD5 sum files."
  echo "  --suffix2 string        : Only used if --check is the action. Used in conjuction with --suffix1 "
  echo "                          :   to differentiate 2 sets of MD5 sum files."
  echo ""
  echo ""
}

DoSplit()
{
  ${SPLIT} --verbose -b ${SPLITSIZE}m ${INPUTFILE} 2>&1 |  ${AWK} '{print($3)}' | ${SED} -e "s/\`//" -e "s/'//" -e "s/‘//" -e "s/’//" -e "/^\s*$/d" > ${OUTPUTFILE}
}

DoSum()
{
  while read file
  do
    ${MD5SUM} ${file} > ${file}.md5.${SUFFIX1}
  done < ${INPUTFILE}
}

DoCheck()
{
  while read file
  do
    if [ ! -f ${file}.md5.${SUFFIX1} ]
    then
      echo "Fatal error: ${file}.md5.${SUFFIX1} does not exist. Exiting."
      exit 1
    fi

    if [ ! -f ${file}.md5.${SUFFIX2} ]
    then
      echo "Fatal error: ${file}.md5.${SUFFIX2} does not exist. Exiting."
      exit 1
    fi

    ${DIFF} ${file}.md5.${SUFFIX1} ${file}.md5.${SUFFIX2}
    if [ ${?} != 0 ]
    then
      echo "MD5 SUM for ${file} differs."
    fi
  done < ${INPUTFILE}
}

DoJoin()
{
  while read file
  do
    ${CAT} ${file} >> ${OUTPUTFILE}
  done < ${INPUTFILE}
}

CheckForInputFileList()
{
  if [ -z "${INPUTFILE}" ]
  then
    echo "--input_file not specified. A file listing the split files must be supplied."
    echo ""
    PrintUsage
    exit 1
  elif [ ! -f "${INPUTFILE}" ]
  then
    echo "Specified input file ${INPUTFILE} does not exist. Exiting."
    exit 1
  fi
}

# Main Loop
CheckOsVars

# parse command line
while [ $# -ge 1 ]; do
  case ${1} in
    --help)                       PrintUsage 
                                  exit 0
                                  ;;

    --split|--sum|--check|--join) if [ ! -z "${ACTION}" ]
                                  then
                                    echo ""
                                    echo "Only one action may be specified at a time"
                                    echo ""
                                    PrintUsage
                                    exit 1
                                  else
                                    ACTION="${1}"
                                  fi
                                  ;;

    --splitsize)                  shift
                                  SPLITSIZE=${1}
                                  ;;

    --input_file)                 shift
                                  INPUTFILE=${1}
                                  ;;

    --output_file)                shift
                                  OUTPUTFILE=${1}
                                  ;;
  
    --suffix1)                    shift
                                  SUFFIX1=${1}
                                  ;;

    --suffix2)                    shift
                                  SUFFIX2=${1}
                                  ;;

    *)                            echo "Unknown option ${1}"
                                  PrintUsage
                                  exit 1
                                  ;;
  
  esac
  shift
done


if [ -z "${ACTION}" ]
then
  echo ""
  echo "One action needs to be specified."
  PrintUsage
  exit 1
fi

case ${ACTION} in
  --split)  echo ""
            if [ -z "${INPUTFILE}" ] || [ -z "${OUTPUTFILE}" ]
            then
              echo "An input file and an output file needs to be specified. The input file is the file to split and the output file is the list of files created by the split. This list is used as input in the join, sum and check operations."
              echo ""
              PrintUsage
              exit 1
            elif [ -f "${OUTPUTFILE}" ]
            then
              echo "${OUTPUTFILE} alread exists. Please specify a different name or remove ${OUTPUTFILE}"
              echo ""
              exit 1
            else
              echo "Performing split"
              if [ -z "${SPLITSIZE}" ]
              then
                echo "--splitsize not specified. Using default size of ${DEFAULTSPLITSIZE} megabytes"
                SPLITSIZE=${DEFAULTSPLITSIZE}
              fi
              DoSplit
              echo "Done."
              exit 0
            fi
            ;;


  --sum)    echo ""
            CheckForInputFileList
            if [ -z "${SUFFIX1}" ]
            then
              echo "--suffix1 not specified. Using hostname."
              SUFFIX1=`${HOSTNAME}`
            fi
            echo "Generating MD5 sum files."
            DoSum
            echo "Done."
            exit 0
            ;;

  --check)  echo ""
            CheckForInputFileList
            if [ -z "${SUFFIX1}" ] || [ -z "${SUFFIX2}" ]
            then
              echo "both --suffix1 and --suffix2 must be specified for --check action"
              PrintUsage
              exit 1
            else
              echo "Checking MD5 sum files."
              DoCheck
              echo "Done."
              exit 0
            fi
            ;;

  --join )  echo ""
            CheckForInputFileList
            if [ -z "${OUTPUTFILE}" ]
            then
              echo "--output_file must be specified. "
              echo ""
              PrintUsage
              exit 1
            elif [ -f "${OUTPUTFILE}" ]
            then
              echo "${OUTPUTFILE} alread exists. Please specify a different name or remove ${OUTPUTFILE}"
              echo ""
              exit 1
            else
              echo "Performing join"
              DoJoin
              echo "Done."
              exit 0
            fi
            ;;

  *)        echo ""
            echo "Unknown action. ${ACTION}"
            PrintUsage
            exit 1
            ;;

esac

exit 0
