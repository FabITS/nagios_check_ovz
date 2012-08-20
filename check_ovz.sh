#!/bin/bash

THISFILE=$0

# read commandline options,
PCNT=1
for PARAM in $@
do
    # reads options in the form --longNameOpt
    if [ "${PARAM:0:1}" == "-" ]; then
        case $PARAM in
            --nproc-warning|-nw )
            	PROC_WARN=`echo $@ | awk -v PCNT=$(($PCNT+1)) '{print $PCNT}'`
            	if [[ $PROC_WARN != [0-9]* ]]; then
            		echo "$PARAM is not a positive integer. aborting..."
            		exit 4
            	fi
            	;;
            --nproc-critical|-nc )
            	PROC_CRIT=`echo $@ | awk -v PCNT=$(($PCNT+1)) '{print $PCNT}'`
            	if [[ $PROC_CRIT != [0-9]* ]]; then
                        echo "$PARAM is not a positive integer. aborting..."
                        exit 4
                fi
		;;
	    --fail-warning|-fw )
                FAIL_WARN=`echo $@ | awk -v PCNT=$(($PCNT+1)) '{print $PCNT}'`
                if [[ $FAIL_WARN != [0-9]* ]]; then
                        echo "$PARAM is not a positive integer. aborting..."
                        exit 4
                fi
                ;;
	    --fail-critical|-fc )
                FAIL_CRIT=`echo $@ | awk -v PCNT=$(($PCNT+1)) '{print $PCNT}'`
                if [[ $FAIL_CRIT != [0-9]* ]]; then
                        echo "$PARAM is not a positive integer. aborting..."
                        exit 4
                fi
                ;;
            * ) echo `basename $THISFILE`: invalid option $PARAM; exit ;;
        esac
    fi
    PCNT=$(($PCNT+1))
done

if [ -z $PROC_WARN ] && [ -z $PROC_CRIT ] && [ -z $FAIL_WARN ] && [ -z $FAIL_CRIT ]; then
	echo "no parameters given. aborting..."
	exit 4
fi

if [[ $PROC_WARN == [0-9]* ]] && [[ $PROC_CRIT == [0-9]* ]] && (("$PROC_WARN" >= "$PROC_CRIT")); then
	echo "nproc-warning must be lower than nproc-critical. aborting..."
	exit 4
fi

if [[ $FAIL_WARN == [0-9]* ]] && [[ $FAIL_CRIT == [0-9]* ]] && (("$FAIL_WARN" >= "$FAIL_CRIT")); then
        echo "fail-warning must be lower than fail-critical. aborting..."
        exit 4
fi

# check logic
running=0
critical=0
warning=0

command -v vzlist >& /dev/null || { echo >&2 "vzlist is required but not found. aborting..."; exit 4; }
list=`vzlist`
while read -r srv
do
	if [[ "$srv" == *running* ]]; then
		running=1
		CID=`echo $srv | awk '{print $1}'`
		NPROC=`echo $srv | awk '{print $2}'`
		if [ ! -z $PROC_CRIT ] && [ $NPROC -gt $PROC_CRIT ]; then
			critical=1
			echo "CRITICAL: $CID has $NPROC procs"
		elif [ ! -z $PROC_WARN ] && [ $NPROC -gt $PROC_WARN ]; then
			warning=1
			echo "WARNING: $CID has $NPROC procs"
		fi
		
		if [ ! -z $FAIL_WARN ] || [ ! -z $FAIL_CRIT ]; then
			if [ ! -f /proc/user_beancounters ]; then
				echo >&2 "/proc/user_beancounters does not exist. aborting..."
				exit 4
			fi
			
			active=0
			while read -r line
			do
				line=`echo $line | sed -r 's/[0-9]+://'`
				fails=`echo $line | awk '{print $6}'`
				if [ ! -z $FAIL_CRIT ] && [ $fails -gt $FAIL_CRIT ]; then
					critical=1
					resource=`echo $line | awk '{print $1}'`
					echo "CRITICAL: $CID $resource has $fails fails"
				elif [ ! -z $FAIL_WARN ] && [ $fails -gt $FAIL_WARN ]; then
					warning=1
					resource=`echo $line | awk '{print $1}'`
					echo "WARNING: $CID $resource has $fails fails"
				fi
				
			done <<< "`egrep -A23 "$CID:" /proc/user_beancounters`"
		fi
	fi
done <<< "$list"

if [ $running -eq 0 ]; then
	echo "UNKNOWN: no servers running"
	exit 3
fi

if [ $critical -ne 0 ]; then
	exit 2
elif [ $warning -ne 0 ]; then
	exit 1
else
	exit 0
fi