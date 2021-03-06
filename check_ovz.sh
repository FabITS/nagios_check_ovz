#!/bin/bash

THISFILE=$0

# read commandline options,
PCNT=1
for PARAM in $@
do
    # reads options in the form --longNameOpt
    if [ "${PARAM:0:1}" == "-" ]; then
        case $PARAM in
            --help|-h )
            	echo "check_ovz.sh [options]"
            	echo ""
            	echo "Latest version available at: https://github.com/FabITS/nagios_check_ovz"
            	echo ""
            	echo "At least one option must be given."
            	echo ""
		echo "Define the limit for number of processes to trigger a warning state:"
            	echo "    --nproc-warning [num]"
            	echo "    -nw [num]"
            	echo ""
            	echo "Define the limit for number of processes to trigger a critical state:"
            	echo "    --nproc-critical [num]"
            	echo "    -nc [num]"
            	echo ""
            	echo "Define the limit for number of beancounter fails to trigger a warning state:"
            	echo "    --fail-warning [num]"
            	echo "    -fw [num]"
            	echo ""
            	echo "Define the limit for number of beancounter fails to trigger a critical state:"
            	echo "    --fail-critical [num]"
            	echo "    -fc [num]"
            	echo ""
            	exit 0
            	;;
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
	echo "no parameters given. use $THISFILE --help to show a list of options."
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
list=`vzlist 2> /dev/null`
while read -r srv
do
	if [[ "$srv" == *running* ]]; then
		running=1
		CID=`echo $srv | awk '{print $1}'`
		NPROC=`echo $srv | awk '{print $2}'`
		if [ ! -z $PROC_CRIT ] && [ $NPROC -gt $PROC_CRIT ]; then
			critical=1
			echo -n "CRITICAL: $CID has $NPROC procs\n"
		elif [ ! -z $PROC_WARN ] && [ $NPROC -gt $PROC_WARN ]; then
			warning=1
			echo -n "WARNING: $CID has $NPROC procs\n"
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
					echo -n "CRITICAL: $CID $resource has $fails fails\n"
				elif [ ! -z $FAIL_WARN ] && [ $fails -gt $FAIL_WARN ]; then
					warning=1
					resource=`echo $line | awk '{print $1}'`
					echo -n "WARNING: $CID $resource has $fails fails\n"
				fi
				
			done <<< "`egrep -A23 "$CID:" /proc/user_beancounters`"
		fi
	fi
done <<< "$list"

if [ $running -eq 0 ]; then
	echo -n "UNKNOWN: no servers running\n"
	exit 3
fi

if [ $critical -ne 0 ]; then
	exit 2
elif [ $warning -ne 0 ]; then
	exit 1
else
	exit 0
fi