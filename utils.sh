####################################
# Common Functions
####################################
function trim() {
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"  
    echo -n "$var"
}
 
function replaceStr() {
    local str=$(trim "$1")
    local replaceThis=$(trim "$2")
    local replaceWith=$(trim "$3")
    echo ${str//"$replaceThis"/"$replaceWith"}
}
 
function toLowercase() {
    str=$(echo "$1" | tr A-Z a-z)
    echo "$str"
}
 
function toUppercase() {
    str=$(echo "$1" | tr a-z A-Z)
    echo "$str"
}
 
function cleanUpLogs() {
    expiry_days=90
    find $LOGS_PATH -mindepth 1 -type f -mtime +$expiry_days -delete &> /dev/null
}
 
function handleMissingNewLineAtEOF() {
    c=`tail -c 1 $1`
    if [ "$c" != "" ]; then echo "" >> $1; fi
}
 
function printArray() {
    var=$(declare -p "$1")
    eval "declare -A _arr=${var#*=}"
    for k in "${!_arr[@]}"; do
        echo "$k = "${_arr[$k]}""
    done
}
 
function loadConfigFiles() {
    log_file="$1"
    conf_files="$2" # Comma separated list of config file paths.
   
    # Read config files.
    for i in $(echo "$conf_files" | sed "s/,/ /g"); do
        handleMissingNewLineAtEOF $i
        ifp=`readlink -f $i`
        while IFS=$'= \t' read key value; do
            [[ "$key" = [\#!]* ]] || [[ "$key" = "" ]] || props["$key"]="$value"
        done < "$i" || die $log_file "Failed to read config file: '$ifp'."
        pass $log_file "Successfully loaded config file: '$ifp'."
    done
 
    # Replace all parametrized values.
    info $log_file "Performing parameter substitution..."
    for i in "${!props[@]}"; do
        key=$i
        value=$(trim "${props[$key]}")
        while [[ "$value" =~ "<" && "$value" =~ ">" ]]; do
            valuesToReplace=$(echo -n "$value" | grep -oP '(?<=<).*?(?=>)' | tr '\n' ',' | sed 's/.$//')
            for var in $(trim $(echo "$valuesToReplace" | sed "s/,/ /g")); do
                if [ ! -z ${props["$var"]} ]; then # Don't do the substitution if the lookup value is not in our config file.
                    value=$(replaceStr "$value" "<$var>" "${props["$var"]}")
                    props["$key"]="$value"
                else
                    value=$(replaceStr "$value" "<$var>" "${props["$var"]}")
                    warn $log_file "Failed to find a mapping for variable: '"$var"'. Please double check your config files."
                fi
            done
        done
    done || die $log_file "Failed to complete parameter substitution."
    pass $log_file "Successfully finished parameter substitution."
}
 
####################################
# Logging Functions
####################################
function logIt() {
    OIFS=$IFS
    IFS=$'\n'
    GREEN='\033[1;32m'
    RED='\033[1;31m'
    YELLOW='\033[1;33m'
    NC='\033[0m'

    log_file="$1"
    line="${@:2}"
    header=$(echo "$line" | cut -d ' ' -f1)
    ts="[$(date +"%Y-%m-%d %T")]:"
    case $header in
        'ERROR')
            echo -e "$ts ${line/$header/[$RED $header $NC]}";;
        'PASS')
            echo -e "$ts ${line/$header/[$GREEN $header $NC]}";;
        'WARN')
            echo -e "$ts ${line/$header/[$YELLOW $header $NC]}";;
        'INFO')
            echo -e "$ts ${line/$header/[$NC $header $NC]}";;
        *)
            echo -e "$ts $line";;
    esac
    echo -e "$ts "$line"" >> "$log_file"
    IFS=$OIFS
    return $?
}
 
function printBanner() {
    log_file=$(trim $1)
    script_name=$(trim $2)
    script_version=$(trim $3)
    host=`hostname -A`
    user=`whoami`
    echo "*****************************************************************"
    logIt "$log_file" "*** Script Name:       "$script_name""
    logIt "$log_file" "*** Script Version:    "$script_version""
    logIt "$log_file" "*** Hostname:          "$host""
    logIt "$log_file" "*** Execution User:    "$user""
    logIt "$log_file" "*** Log File Path:     "$log_file""
    echo "*****************************************************************"
 
    return $?
}
 
function die() {
    log_file=$(trim $1)
    logIt "$log_file" "ERROR ${2}"
    exit ${3:--1}
}
 
function pass() {
    log_file=$(trim $1)
    logIt "$log_file" "PASS ${2}"
    return $?
}
 
function warn() {
    log_file=$(trim $1)
    logIt "$log_file" "WARN ${2}"
    return $?
}
 
function info() {
    log_file=$(trim $1)
    logIt "$log_file" "INFO ${2}"
    return $?
}
