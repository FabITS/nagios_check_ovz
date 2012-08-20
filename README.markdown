# Nagios OpenVZ Plugin

This nagios plugin checks for the number of processes running and number of beancounter fails on each configured server and creates a warning or critical state depending on the given parameters.

## Usage

check_ovz.sh
* Define the limit for number of processes to trigger a warning state
    --nproc-warning [num] OR -nw [num]
* Define the limit for number of processes to trigger a critical state
    --nproc-critical [num] OR -nc [num]
* Define the limit for number of beancounter fails to trigger a warning state
    --fail-warning [num] OR -fw [num]
* Define the limit for number of beancounter fails to trigger a critical state
    --fail-critical [num] OR -fc [num]
