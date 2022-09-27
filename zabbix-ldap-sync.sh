#!/bin/bash
#############################################################################################################
# Script Name ...: zabbix-ldap-sync.sh
# Version .......: V1.3.2
# Date ..........: 24.03.2022
# Description....: Synchronise Members of a Actice Directory Group with Zabbix via API
#                  User wich are removed will be deactivated
# Args ..........: 
# Author ........: Bernhard Linz
# Email Business : Bernhard.Linz@datagroup.de
# Email Private  : Bernhard@znil.de
#############################################################################################################
# Variables
Script_Version="V1.3.2 (2022-03-24)"
# Colors for printf and echo
DEFAULT_FOREGROUND=39
RED=31
GREEN=32
YELLOW=33
BLUE=34
MAGENTA=35
CYAN=36
LIGHTRED=91
LIGHTGREEN=92
LIGHTYELLOW=93
LIGHTBLUE=94
LIGHTMAGENTA=95
LIGHTCYAN=96

#############################################################################################################
#  ______                _   _                 
# |  ____|              | | (_)                
# | |__ _   _ _ __   ___| |_ _  ___  _ __  ___ 
# |  __| | | | '_ \ / __| __| |/ _ \| '_ \/ __|
# | |  | |_| | | | | (__| |_| | (_) | | | \__ \
# |_|   \__,_|_| |_|\___|\__|_|\___/|_| |_|___/
#                                              
#############################################################################################################
# Print_Error ### START Function #####################################################################
Print_Error () {
    # $1 = Message
    echo
    echo -e "+- \e[91mERROR: \e[39m------------------------------------------------------------"
    printf "$1"
    echo
    echo "+---------------------------------------------------------------------"
}
# Print_Error ### END Function #####################################################################
# Print_Status_Text ### START Function #####################################################################
Print_Status_Text () {
    if [ "$b_silent" = "false" ]; then
        printf "%-.70s" "${1} ......................................................................"
    fi
}
# Print_Status_Text ### ENDE Function #####################################################################
# Print_Status_Done ### START Function #####################################################################
Print_Status_Done () {
    # RED = 31
    # GREEN = 32
    if [ "$b_silent" = "false" ]; then
        local status_text="${1:-done}"
        local status_color="${2:-32}"
        printf " \x1b["$status_color"m%s\e[m" "$status_text"
        echo
    fi
}
# Print_Status_Done ### ENDE Function #####################################################################
# Print_Verbose_Text ### START Function #####################################################################
Print_Verbose_Text () {
    if [ "$b_verbose" = "true" ]; then
        printf "%-.69s: %s\n" "${1} ......................................................................" "${2}"
    fi
}
# Print_Verbose_Text ### ENDE Function #####################################################################
# Check_Prerequisites ### START Function #####################################################################
Check_Prerequisites () {
    # $1 = name of command
    # $2 = name of Package for Ubuntu/Debian
    # $3 = name of Package for CentOS/Red Hat
    if ! type "$1" >/dev/null 2>&1; then
        echo
        echo -e "+- \e[91mERROR: Missing Command \e[39m--------------------------------------------"
        echo -e "| \e[36m$1\e[39m is not installed!"
        echo "| try:"
        echo "| apt install $2"
        echo "| yum install $3"
        echo "+---------------------------------------------------------------------"
        exit 1
    fi
}
# Check_Prerequisites ### END Function #####################################################################
# Translate_ldapsearch_exitcode ### START Function #####################################################################
Translate_ldapsearch_exitcode () {
    case $1 in
        0) printf "0: SUCCESS";;
        1) printf "1: LDAP_OPERATIONS_ERROR";;
        2) printf "2: LDAP_PROTOCOL_ERROR";;
        3) printf "3: LDAP_TIMELIMIT_EXCEEDED";;
        4) printf "4: LDAP_SIZELIMIT_EXCEEDED";;
        7) printf "7: LDAP_AUTH_METHOD_NOT_SUPPORTED";;
        8) printf "8: LDAP_STRONG_AUTH_REQUIRED";;
        11) printf "11: LDAP_ADMINLIMIT_EXCEEDED";;
        13) printf "13: LDAP_CONFIDENTIALITY_REQUIRED";;
        16) printf "14: LDAP_NO_SUCH_ATTRIBUTE";;
        17) printf "18: LDAP_INAPPROPRIATE_MATCHING";;
        32) printf "32: LDAP_NO_SUCH_OBJECT";;
        34) printf "34: LDAP_INVALID_DN_SYNTAX";;
        48) printf "48: LDAP_INAPPROPRIATE_AUTH";;
        49) printf "49: LDAP_INVALID_CREDENTIALS";;
        50) printf "50: LDAP_INSUFFICIENT_ACCESS";;
        51) printf "51: LDAP_BUSY";;
        52) printf "52: LDAP_UNAVAILABLE";;
        255) printf "255: LDAP Can't contact LDAP server";;
        *) printf "$1: unkown error";;
    esac
    echo " (for more details: https://ldapwiki.com/wiki/LDAP%20Result%20Codes)"
}
# Translate_ldapsearch_exitcode ### END Function #####################################################################
# CompareVersionNumbers ### START Function #####################################################################
# Source: https://stackoverflow.com/questions/4023830/how-to-compare-two-strings-in-dot-separated-version-format-in-bash
CompareVersionNumbers () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}
# VersionNumbers ### END Function #####################################################################
# TestVersionNumbers ### START Function #####################################################################
# Source: https://stackoverflow.com/questions/4023830/how-to-compare-two-strings-in-dot-separated-version-format-in-bash
# TestVersionNumbers ### END Function #####################################################################
TestVersionNumbers () {
    CompareVersionNumbers $1 $2
    case $? in
        0) op='=';;
        1) op='>';;
        2) op='<';;
    esac
    if [[ $op != $3 ]]
    then
        if [ "$b_verbose" = "true" ]; then
            echo "CompareVersionNumbers: '$1' is higher than '$2'"
        fi
        # 1 = false
        return 1
    else
        if [ "$b_verbose" = "true" ]; then
            echo "CompareVersionNumbers: '$1' is lower than '$2'"
        fi
        # 0 = true
        return 0
    fi
}
# Zabbix_Logout ### START Function #####################################################################
Zabbix_Logout () {
    Print_Status_Text "Logout Zabbix API"
    if [ "$b_verbose" = "true" ]; then 
        Print_Status_Done "checking" $LIGHTCYAN
        printf 'curl -k -s -X POST -H "Content-Type:application/json" -d '
        printf "'"
        printf '{"jsonrpc": "2.0","method":"user.logout","params":[],"id":42,"'"$ZABBIX_authentication_token"'"}'
        printf "'"
        echo " $ZABBIX_API_URL"
    fi
    myJSON=$(curl -k -s -X POST -H "Content-Type:application/json"  -d '{"jsonrpc": "2.0","method":"user.logout","params":[],"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL)
    if [ "$b_verbose" = "true" ]; then echo "Answer from API: $myJSON"; fi
    if [ "$b_verbose" = "true" ]; then Print_Status_Text "Logout Zabbix API"; fi
    Print_Status_Done "done" $GREEN
    b_Zabbix_is_logged_in="false"
}
# Zabbix_Logout ### END Function #####################################################################

##################################################################################################################################################################################
#   _____ _             _               
#  / ____| |           | |              
# | (___ | |_ __ _ _ __| |_ _   _ _ __  
#  \___ \| __/ _` | '__| __| | | | '_ \ 
#  ____) | || (_| | |  | |_| |_| | |_) |
# |_____/ \__\__,_|_|   \__|\__,_| .__/ 
#                                | |    
#                                |_|    
#############################################################################################################
# Check Commandline Arguments
Config_File="<notset>"
b_Unknown_Parameter="false"
b_showpasswords="false"
b_silent="false"
b_verbose="false"
while [[ $# -gt 0 ]]; do
    current_parameter="$1"
    case $current_parameter in
        -c|-C|--config)
            Config_File="$2"
            shift # past -c / --config
            shift # past value
            ;;
        -p|-P|--ShowPassword)
            # Passwords will be displayed in Errors and in Verbose mode
            b_showpasswords="true"
            shift # past argument
            ;;
        -s|-S|--silent)
            # be quiet! only errors will be displayed
            b_silent="true"
            shift # past argument
            ;;
        -v|-V|--verbose)
            # show some extra information
            b_verbose="true"
            shift # past argument
            ;;
        *)  # Catch all other
            echo -e "\e[91mUnknown Parameter:\e[39m $1"
            # next parameter will display help and exit script after the loop
            b_Unknown_Parameter="true"
            shift # past argument
            ;;
    esac
done
if [ "$b_Unknown_Parameter" = "true" ]; then
    # ToDo: Create Help text
    echo "Parameter error - print help"
    echo
    echo " Allowed Parameter are:"
    echo "  -c | -C | --config			use a specific configuration file instead config.sh"
    echo "  -v | -V | --verbose 		Display debugging information, include all commands"
    echo "  -p | -P | --ShowPassword	Show the passwords in the verbose output"
    echo "  -s | -S | --silent			Hide all Output except errors. Usefull with crontab"
    echo
    echo "HowTo and Manual: https://github.com/BernhardLinz/zabbix-ldap-sync-bash"
    exit 1
fi
#############################################################################################################
# Clear Screen
clear
#############################################################################################################
if [ "$b_silent" = "false" ]; then
    echo "---------------------------------------------------------------------------"
    echo "zabbix-ldap-sync.sh (Version $Script_Version) startup"
fi
#############################################################################################################
# Testing for all needed commands (normaly only ldapsearch have to be installed manualy)
Print_Status_Text "Checking prerequisites"
Check_Prerequisites "ldapsearch" "ldap-utils" "openldap-clients"
Check_Prerequisites "curl" "curl" "curl"
Check_Prerequisites "sed" "sed" "sed"
Check_Prerequisites "dirname" "coreutils" "coreutils"
Check_Prerequisites "readlink" "coreutils" "coreutils"
Print_Status_Done "done" $GREEN
#############################################################################################################
#  _____                _    _____             __ _                       _   _             
# |  __ \              | |  / ____|           / _(_)                     | | (_)            
# | |__) |___  __ _  __| | | |     ___  _ __ | |_ _  __ _ _   _ _ __ __ _| |_ _  ___  _ __  
# |  _  // _ \/ _` |/ _` | | |    / _ \| '_ \|  _| |/ _` | | | | '__/ _` | __| |/ _ \| '_ \ 
# | | \ \  __/ (_| | (_| | | |___| (_) | | | | | | | (_| | |_| | | | (_| | |_| | (_) | | | |
# |_|  \_\___|\__,_|\__,_|  \_____\___/|_| |_|_| |_|\__, |\__,_|_|  \__,_|\__|_|\___/|_| |_|
#                                                    __/ |                                  
#                                                   |___/                                   
Print_Status_Text "Searching config file"
if [ "$Config_File" = "<notset>" ]; then
    # Get the current path of this running script - long solution wich is also working with symlinks
    This_Script_Bash_Source="${BASH_SOURCE[0]}"
    while [ -h "$This_Script_Bash_Source" ]; do # resolve $This_Script_Bash_Source until the file is no longer a symlink
        This_Script_Path="$( cd -P "$( dirname "$This_Script_Bash_Source" )" >/dev/null 2>&1 && pwd )"
        This_Script_Bash_Source="$(readlink "$This_Script_Bash_Source")"
        [[ $This_Script_Bash_Source != /* ]] && This_Script_Bash_Source="$This_Script_Path/$This_Script_Bash_Source" # if $This_Script_Bash_Source was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    done
    This_Script_Path="$( cd -P "$( dirname "$This_Script_Bash_Source" )" >/dev/null 2>&1 && pwd )"
    # Special case for programming - my own config file, excluded from .git
    if test -f "$This_Script_Path/config-znil.sh"; then
        Config_File="$This_Script_Path/config-znil.sh"
    else
        Config_File="$This_Script_Path/config.sh"
    fi
fi
# Normal test for the file now
if ! test -f "$Config_File"; then
    Print_Status_Done "Error" $RED
    Print_Error "$Config_File not found"
    exit 1
else
    Print_Status_Done "done" $GREEN
fi
# File exist, read it now
Print_Status_Text 'Reading "'$Config_File'"'
source $Config_File
Print_Status_Done "done" $GREEN
Print_Status_Text "Check all needed Settings"
# if [ -z ${var+x} ]; then echo "var is unset"; else echo "var is set to '$var'"; fi
if [ "$b_verbose" = "true" ]; then Print_Status_Done "checking" $LIGHTCYAN; fi
####################################################################################################
if ! [ -z ${LDAP_Source_URL+x} ]; then Print_Verbose_Text "LDAP_Source_URL" "${LDAP_Source_URL}"; else Print_Error "Missing LDAP_Source_URL"; fi
####################################################################################################
if ! [ -z ${LDAP_Ignore_SSL_Certificate+x} ]; then
    Print_Verbose_Text "LDAP_Ignore_SSL_Certificate" "${LDAP_Ignore_SSL_Certificate}"
else
    LDAP_Ignore_SSL_Certificate="true"
    Print_Verbose_Text "LDAP_Ignore_SSL_Certificate (using Default Value)" "${LDAP_Ignore_SSL_Certificate}"
fi
####################################################################################################
if ! [ -z ${LDAP_Bind_User_DN+x} ]; then Print_Verbose_Text "LDAP_Bind_User_DN" "${LDAP_Bind_User_DN}"; else Print_Error "Missing LDAP_Bind_User_DN"; fi
####################################################################################################
if [ -z ${LDAP_Bind_User_Password+x} ]; then 
    Print_Error "Missing LDAP_Bind_User_Password"
else
    if [ "$b_showpasswords" = "true" ]; then
        Print_Verbose_Text "LDAP_Bind_User_Password" "${LDAP_Bind_User_Password}";
    else
        Print_Verbose_Text "LDAP_Bind_User_Password" "${LDAP_Bind_User_Password:0:3}***************"
    fi
fi
####################################################################################################
if ! [ -z ${LDAP_SearchBase+x} ]; then Print_Verbose_Text "LDAP_SearchBase" "${LDAP_SearchBase}"; else Print_Error "Missing LDAP_SearchBase"; fi
####################################################################################################
if ! [ -z ${LDAP_Groupname_for_Sync+x} ]; then
    Print_Verbose_Text "LDAP_Groupname_for_Sync" "${LDAP_Groupname_for_Sync}"
else
    LDAP_Groupname_for_Sync="skip"
    Print_Verbose_Text "LDAP_Groupname_for_Sync" "skip sync"
fi
if [ "$LDAP_Groupname_for_Sync" = "skip" ]; then Print_Verbose_Text "LDAP_Groupname_for_Sync" "skip sync"; fi
####################################################################################################
if ! [ -z ${ZABBIX_Groupname_for_Sync+x} ]; then
    Print_Verbose_Text "ZABBIX_Groupname_for_Sync" "${ZABBIX_Groupname_for_Sync}"
else
    ZABBIX_Groupname_for_Sync="skip"
    Print_Verbose_Text "ZABBIX_Groupname_for_Sync" "skip sync"
fi
if [ "$ZABBIX_Groupname_for_Sync" = "skip" ]; then Print_Verbose_Text "ZABBIX_Groupname_for_Sync" "skip sync"; fi
####################################################################################################
if ! [ -z ${ZABBIX_Disabled_User_Group+x} ]; then
    Print_Verbose_Text "ZABBIX_Disabled_User_Group" "${ZABBIX_Disabled_User_Group}"
else
    ZABBIX_Disabled_User_Group="Disabled"
    Print_Verbose_Text "ZABBIX_Disabled_User_Group (using Default Value)" "${ZABBIX_Disabled_User_Group}"
fi
####################################################################################################
if ! [ -z ${ZABBIX_API_URL+x} ]; then Print_Verbose_Text "ZABBIX_API_URL" "${ZABBIX_API_URL}"; else Print_Error "Missing ZABBIX_API_URL"; fi
####################################################################################################
if ! [ -z ${ZABBIX_API_User+x} ]; then Print_Verbose_Text "ZABBIX_API_User" "${ZABBIX_API_User}"; else Print_Error "Missing ZABBIX_API_User"; fi
####################################################################################################
####################################################################################################
if [ -z ${ZABBIX_API_Password+x} ]; then 
    Print_Error "Missing ZABBIX_API_Password"
else
    if [ "$b_showpasswords" = "true" ]; then
        Print_Verbose_Text "ZABBIX_API_Password" "${ZABBIX_API_Password}";
    else
        Print_Verbose_Text "ZABBIX_API_Password" "${ZABBIX_API_Password:0:3}***************";
    fi
fi
####################################################################################################
if ! [ -z ${ZABBIX_UserType_User+x} ]; then
    Print_Verbose_Text "ZABBIX_UserType_User" "${ZABBIX_UserType_User}"
else
    ZABBIX_UserType_User=1
    Print_Verbose_Text "ZABBIX_UserType_User (using Default Value)" "${ZABBIX_UserType_User}"
fi
####################################################################################################
if ! [ -z ${ZABBIX_MediaTypeID+x} ]; then
    Print_Verbose_Text "ZABBIX_MediaTypeID" "${ZABBIX_MediaTypeID}"
else
    ZABBIX_MediaTypeID=1
    Print_Verbose_Text "ZABBIX_MediaTypeID (using Default Value)" "${ZABBIX_MediaTypeID}"
fi
####################################################################################################
if [ "$b_verbose" = "false" ]; then
    Print_Status_Done "done" $GREEN
else
    Print_Status_Text "Check all needed Settings"
    Print_Status_Done "done" $GREEN
fi

#############################################################################################################
#   ____                          _      _____          _____  
#  / __ \                        | |    |  __ \   /\   |  __ \ 
# | |  | |_   _  ___ _ __ _   _  | |    | |  | | /  \  | |__) |
# | |  | | | | |/ _ \ '__| | | | | |    | |  | |/ /\ \ |  ___/ 
# | |__| | |_| |  __/ |  | |_| | | |____| |__| / ____ \| |     
#  \___\_\\__,_|\___|_|   \__, | |______|_____/_/    \_\_|     
#                          __/ |                               
#                         |___/                                
#
declare -a LDAP_ARRAY_Members_RAW           # Raw Data from ldapsearch
declare -a LDAP_ARRAY_Members_DN            # Distinguished names extracted from LDAP_ARRAY_Members_RAW
Print_Status_Text "STEP 1: Getting all Members from Active Directory / LDAP Group"
if [ "$b_verbose" = "true" ]; then Print_Status_Done "checking" $LIGHTCYAN; fi
if [ "$b_verbose" = "true" ]; then
    echo
    echo "STEP 1: Getting all Members from Active Directory / LDAP Group"
    echo "--------------------------------------------------------------"
    echo "Group Name SuperAdmin : $LDAP_Groupname_for_Sync"
    echo "LDAP Server ..........: $LDAP_Source_URL"
    echo "LDAP User ............: $LDAP_Bind_User_DN"
    echo "LDAP Search Base .....: $LDAP_SearchBase"
    echo "--------------------------------------------------------------"
    echo "running ldapsearch:"
fi
if [ LDAP_Ignore_SSL_Certificate = "false" ]; then
    # normal ldapsearch call
    if [ "$b_verbose" = "true" ]; then
        if [ "$b_showpasswords" = "true" ]; then
            echo 'ldapsearch -x -o ldif-wrap=no -H '$LDAP_Source_URL' -D "'$LDAP_Bind_User_DN'" -w "'$LDAP_Bind_User_Password'" -b "'$LDAP_SearchBase'" "(&(objectClass=group)(cn="'$LDAP_Groupname_for_Sync'"))"'
        else
            echo 'ldapsearch -x -o ldif-wrap=no -H '$LDAP_Source_URL' -D "'$LDAP_Bind_User_DN'" -w "***********" -b "'$LDAP_SearchBase'" "(&(objectClass=group)(cn="'$LDAP_Groupname_for_Sync'"))"'
        fi
    fi
    # yes, ldapsearch is called twice - first time without grep to catch the exitcode, 2. time to catch the content
    tempvar=`ldapsearch -x -o ldif-wrap=no -H $LDAP_Source_URL -D "$LDAP_Bind_User_DN" -w "$LDAP_Bind_User_Password" -b "$LDAP_SearchBase" "(&(objectClass=group)(cn=$LDAP_Groupname_for_Sync))" o member`
    ldapsearch_exitcode="$?"
    if [ "$b_verbose" = "true" ]; then echo "ldapsearch_exitcode: $ldapsearch_exitcode"; fi
    tempvar=`ldapsearch -x -o ldif-wrap=no -H $LDAP_Source_URL -D "$LDAP_Bind_User_DN" -w "$LDAP_Bind_User_Password" -b "$LDAP_SearchBase" "(&(objectClass=group)(cn=$LDAP_Groupname_for_Sync))" o member | grep member:`
else
    # ignore SSL ldapsearch
    if [ "$b_verbose" = "true" ]; then
        if [ "$b_showpasswords" = "true" ]; then
            echo 'LDAPTLS_REQCERT=never ldapsearch -x -o ldif-wrap=no -H '$LDAP_Source_URL' -D "'$LDAP_Bind_User_DN'" -w "'$LDAP_Bind_User_Password'" -b "'$LDAP_SearchBase'" "(&(objectClass=group)(cn='$LDAP_Groupname_for_Sync'))" o member'
        else
            echo 'LDAPTLS_REQCERT=never ldapsearch -x -o ldif-wrap=no -H '$LDAP_Source_URL' -D "'$LDAP_Bind_User_DN'" -w "***********" -b "'$LDAP_SearchBase'" "(&(objectClass=group)(cn='$LDAP_Groupname_for_Sync'))" o member'
        fi
    fi
    # yes, ldapsearch is called twice - first time without grep to catch the exitcode, 2. time to catch the content
    tempvar=`LDAPTLS_REQCERT=never ldapsearch -x -o ldif-wrap=no -H $LDAP_Source_URL -D "$LDAP_Bind_User_DN" -w "$LDAP_Bind_User_Password" -b "$LDAP_SearchBase" "(&(objectClass=group)(cn=$LDAP_Groupname_for_Sync))" o member`
    ldapsearch_exitcode="$?"
    if [ "$b_verbose" = "true" ]; then echo "ldapsearch_exitcode: $ldapsearch_exitcode"; fi
    tempvar=`LDAPTLS_REQCERT=never ldapsearch -x -o ldif-wrap=no -H $LDAP_Source_URL -D "$LDAP_Bind_User_DN" -w "$LDAP_Bind_User_Password" -b "$LDAP_SearchBase" "(&(objectClass=group)(cn=$LDAP_Groupname_for_Sync))" o member | grep member:`
fi
if [ "$b_verbose" = "true" ]; then 
    echo 'Result ldapsearch (with "grep member:" : '"$tempvar"
    echo "Exitcode ldapsearch: $(Translate_ldapsearch_exitcode $ldapsearch_exitcode)"
fi
# only continue if ldapsearch was succesfull
if [ "$ldapsearch_exitcode" -eq 0 ];then
    LDAP_ARRAY_Members_RAW=($tempvar) # Split the raw output into an array
    LDAP_ARRAY_Members_DN=()
    for (( i=0; i < ${#LDAP_ARRAY_Members_RAW[*]}; i++ )); do
        # Double colon means base64 encoded data: https://www.ietf.org/rfc/rfc2849.txt
        if [ "${LDAP_ARRAY_Members_RAW[$i]:0:8}" = "member::" ]; then
            i=$(($i + 1))
            LDAP_ARRAY_Members_DN+=("`echo ${LDAP_ARRAY_Members_RAW[$i]} | base64 -d`") # add new Item to the end of the array
        # Search for the word "member:" in Array - the next value is the DN of a Member
        elif [ "${LDAP_ARRAY_Members_RAW[$i]:0:7}" = "member:" ]; then
            i=$(($i + 1))
            LDAP_ARRAY_Members_DN+=("${LDAP_ARRAY_Members_RAW[$i]}") # add new Item to the end of the array
        else
            # Ok, no "member:" found and the Item was not skipped by i=i+1 - must still belong to the previous Item, which was separated by a space
            last_item_of_array=${#LDAP_ARRAY_Members_DN[*]} # get the Number of Items in the array
            last_item_of_array=$(($last_item_of_array - 1)) # get the Index of the last one (0 is the first index but the number of Items would be 1)
            LDAP_ARRAY_Members_DN[$last_item_of_array]+=" ${LDAP_ARRAY_Members_RAW[$i]}" # without ( ) -> replace the Item-Value, add no new Item to the array
        fi
    done
else
    Print_Error "Exitcode ldapsearch not zero: $(Translate_ldapsearch_exitcode $ldapsearch_exitcode)\nTry -v -p and test command by hand"
    exit 1
fi
if [ "$b_verbose" = "true" ]; then Print_Status_Text "STEP 1: Getting all Members from Active Directory / LDAP Group"; fi
Print_Status_Done "done" $GREEN
if [ "$b_verbose" = "true" ]; then
    echo 'Got "Distinguished Name" for '${#LDAP_ARRAY_Members_DN[*]}' members:'
    for (( i=0; i < ${#LDAP_ARRAY_Members_DN[*]}; i++ )); do
        echo "$i: ${LDAP_ARRAY_Members_DN[$i]}"
    done
    echo "--------------------------------------------------------------"
fi
# Needed additional arrays
declare -a LDAP_ARRAY_Members_sAMAccountName
declare -a LDAP_ARRAY_Members_Surname
declare -a LDAP_ARRAY_Members_Givenname
declare -a LDAP_ARRAY_Members_Email
LDAP_ARRAY_Members_sAMAccountName=()
LDAP_ARRAY_Members_Surname=()
LDAP_ARRAY_Members_Givenname=()
LDAP_ARRAY_Members_Email=()
# Only catch the rest if there members in the group
if [ "${#LDAP_ARRAY_Members_DN[*]}" -gt 0 ]; then
    Print_Status_Text "Query sAMAccountName, sn, givenName and primary Email-Address"
    if [ "$b_verbose" = "true" ]; then Print_Status_Done "checking" $LIGHTCYAN; fi
    # Maybe a User have no Surname, Givenname and/or Email - but the will be always a sAMAccountName
    # the checks are used for testing this. Set to false for the first run of the loop
    b_check_sAMAccountName="false"
    b_check_Surname="false"
    b_check_Givenname="false"
    b_check_Email="false"
    
    for (( i=0; i < ${#LDAP_ARRAY_Members_DN[*]}; i++ )); do
        # When the Loop start again we have to for all values. All arrays-size must be equal!
        # First run of loop will be skipped because b_check_sAMAccountName is false
        if [ "$b_check_sAMAccountName" = "true" ]; then
            if [ "$b_check_Surname" = "false" ]; then
                LDAP_ARRAY_Members_Surname+=(" - ")
            fi
            if [ "$b_check_Givenname" = "false" ]; then
                LDAP_ARRAY_Members_Givenname+=(" - ")
            fi
            if [ "$b_check_Email" = "false" ]; then
                LDAP_ARRAY_Members_Email+=(" - ")
            fi
        fi
        if [ LDAP_Ignore_SSL_Certificate = "false" ]; then
            if [ "$b_verbose" = "true" ]; then
                printf "ldapsearch -x -o ldif-wrap=no -H "
                printf '"'
                printf "$LDAP_Source_URL"
                printf '" -D "'
                printf "$LDAP_Bind_User_DN"
                printf '" -w "'
                if [ "$b_showpasswords" = "true" ]; then
                    printf "$LDAP_Bind_User_Password"
                else
                    printf "***********"
                fi
                printf '" -b "'
                printf "${LDAP_ARRAY_Members_DN[$i]}"
                printf '" o sAMAccountName o sn o givenName o mail | grep "^sn: \|^givenName: \|^sAMAccountName: \|^mail:" | sed '
                echo "'s/$/|/' | sed 's/: /|/'"
            fi
            # sed replace all ": " and "new line" to "|"
            tempvar=`ldapsearch -x -o ldif-wrap=no -H $LDAP_Source_URL -D "$LDAP_Bind_User_DN" -w "$LDAP_Bind_User_Password" -b "${LDAP_ARRAY_Members_DN[$i]}" o sAMAccountName o sn o givenName o mail | grep "^sn: \|^givenName: \|^sAMAccountName: \|^mail:" | sed 's/$/|/' | sed 's/: /|/'`
        else
            if [ "$b_verbose" = "true" ]; then
                printf "LDAPTLS_REQCERT=never ldapsearch -x -o ldif-wrap=no -H "
                printf '"'
                printf "$LDAP_Source_URL"
                printf '" -D "'
                printf "$LDAP_Bind_User_DN"
                printf '" -w "'
                if [ "$b_showpasswords" = "true" ]; then
                    printf "$LDAP_Bind_User_Password"
                else
                    printf "***********"
                fi
                printf '" -b "'
                printf "${LDAP_ARRAY_Members_DN[$i]}"
                printf '" o sAMAccountName o sn o givenName o mail | grep "^sn: \|^givenName: \|^sAMAccountName: \|^mail:" | sed '
                echo "'s/$/|/' | sed 's/: /|/'"
            fi
            # sed replace all ": " and "new line" to "|"
            tempvar=`LDAPTLS_REQCERT=never ldapsearch -x -o ldif-wrap=no -H "$LDAP_Source_URL" -D "$LDAP_Bind_User_DN" -w "$LDAP_Bind_User_Password" -b "${LDAP_ARRAY_Members_DN[$i]}" o sAMAccountName o sn o givenName o mail | grep "^sn: \|^givenName: \|^sAMAccountName: \|^mail:" | sed 's/$/|/' | sed 's/: /|/'`
            if [ "$b_verbose" = "true" ]; then
                echo $tempvar
            fi
        fi
        # Remove all "New Line" (yes, again,) but keep all Spaces
        tempvar=$(echo "|${tempvar//[$'\t\r\n']}|")
        IFS=$'|' # | is set as delimiter
        LDAP_ARRAY_Members_RAW=($tempvar)
        IFS=' ' # space is set as delimiter
        b_check_sAMAccountName="false"
        b_check_Surname="false"
        b_check_Givenname="false"
        b_check_Email="false"
        for (( k=0; k < ${#LDAP_ARRAY_Members_RAW[*]}; k++ )); do
            # Check sAMAccountName
            if [ "${LDAP_ARRAY_Members_RAW[$k]}" = "sAMAccountName" ]; then
                k=$(($k + 1))
                # echo "add SAM: ${LDAP_ARRAY_Members_RAW[$k]}"
                LDAP_ARRAY_Members_sAMAccountName+=("${LDAP_ARRAY_Members_RAW[$k]}")
                b_check_sAMAccountName="true"
            fi
            if [ "${LDAP_ARRAY_Members_RAW[$k]}" = "sn" ]; then
                k=$(($k + 1))
                # echo "add SN: ${LDAP_ARRAY_Members_RAW[$k]}"
                LDAP_ARRAY_Members_Surname+=("${LDAP_ARRAY_Members_RAW[$k]}")
                b_check_Surname="true"
            fi
            if [ "${LDAP_ARRAY_Members_RAW[$k]}" = "givenName" ]; then
                k=$(($k + 1))
                # echo "add givenName: ${LDAP_ARRAY_Members_RAW[$k]}"
                LDAP_ARRAY_Members_Givenname+=("${LDAP_ARRAY_Members_RAW[$k]}")
                b_check_Givenname="true"
            fi
            if [ "${LDAP_ARRAY_Members_RAW[$k]}" = "mail" ]; then
                k=$(($k + 1))
                # echo "add Email: ${LDAP_ARRAY_Members_RAW[$k]}"
                LDAP_ARRAY_Members_Email+=("${LDAP_ARRAY_Members_RAW[$k]}")
                b_check_Email="true"
            fi
        done
    done
    # If only one user is in group and some Values are missing ... we need a special treatment for this:
    if [ "$b_check_sAMAccountName" = "true" ]; then
        if [ "$b_check_Surname" = "false" ]; then
            LDAP_ARRAY_Members_Surname+=(" - ")
        fi
        if [ "$b_check_Givenname" = "false" ]; then
            LDAP_ARRAY_Members_Givenname+=(" - ")
        fi
        if [ "$b_check_Email" = "false" ]; then
            LDAP_ARRAY_Members_Email+=(" - ")
        fi
    fi

    Print_Status_Done "done" $GREEN
fi
unset LDAP_ARRAY_Members_RAW
if [ "$b_verbose" = "true" ]; then
    echo "------------------------------------------------------------------------------------------------"
    echo "Result from STEP 1: Getting all Members from Active Directory / LDAP Group $LDAP_Groupname_for_Sync"
    echo "----+----------------------+----------------------+----------------------+----------------------"
    printf "%-3s | %-20s | %-20s | %-20s | %-20s" "No." "sAMAccountName" "Surname" "Givenname" "Email"
    printf "\n"
    echo "----+----------------------+----------------------+----------------------+----------------------"
    for (( i=0; i < ${#LDAP_ARRAY_Members_sAMAccountName[*]}; i++ )); do
        printf "%-3s | %-20s | %-20s | %-20s | %-20s" "$i" "${LDAP_ARRAY_Members_sAMAccountName[$i]}" "${LDAP_ARRAY_Members_Surname[$i]}" "${LDAP_ARRAY_Members_Givenname[$i]}" "${LDAP_ARRAY_Members_Email[$i]}"
        printf "\n"
    done
    echo "------------------------------------------------------------------------------------------------"
    echo
    echo
fi



##########################################################################################################################
#   _____ _               _      ______     _     _     _                 _____ _____  __      __           _             
#  / ____| |             | |    |___  /    | |   | |   (_)          /\   |  __ \_   _| \ \    / /          (_)            
# | |    | |__   ___  ___| | __    / / __ _| |__ | |__  ___  __    /  \  | |__) || |    \ \  / /__ _ __ ___ _  ___  _ __  
# | |    | '_ \ / _ \/ __| |/ /   / / / _` | '_ \| '_ \| \ \/ /   / /\ \ |  ___/ | |     \ \/ / _ \ '__/ __| |/ _ \| '_ \ 
# | |____| | | |  __/ (__|   <   / /_| (_| | |_) | |_) | |>  <   / ____ \| |    _| |_     \  /  __/ |  \__ \ | (_) | | | |
#  \_____|_| |_|\___|\___|_|\_\ /_____\__,_|_.__/|_.__/|_/_/\_\ /_/    \_\_|   |_____|     \/ \___|_|  |___/_|\___/|_| |_|
#                                                                                                                         
##########################################################################################################################
# There are breaking changes at the Zabbix API since Version 5.2 or higher, so we have to check the version
Print_Status_Text "Check Zabbix API Version"
if [ "$b_verbose" = "true" ]; then 
    Print_Status_Done "checking" $LIGHTCYAN
    printf 'curl -k -s -X POST -H "Content-Type:application/json" -d '
    printf "'"
    printf '{"jsonrpc": "2.0","method":"apiinfo.version","params":[],"id":42}'
    printf "'"
    echo " $ZABBIX_API_URL"
fi
myAPIVersion=$(curl -k -s -X POST -H "Content-Type:application/json"  -d '{"jsonrpc": "2.0","method":"apiinfo.version","params":[],"id":42}' $ZABBIX_API_URL | cut -d'"' -f8)
if [ "$b_verbose" = "true" ]; then echo "Zabbix Server Version: $myAPIVersion"; fi
TestVersionNumbers "$myAPIVersion" "5.0.999" "<"
if [ "$?" = "1" ]; then
    if [ "$b_verbose" = "true" ]; then
        echo "Zabbix API Version is higher than 5.0.x - using User-RoleId-Mode"
    fi
    s_UserMode="roleid"
else
    if [ "$b_verbose" = "true" ]; then
        echo "Zabbix API Version is 5.0.x or lower - using User-Type-Mode"
    fi
    s_UserMode="type"
fi
if [ "$b_verbose" = "true" ]; then
    Print_Status_Text "Check Zabbix API Version"
fi
Print_Status_Done "done" $GREEN
Print_Status_Text "Using User mode"
Print_Status_Done "$s_UserMode" $LIGHTGREEN


#############################################################################################################
#  ______     _     _     _        _                 _       
# |___  /    | |   | |   (_)      | |               (_)      
#    / / __ _| |__ | |__  ___  __ | |     ___   __ _ _ _ __  
#   / / / _` | '_ \| '_ \| \ \/ / | |    / _ \ / _` | | '_ \ 
#  / /_| (_| | |_) | |_) | |>  <  | |___| (_) | (_| | | | | |
# /_____\__,_|_.__/|_.__/|_/_/\_\ |______\___/ \__, |_|_| |_|
#                                               __/ |        
#                                              |___/     
# Login Zabbix API and catch the authentication token
b_Zabbix_is_logged_in="false"
Print_Status_Text "Login at Zabbix API"
if [ "$b_verbose" = "true" ]; then Print_Status_Done "checking" $LIGHTCYAN; fi
if [ "$b_verbose" = "true" ]; then
    printf 'curl -k -s -X POST -H "Content-Type:application/json" -d '
    printf "'"
    if [ "$b_showpasswords" = "true" ]; then
        printf '{"jsonrpc": "2.0","method":"user.login","params":{"user":"'$ZABBIX_API_User'","password":"'$ZABBIX_API_Password'"},"id":42}'
    else
        printf '{"jsonrpc": "2.0","method":"user.login","params":{"user":"'$ZABBIX_API_User'","password":"********"},"id":42}'
    fi
    printf "'"
    echo " $ZABBIX_API_URL"
fi
ZABBIX_authentication_token=$(curl -k -s -X POST -H "Content-Type:application/json" -d '{"jsonrpc": "2.0","method":"user.login","params":{"user":"'$ZABBIX_API_User'","password":"'$ZABBIX_API_Password'"},"id":42}' $ZABBIX_API_URL | cut -d'"' -f8)
Print_Verbose_Text "Authentification token" "$ZABBIX_authentication_token"
if [ "${#ZABBIX_authentication_token}" -ne 32 ]; then
    # Token must have 32 Chars - something went wrong
    Print_Status_Done "failed" $RED
    Print_Error "Login Zabbix API failed\nTry -v -p and test command by hand"
    exit 1
else
    b_Zabbix_is_logged_in="true"
fi
Print_Verbose_Text "b_Zabbix_is_logged_in" "$b_Zabbix_is_logged_in"
if [ "$b_verbose" = "true" ]; then
    Print_Status_Text "Login at Zabbix API"
fi
Print_Status_Done "done" $GREEN
#############################################################################################################
#   ____                          ______     _     _     _         _____                       
#  / __ \                        |___  /    | |   | |   (_)       / ____|                      
# | |  | |_   _  ___ _ __ _   _     / / __ _| |__ | |__  ___  __ | |  __ _ __ ___  _   _ _ __  
# | |  | | | | |/ _ \ '__| | | |   / / / _` | '_ \| '_ \| \ \/ / | | |_ | '__/ _ \| | | | '_ \ 
# | |__| | |_| |  __/ |  | |_| |  / /_| (_| | |_) | |_) | |>  <  | |__| | | | (_) | |_| | |_) |
#  \___\_\\__,_|\___|_|   \__, | /_____\__,_|_.__/|_.__/|_/_/\_\  \_____|_|  \___/ \__,_| .__/ 
#                          __/ |                                                        | |    
#                         |___/                                                         |_|    
# Get UserGrpIds and Members of existing LDAP-User Group in Zabbix
Print_Status_Text "STEP 2: Get Members of Zabbix-LDAP Groups"
Print_Status_Done "checking" $LIGHTCYAN
if [ "$b_verbose" = "true" ]; then
    echo
    echo "STEP 2: Get Members of Zabbix-LDAP Group"
    echo "--------------------------------------------------------------"
    echo "Zabbix LDAP Group Name .........: $ZABBIX_Groupname_for_Sync"
    echo "Zabbix Disabled User Group Name : $ZABBIX_Disabled_User_Group"
    echo "Zabbix API URL .................: $ZABBIX_API_User"
    echo "Zabbix API User ................: $LDAP_Bind_User_DN"
    echo "--------------------------------------------------------------"
fi
#############################################################################################################
# Get UsrGrpIds
Print_Status_Text 'determine UsrGrpID of "'$ZABBIX_Groupname_for_Sync'"'
if [ "$b_verbose" = "true" ]; then Print_Status_Done "checking" $LIGHTCYAN; fi
declare -a ZABBIX_ARRAY_usrgrpid_RAW
if [ "$b_verbose" = "true" ]; then
    printf 'curl -k -s -X POST -H "Content-Type:application/json"  -d '
    printf "'"
    printf '{"jsonrpc":"2.0","method":"usergroup.get","params":{"filter":{"name":"'$ZABBIX_Groupname_for_Sync'"},"output":"extend","status":0},"id":42,"auth":"'$ZABBIX_authentication_token'"}'
    printf "'"
    printf " $ZABBIX_API_URL"
fi
tempvar=`curl -k -s -X POST -H "Content-Type:application/json"  -d '{"jsonrpc":"2.0","method":"usergroup.get","params":{"filter":{"name":"'$ZABBIX_Groupname_for_Sync'"},"output":"extend","status":0},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
if [ "$b_verbose" = "true" ]; then echo $tempvar; fi
# The answer is an JSON - we split by the " into an array and search for the wanted values
IFS='"' # " is set as delimiter
ZABBIX_ARRAY_usrgrpid_RAW=($tempvar)
IFS=' ' # space is set as delimiter
for (( i=0; i < ${#ZABBIX_ARRAY_usrgrpid_RAW[*]}; i++ )); do
    #echo "Wert $i: ${ZABBIX_ARRAY_usrgrpid_RAW[$i]}"
    if [ "${ZABBIX_ARRAY_usrgrpid_RAW[$i]}" = "usrgrpid" ]; then
        i=$(($i + 2))
        ZABBIX_LDAP_Group_UsrGrpId="${ZABBIX_ARRAY_usrgrpid_RAW[$i]}"
        # i=${#ZABBIX_ARRAY_usrgrpid_RAW[*]}
        break
    fi
done
Print_Verbose_Text "$ZABBIX_Groupname_for_Sync" "$ZABBIX_LDAP_Group_UsrGrpId"
if [ "$b_verbose" = "true" ]; then Print_Status_Text 'determine UsrGrpID of "'$ZABBIX_Groupname_for_Sync'"'; fi
Print_Status_Done "done" $GREEN
tempvar=""
Print_Status_Text 'determine UsrGrpID of "'$ZABBIX_Disabled_User_Group'"'
if [ "$b_verbose" = "true" ]; then Print_Status_Done "checking" $LIGHTCYAN; fi
tempvar=`curl -k -s -X POST -H "Content-Type:application/json"  -d '{"jsonrpc":"2.0","method":"usergroup.get","params":{"filter":{"name":"'$ZABBIX_Disabled_User_Group'"},"output":"extend","status":1},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
if [ "$b_verbose" = "true" ]; then echo $tempvar; fi
IFS='"' # " is set as delimiter
ZABBIX_ARRAY_usrgrpid_RAW=($tempvar)
IFS=' ' # space is set as delimiter
for (( i=0; i < ${#ZABBIX_ARRAY_usrgrpid_RAW[*]}; i++ )); do
    if [ "${ZABBIX_ARRAY_usrgrpid_RAW[$i]}" = "usrgrpid" ]; then
        i=$(($i + 2))
        ZABBIX_Disabled_Group_UsrGrpId="${ZABBIX_ARRAY_usrgrpid_RAW[$i]}"
        break
    fi
done
Print_Verbose_Text "$ZABBIX_Disabled_User_Group" "$ZABBIX_Disabled_Group_UsrGrpId"
if [ "$b_verbose" = "true" ]; then Print_Status_Text 'determine UsrGrpID of "'$ZABBIX_Disabled_User_Group'"'; fi
Print_Status_Done "done" $GREEN
tempvar=""
unset ZABBIX_ARRAY_usrgrpid_RAW
#############################################################################################################
# Get alias and userid of the Zabbix Group Members
Print_Status_Text 'determine alias and userid for Members of "'$ZABBIX_Groupname_for_Sync'"'
if [ "$b_verbose" = "true" ]; then Print_Status_Done "checking" $LIGHTCYAN; fi

declare -a ZABBIX_ARRAY_LDAP_GroupMember_alias
declare -a ZABBIX_ARRAY_LDAP_GroupMember_userid
declare -a ZABBIX_ARRAY_LDAP_GroupMember_RAW
ZABBIX_ARRAY_LDAP_GroupMember_alias=()
ZABBIX_ARRAY_LDAP_GroupMember_userid=()
if [ "$b_verbose" = "true" ]; then
    printf 'curl -k -s -X POST -H "Content-Type:application/json"  -d '
    printf "'"
    printf '{"jsonrpc": "2.0","method":"user.get","params":{"usrgrpids":"'$ZABBIX_LDAP_Group_UsrGrpId'","output":["alias","userid"]},"id":42,"auth":"'$ZABBIX_authentication_token'"}'
    printf "'"
    printf " $ZABBIX_API_URL"
fi
tempvar=`curl -k -s -X POST -H "Content-Type:application/json"  -d '{"jsonrpc": "2.0","method":"user.get","params":{"usrgrpids":"'$ZABBIX_LDAP_Group_UsrGrpId'","output":["alias","userid"]},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
if [ "$b_verbose" = "true" ]; then echo $tempvar; fi
IFS='"' # " is set as delimiter
ZABBIX_ARRAY_LDAP_GroupMember_RAW=($tempvar)
IFS=' ' # space is set as delimiter
for (( i=0; i < ${#ZABBIX_ARRAY_LDAP_GroupMember_RAW[*]}; i++ )); do
    #echo "Wert $i: ${ZABBIX_ARRAY_LDAP_GroupMember_RAW[$i]}"
    # Wir gehen davon aus das UserId und Alias immer - in beliebiger Reihenfolge - hintereinander kommen, der Index der beiden Arrays sollte also zueinander passen
    if [ "${ZABBIX_ARRAY_LDAP_GroupMember_RAW[$i]}" = "userid" ]; then
        i=$(($i + 2))
        ZABBIX_ARRAY_LDAP_GroupMember_userid+=("${ZABBIX_ARRAY_LDAP_GroupMember_RAW[$i]}")
        Print_Verbose_Text "Found UserId" "${ZABBIX_ARRAY_LDAP_GroupMember_RAW[$i]}"
        #printf "."
    fi
    if [ "${ZABBIX_ARRAY_LDAP_GroupMember_RAW[$i]}" = "alias" ] || [ "${ZABBIX_ARRAY_LDAP_GroupMember_RAW[$i]}" = "username" ]; then
        i=$(($i + 2))
        ZABBIX_ARRAY_LDAP_GroupMember_alias+=("${ZABBIX_ARRAY_LDAP_GroupMember_RAW[$i]}")
        Print_Verbose_Text "Found Alias" "${ZABBIX_ARRAY_LDAP_GroupMember_RAW[$i]}"
        #printf "."
    fi
done
if [ "$b_verbose" = "true" ]; then Print_Status_Text 'determine alias and userid for Members of "'$ZABBIX_Groupname_for_Sync'"'; fi
Print_Status_Done "done" $GREEN
unset ZABBIX_ARRAY_LDAP_GroupMember_RAW
if [ "$b_verbose" = "true" ]; then
    echo "------------------------------------------------------------------------------------------------"
    echo "Result from STEP 2: Get Members of Zabbix-LDAP Group $ZABBIX_Groupname_for_Sync"
    echo "----+----------------------+----------------------+----------------------+----------------------"
    printf "%-3s | %-20s | %-20s | %-20s | %-20s" "No." "Alias" "UserId" " " " "
    printf "\n"
    echo "----+----------------------+----------------------+----------------------+----------------------"
    for (( i=0; i < ${#ZABBIX_ARRAY_LDAP_GroupMember_alias[*]}; i++ )); do
        printf "%-3s | %-20s | %-20s | %-20s | %-20s" "$i" "${ZABBIX_ARRAY_LDAP_GroupMember_alias[$i]}" "${ZABBIX_ARRAY_LDAP_GroupMember_userid[$i]}" " " " "
        printf "\n"
    done
    echo "------------------------------------------------------------------------------------------------"
    echo
fi
#############################################################################################################
#   _____                                        _____                           
#  / ____|                                      / ____|                          
# | |     ___  _ __ ___  _ __   __ _ _ __ ___  | |  __ _ __ ___  _   _ _ __  ___ 
# | |    / _ \| '_ ` _ \| '_ \ / _` | '__/ _ \ | | |_ | '__/ _ \| | | | '_ \/ __|
# | |___| (_) | | | | | | |_) | (_| | | |  __/ | |__| | | | (_) | |_| | |_) \__ \
#  \_____\___/|_| |_| |_| .__/ \__,_|_|  \___|  \_____|_|  \___/ \__,_| .__/|___/
#                       | |                                           | |        
#                       |_|                                           |_|        
Print_Status_Text "STEP 3: Compare Groups for changes"
Print_Status_Done "checking" $LIGHTCYAN
if [ "$b_verbose" = "true" ]; then
    echo
    echo "STEP 3: Compare Groups for changes"
    echo "--------------------------------------------------------------"
    echo "AD / LDAP Group Name ...........: $LDAP_Groupname_for_Sync"
    echo "Zabbix LDAP Group Name .........: $ZABBIX_Groupname_for_Sync"
    echo "--------------------------------------------------------------"
fi
b_Must_Sync_Users="false"
# Check 1:
Print_Status_Text "Check 1: Number of Users LDAP"
Print_Status_Done "${#LDAP_ARRAY_Members_sAMAccountName[*]}" $DEFAULT_FOREGROUND
Print_Status_Text "Check 1: Number of Users Zabbix"
Print_Status_Done "${#ZABBIX_ARRAY_LDAP_GroupMember_alias[*]}" $DEFAULT_FOREGROUND
Print_Status_Text "Check 1: Number of Users"
if [ "${#LDAP_ARRAY_Members_sAMAccountName[*]}" -eq "${#ZABBIX_ARRAY_LDAP_GroupMember_alias[*]}" ]; then
    Print_Status_Done "equal" $GREEN
else
    Print_Status_Done "not equal" $RED
    b_Must_Sync_Users="true"
fi

# Check 2:
if [ "$b_Must_Sync_Users" = "false" ]; then
    # make Compare case insensitive, save original settings
    orig_nocasematch=$(shopt -p nocasematch)
    shopt -s nocasematch
    Print_Status_Text "Check 2: Compare Active Directory sAMAccountName with Zabbix Alias"
    if [ "$b_verbose" = "true" ]; then Print_Status_Done "checking" $LIGHTCYAN; fi
    # Check every sAMAccountName and find a alias for it
    for (( i=0; i < ${#LDAP_ARRAY_Members_sAMAccountName[*]}; i++ )); do
        b_alias_was_found="false"
        for (( k=0; k < ${#ZABBIX_ARRAY_LDAP_GroupMember_alias[*]}; k++ )); do
            if [[ "${LDAP_ARRAY_Members_sAMAccountName[$i]}" == "${ZABBIX_ARRAY_LDAP_GroupMember_alias[$k]}" ]]; then
                # printf "."
                Print_Verbose_Text "${LDAP_ARRAY_Members_sAMAccountName[$i]}" "found"
                b_alias_was_found="true"
                # if user have found the loop can be finished
                break
            fi
        done
        if [ "$b_alias_was_found" = "false" ]; then
            b_Must_Sync_Users="true"
            Print_Verbose_Text "${LDAP_ARRAY_Members_sAMAccountName[$i]}" "not found"
            if [ "$b_verbose" = "true" ]; then Print_Status_Text "Check 2: Compare Active Directory sAMAccountName with Zabbix Alias"; fi
            Print_Status_Done "mismatch" $RED
            # one user was not found, we can exit the test, we must sync
            break
        fi
    done
    # restore original case sensitive/insenstive settings
    $orig_nocasematch
    if [ "$b_verbose" = "true" ]; then Print_Status_Text "Check 2: Compare Active Directory sAMAccountName with Zabbix Alias"; fi
    if [ "$b_Must_Sync_Users" = "false" ]; then Print_Status_Done "done" $GREEN; fi
fi

#############################################################################################################
#   _____                  _                     _     _             
#  / ____|                | |                   (_)   (_)            
# | (___  _   _ _ __   ___| |__  _ __ ___  _ __  _ _____ _ __   __ _ 
#  \___ \| | | | '_ \ / __| '_ \| '__/ _ \| '_ \| |_  / | '_ \ / _` |
#  ____) | |_| | | | | (__| | | | | | (_) | | | | |/ /| | | | | (_| |
# |_____/ \__, |_| |_|\___|_| |_|_|  \___/|_| |_|_/___|_|_| |_|\__, |
#          __/ |                                                __/ |
#         |___/                                                |___/ 
if [ "$b_Must_Sync_Users" = "true" ]; then
    Print_Status_Text "STEP 4: Get all Zabbix Users with alias and userid"
    if [ "$b_verbose" = "true" ]; then Print_Status_Done "checking" $LIGHTCYAN; fi
    if [ "$b_verbose" = "true" ]; then
        echo
        echo "--------------------------------------------------------------"
        echo "STEP 4: Get all Zabbix Users with alias and userid"
    fi
    # get a List of all Zabbix Users to get the possible UserIds of new Users
    tempvar=""
    declare -a ZABBIX_ARRAY_AllUser_alias
    declare -a ZABBIX_ARRAY_AllUser_userid
    declare -a ZABBIX_ARRAY_AllUser_RAW
    ZABBIX_ARRAY_AllUser_alias=()
    ZABBIX_ARRAY_AllUser_userid=()
    if [ "$b_verbose" = "true" ]; then
        printf 'curl -k -s -X POST -H "Content-Type:application/json"  -d '
        printf "'"
        printf '{"jsonrpc": "2.0","method":"user.get","params":{"output":["alias","userid"]},"id":42,"auth":"'$ZABBIX_authentication_token'"}'
        printf "'"
        echo $ZABBIX_API_URL
    fi
    tempvar=`curl -k -s -X POST -H "Content-Type:application/json"  -d '{"jsonrpc": "2.0","method":"user.get","params":{"output":["alias","userid"]},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
    if [ "$b_verbose" = "true" ]; then
        echo $tempvar
    fi
    IFS='"' # " is set as delimiter
    ZABBIX_ARRAY_AllUser_RAW=($tempvar)
    IFS=' ' # space is set as delimiter
    for (( i=0; i < ${#ZABBIX_ARRAY_AllUser_RAW[*]}; i++ )); do
        # We assume that the UserId and Alias always come one after the other in any order, so the index of the two arrays should match
        if [ "${ZABBIX_ARRAY_AllUser_RAW[$i]}" = "userid" ]; then
            i=$(($i + 2))
            ZABBIX_ARRAY_AllUser_userid+=("${ZABBIX_ARRAY_AllUser_RAW[$i]}")
        fi
        if [ "${ZABBIX_ARRAY_AllUser_RAW[$i]}" = "alias" ] || [ "${ZABBIX_ARRAY_AllUser_RAW[$i]}" = "username" ]; then
            i=$(($i + 2))
            ZABBIX_ARRAY_AllUser_alias+=("${ZABBIX_ARRAY_AllUser_RAW[$i]}")
        fi
    done
    unset ZABBIX_ARRAY_AllUser_RAW
    if [ "$b_verbose" = "true" ]; then Print_Status_Text "STEP 4: Get all Zabbix Users with alias and userid"; fi
    Print_Status_Done "done" $GREEN
    if [ "$b_verbose" = "true" ]; then
        echo "------------------------------------------------------------------------------------------------"
        echo "Result from STEP 4: Get all Zabbix Users with alias and userid"
        echo "----+----------------------+----------------------+----------------------+----------------------"
        printf "%-3s | %-20s | %-20s | %-20s | %-20s" "No." "Alias" "UserId" " " " "
        printf "\n"
        echo "----+----------------------+----------------------+----------------------+----------------------"
        for (( i=0; i < ${#ZABBIX_ARRAY_AllUser_alias[*]}; i++ )); do
            printf "%-3s | %-20s | %-20s | %-20s | %-20s" "$i" "${ZABBIX_ARRAY_AllUser_alias[$i]}" "${ZABBIX_ARRAY_AllUser_userid[$i]}" " " " "
            printf "\n"
        done
        echo "------------------------------------------------------------------------------------------------"
    fi
    Print_Status_Text "STEP 5: Compare LDAP user with existing Zabbix User"
    if [ "$b_verbose" = "true" ]; then Print_Status_Done "checking" $LIGHTCYAN; fi
    if [ "$b_verbose" = "true" ]; then
        echo
        echo "--------------------------------------------------------------"
        echo "STEP 5: Compare LDAP user with existing Zabbix User"
    fi
    # additional Array for Zabbix-UserId
    declare -a LDAP_ARRAY_Members_UserId
    LDAP_ARRAY_Members_UserId=()
    # Merker ob wir neue Benutzer anlegen müssen
    b_have_to_create_new_user="false"
    # Compare LDAP-User with Zabbix-User
    # make Compare case insensitive, save original settings
    orig_nocasematch=$(shopt -p nocasematch)
    shopt -s nocasematch
    i_CounterNewUsers=0
    for (( i=0; i < ${#LDAP_ARRAY_Members_sAMAccountName[*]}; i++ )); do
        b_we_have_a_winner="false"
        for (( k=0; k < ${#ZABBIX_ARRAY_AllUser_alias[*]}; k++ )); do
            if [[ "${LDAP_ARRAY_Members_sAMAccountName[$i]}" == "${ZABBIX_ARRAY_AllUser_alias[$k]}" ]]; then
                LDAP_ARRAY_Members_UserId+=("${ZABBIX_ARRAY_AllUser_userid[$k]}")
                Print_Verbose_Text "Found existing User: ${LDAP_ARRAY_Members_sAMAccountName[$i]}" "${ZABBIX_ARRAY_AllUser_alias[$k]}"
                b_we_have_a_winner="true"
                break
            fi
        done
        # User was found?
        if [ "$b_we_have_a_winner" = "false" ]; then
            # User was not found - but we need an array item to have all array index identical and matched to each other
            # also mark this User to have to be created
            LDAP_ARRAY_Members_UserId+=("create-user")
            Print_Verbose_Text "No Zabbix user found: ${LDAP_ARRAY_Members_sAMAccountName[$i]}" "will be created"
            b_have_to_create_new_user="true"
            i_CounterNewUsers=$(($i_CounterNewUsers + 1))
        fi
    done
    # restore original case sensitive/insenstive settings
    $orig_nocasematch
    if [ "$b_verbose" = "true" ]; then Print_Status_Text "STEP 5: Compare LDAP user with existing Zabbix User"; fi
    if [ "$b_have_to_create_new_user" = "true" ]; then
        Print_Status_Done "must create $i_CounterNewUsers new user" $RED
    else
        Print_Status_Done "done" $GREEN
    fi
    if [ "$b_verbose" = "true" ]; then
        echo "----------------------------------------------------------------------------------------------------------------------"
        echo "Result from STEP 5: Compare LDAP user with existing Zabbix User"
        echo "----+----------------------+----------------------+----------------------+--------------------------+-----------------"
        printf "%-3s | %-20s | %-20s | %-20s | %-24s | %-20s" "No." "sAMAccountName" "Surname" "Givenname" "Zabbix-UserId" "Email-Address"
        printf "\n"
        echo "----+----------------------+----------------------+----------------------+--------------------------+-----------------"
        for (( i=0; i < ${#LDAP_ARRAY_Members_sAMAccountName[*]}; i++ )); do
            printf "%-3s | %-20s | %-20s | %-20s | %-24s | %-20s" "$i" "${LDAP_ARRAY_Members_sAMAccountName[$i]}" "${LDAP_ARRAY_Members_Surname[$i]}" "${LDAP_ARRAY_Members_Givenname[$i]}" "${LDAP_ARRAY_Members_UserId[$i]}" "${LDAP_ARRAY_Members_Email[$i]}"
        printf "\n"
        done
        echo "----------------------------------------------------------------------------------------------------------------------"
    fi
    #############################################################################################################
    if [ "$b_have_to_create_new_user" = "true" ]; then
        Print_Status_Text "STEP 6: Create needed $i_CounterNewUsers new Zabbix-User"
        if [ "$b_verbose" = "true" ]; then Print_Status_Done "checking" $LIGHTCYAN; fi
        if [ "$b_verbose" = "true" ]; then
            echo "--------------------------------------------------------------"
            echo "STEP 6: Create needed $i_CounterNewUsers new Zabbix-User"
        fi
        declare -a ZABBIX_ARRAY_New_User_RAW
        # Search for all User with UserId "create-user"
        for (( i=0; i < ${#LDAP_ARRAY_Members_sAMAccountName[*]}; i++ )); do
            if [ "${LDAP_ARRAY_Members_UserId[$i]}" = "create-user" ]; then
                # printf "Create new user ${LDAP_ARRAY_Members_sAMAccountName[$i]} ... "
                tempSAM='"'"${LDAP_ARRAY_Members_sAMAccountName[$i]}"'"'
                # Check the things we have
                create_combination=""
                if [ "${LDAP_ARRAY_Members_Surname[$i]}" != " - " ]; then
                    create_combination+="X"
                    tempSURNAME='"'"${LDAP_ARRAY_Members_Surname[$i]}"'"'
                    Print_Verbose_Text "tempSURNAME" "$tempSURNAME"
                else
                    create_combination+="O"
                fi
                if [ "${LDAP_ARRAY_Members_Givenname[$i]}" != " - " ]; then
                    create_combination+="X"
                    tempNAME='"'"${LDAP_ARRAY_Members_Givenname[$i]}"'"'
                    Print_Verbose_Text "tempNAME" "$tempNAME"
                else
                    create_combination+="O"
                fi
                if [ "${LDAP_ARRAY_Members_Email[$i]}" != " - " ]; then
                    create_combination+="X"
                    tempEmail='"'"${LDAP_ARRAY_Members_Email[$i]}"'"'
                    Print_Verbose_Text "tempEmail" "$tempEmail"
                else
                    create_combination+="O"
                fi
                Print_Verbose_Text "Create Combination" "$create_combination"
                # create_combination should be OOO, OOX, OXO, OXX, XOO, XOX, XXO or XXX
                tempvar=""
                case "$create_combination" in
                    "OOO")  # No Surname, Givenname or Email
                            if [ "$b_verbose" = "true" ]; then
                                printf 'curl -k -s -X POST -H "Content-Type:application/json" -d '
                                printf "'"
                                printf '{"jsonrpc":"2.0","method":"user.create","params":{"alias":'"$tempSAM"',"usrgrps":[{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'"}],"'$s_UserMode'":'$ZABBIX_UserType_User'},"id":42,"auth":"'$ZABBIX_authentication_token'"}'
                                printf "'"
                                echo $ZABBIX_API_URL
                            fi
                            tempvar=`curl -k -s -X POST -H "Content-Type:application/json" -d '{"jsonrpc":"2.0","method":"user.create","params":{"alias":'"$tempSAM"',"usrgrps":[{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'"}],"'$s_UserMode'":'$ZABBIX_UserType_User'},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
                            ;;
                    "OOX")  # Email, but no Surname or Givenname
                            if [ "$b_verbose" = "true" ]; then
                                printf 'curl -k -s -X POST -H "Content-Type:application/json" -d '
                                printf "'"
                                printf '{"jsonrpc":"2.0","method":"user.create","params":{"alias":'"$tempSAM"',"user_medias":[{"mediatypeid": "'$ZABBIX_MediaTypeID'","sendto":['"$tempEmail"']}],"usrgrps":[{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'"}],"'$s_UserMode'":'$ZABBIX_UserType_User'},"id":42,"auth":"'$ZABBIX_authentication_token'"}'
                                printf "'"
                                echo $ZABBIX_API_URL
                            fi
                            tempvar=`curl -k -s -X POST -H "Content-Type:application/json" -d '{"jsonrpc":"2.0","method":"user.create","params":{"alias":'"$tempSAM"',"user_medias":[{"mediatypeid": "'$ZABBIX_MediaTypeID'","sendto":['"$tempEmail"']}],"usrgrps":[{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'"}],"'$s_UserMode'":'$ZABBIX_UserType_User'},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
                            
                            ;;
                    "OXO")  # Givenname, but no Surname or Email
                            if [ "$b_verbose" = "true" ]; then
                                printf 'curl -k -s -X POST -H "Content-Type:application/json" -d '
                                printf "'"
                                printf '{"jsonrpc":"2.0","method":"user.create","params":{"alias":'"$tempSAM"',"name":'"$tempNAME"',"usrgrps":[{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'"}],"'$s_UserMode'":'$ZABBIX_UserType_User'},"id":42,"auth":"'$ZABBIX_authentication_token'"}'
                                printf "'"
                                echo $ZABBIX_API_URL
                            fi
                            tempvar=`curl -k -s -X POST -H "Content-Type:application/json" -d '{"jsonrpc":"2.0","method":"user.create","params":{"alias":'"$tempSAM"',"name":'"$tempNAME"',"usrgrps":[{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'"}],"'$s_UserMode'":'$ZABBIX_UserType_User'},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
                            ;;
                    "OXX")  # Givenname and Email, no Surname
                            if [ "$b_verbose" = "true" ]; then
                                printf 'curl -k -s -X POST -H "Content-Type:application/json" -d '
                                printf "'"
                                printf '{"jsonrpc":"2.0","method":"user.create","params":{"alias":'"$tempSAM"',"user_medias":[{"mediatypeid": "'$ZABBIX_MediaTypeID'","sendto":['"$tempEmail"']}],"name":'"$tempNAME"',"usrgrps":[{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'"}],"'$s_UserMode'":'$ZABBIX_UserType_User'},"id":42,"auth":"'$ZABBIX_authentication_token'"}'
                                printf "'"
                                echo $ZABBIX_API_URL
                            fi
                            tempvar=`curl -k -s -X POST -H "Content-Type:application/json" -d '{"jsonrpc":"2.0","method":"user.create","params":{"alias":'"$tempSAM"',"user_medias":[{"mediatypeid": "'$ZABBIX_MediaTypeID'","sendto":['"$tempEmail"']}],"name":'"$tempNAME"',"usrgrps":[{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'"}],"'$s_UserMode'":'$ZABBIX_UserType_User'},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
                            ;;
                    "XOO")  # Surname, but no Givenname or Email
                            if [ "$b_verbose" = "true" ]; then
                                printf 'curl -k -s -X POST -H "Content-Type:application/json" -d '
                                printf "'"
                                printf '{"jsonrpc":"2.0","method":"user.create","params":{"alias":'"$tempSAM"',"surname":'"$tempSURNAME"',"usrgrps":[{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'"}],"'$s_UserMode'":'$ZABBIX_UserType_User'},"id":42,"auth":"'$ZABBIX_authentication_token'"}'
                                printf "'"
                                echo $ZABBIX_API_URL
                            fi
                            tempvar=`curl -k -s -X POST -H "Content-Type:application/json" -d '{"jsonrpc":"2.0","method":"user.create","params":{"alias":'"$tempSAM"',"surname":'"$tempSURNAME"',"usrgrps":[{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'"}],"'$s_UserMode'":'$ZABBIX_UserType_User'},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
                            ;;
                    "XOX")  # Surname and Email, but no Givenname
                            if [ "$b_verbose" = "true" ]; then
                                printf 'curl -k -s -X POST -H "Content-Type:application/json" -d '
                                printf "'"
                                printf '{"jsonrpc": "2.0","method":"user.create","params":{"alias":'"$tempSAM"',"surname":'"$tempSURNAME"',"user_medias":[{"mediatypeid": "'$ZABBIX_MediaTypeID'","sendto":['"$tempEmail"']}],"usrgrps":[{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'"}],"'$s_UserMode'":'$ZABBIX_UserType_User'},"id":42,"auth":"'$ZABBIX_authentication_token'"}'
                                printf "'"
                                echo $ZABBIX_API_URL
                            fi
                            tempvar=`curl -k -s -X POST -H "Content-Type:application/json" -d '{"jsonrpc": "2.0","method":"user.create","params":{"alias":'"$tempSAM"',"surname":'"$tempSURNAME"',"user_medias":[{"mediatypeid": "'$ZABBIX_MediaTypeID'","sendto":['"$tempEmail"']}],"usrgrps":[{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'"}],"'$s_UserMode'":'$ZABBIX_UserType_User'},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
                            ;;
                    "XXO")  # Surname and Givenname, but no Email
                            if [ "$b_verbose" = "true" ]; then
                                printf 'curl -k -s -X POST -H "Content-Type:application/json" -d '
                                printf "'"
                                printf '{"jsonrpc":"2.0","method":"user.create","params":{"alias":'"$tempSAM"',"name":'"$tempNAME"',"surname":'"$tempSURNAME"',"usrgrps":[{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'"}],"'$s_UserMode'":'$ZABBIX_UserType_User'},"id":42,"auth":"'$ZABBIX_authentication_token'"}'
                                printf "'"
                                echo $ZABBIX_API_URL
                            fi
                            tempvar=`curl -k -s -X POST -H "Content-Type:application/json" -d '{"jsonrpc":"2.0","method":"user.create","params":{"alias":'"$tempSAM"',"name":'"$tempNAME"',"surname":'"$tempSURNAME"',"usrgrps":[{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'"}],"'$s_UserMode'":'$ZABBIX_UserType_User'},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
                            ;;
                    "XXX")  # Surname, Givenname and Email
                            if [ "$b_verbose" = "true" ]; then
                                printf 'curl -k -s -X POST -H "Content-Type:application/json" -d '
                                printf "'"
                                printf '{"jsonrpc": "2.0","method":"user.create","params":{"alias":'"$tempSAM"',"name":'"$tempNAME"',"surname":'"$tempSURNAME"',"user_medias":[{"mediatypeid": "'$ZABBIX_MediaTypeID'","sendto":['"$tempEmail"']}],"usrgrps":[{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'"}],"'$s_UserMode'":'$ZABBIX_UserType_User'},"id":42,"auth":"'$ZABBIX_authentication_token'"}'
                                printf "'"
                                echo $ZABBIX_API_URL
                            fi
                            tempvar=`curl -k -s -X POST -H "Content-Type:application/json" -d '{"jsonrpc": "2.0","method":"user.create","params":{"alias":'"$tempSAM"',"name":'"$tempNAME"',"surname":'"$tempSURNAME"',"user_medias":[{"mediatypeid": "'$ZABBIX_MediaTypeID'","sendto":['"$tempEmail"']}],"usrgrps":[{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'"}],"'$s_UserMode'":'$ZABBIX_UserType_User'},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
                            ;;
                esac
                if [ "$b_verbose" = "true" ]; then echo "$tempvar"; fi
                # Catch the new UserId from the answer
                IFS='"' # " is set as delimiter
                ZABBIX_ARRAY_New_User_RAW=($tempvar)
                IFS=' ' # space is set as delimiter
                for (( k=0; k < ${#ZABBIX_ARRAY_New_User_RAW[*]}; k++ )); do
                    if [ "${ZABBIX_ARRAY_New_User_RAW[$k]}" = "userids" ]; then
                        k=$(($k + 2))
                        LDAP_ARRAY_Members_UserId[$i]="${ZABBIX_ARRAY_New_User_RAW[$k]}"
                    fi
                done
                Print_Verbose_Text "Created: ${LDAP_ARRAY_Members_sAMAccountName[$i]}" "LDAP_ARRAY_Members_UserId[$i]"
            fi
        done
        if [ "$b_verbose" = "true" ]; then Print_Status_Text "STEP 6: Create needed $i_CounterNewUsers new Zabbix-User"; fi
        Print_Status_Done "done" $GREEN
        if [ "$b_verbose" = "true" ]; then
            echo "-------------------------------------------------------------------------------------------------------------"
            echo "Result from STEP 6: Create needed new Zabbix-User"
            echo "----+----------------------+----------------------+----------------------+--------------------------+-----------------"
            printf "%-3s | %-20s | %-20s | %-20s | %-24s | %-20s" "No." "sAMAccountName" "Surname" "Givenname" "Zabbix-UserId" "Email-Address"
            printf "\n"
            echo "----+----------------------+----------------------+----------------------+--------------------------+-----------------"
            for (( i=0; i < ${#LDAP_ARRAY_Members_sAMAccountName[*]}; i++ )); do
                printf "%-3s | %-20s | %-20s | %-20s | %-24s | %-20s" "$i" "${LDAP_ARRAY_Members_sAMAccountName[$i]}" "${LDAP_ARRAY_Members_Surname[$i]}" "${LDAP_ARRAY_Members_Givenname[$i]}" "${LDAP_ARRAY_Members_UserId[$i]}" "${LDAP_ARRAY_Members_Email[$i]}"
                printf "\n"
            done
            echo "----------------------------------------------------------------------------------------------------------------------"
        fi
    else
        Print_Status_Text "STEP 6: Create needed $i_CounterNewUsers new Zabbix-User"
        Print_Status_Done "skipped" $GREEN
    fi
    
    #############################################################################################################
    Print_Status_Text "STEP 7: Replace Members of Group $ZABBIX_Groupname_for_Sync"
    if [ "$b_verbose" = "true" ]; then Print_Status_Done "checking" $LIGHTCYAN; fi
    if [ "$b_verbose" = "true" ]; then
        echo "--------------------------------------------------------------"
        echo "STEP 7: Replace Members of Group $ZABBIX_Groupname_for_Sync"
    fi
    tempvar=""
    list_of_userids=""
    for (( i=0; i < ${#LDAP_ARRAY_Members_sAMAccountName[*]}; i++ )); do
        list_of_userids+='"'${LDAP_ARRAY_Members_UserId[$i]}'"'
        list_of_userids+=","
    done
    # maybe the list is empty! So we have to check
    if [ "$list_of_userids" != "" ]; then list_of_userids=${list_of_userids::-1}; fi
    if [ "$b_verbose" = "true" ]; then printf "Update Zabbix Group $ZABBIX_Groupname_for_Sync via API (Replace)"; fi
    if [ "$b_verbose" = "true" ]; then
        printf 'curl -k -s -X POST -H "Content-Type:application/json"  -d '
        printf "'"
        printf '{"jsonrpc": "2.0","method":"usergroup.update","params":{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'","userids":['$list_of_userids']},"id":42,"auth":"'$ZABBIX_authentication_token'"}'
        printf "' "
        echo $ZABBIX_API_URL
    fi
    tempvar=`curl -k -s -X POST -H "Content-Type:application/json"  -d '{"jsonrpc": "2.0","method":"usergroup.update","params":{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'","userids":['$list_of_userids']},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
    if [ "$b_verbose" = "true" ]; then echo $tempvar; fi
    if [ "$b_verbose" = "true" ]; then Print_Status_Text "STEP 7: Replace Members of Group $ZABBIX_Groupname_for_Sync"; fi
    Print_Status_Done "done" $GREEN
    
    #############################################################################################################
    # 1. get a List of all User in the "Disabled User" group
    # 2. Remove all active user from this List
    # 3. Add all user wich was removed from LDAP-Group but was in the Zabbix-LDAP-Group found
    # 4. Update Members of Group "Disabled User" via Zabbix API
    Print_Status_Text "STEP 8: Get List of all disabled user in Group $ZABBIX_Disabled_User_Group"
    if [ "$b_verbose" = "true" ]; then Print_Status_Done "checking" $LIGHTCYAN; fi
    if [ "$b_verbose" = "true" ]; then
        echo "--------------------------------------------------------------"
        echo "STEP 8: Get List of all disabled user in Group $ZABBIX_Disabled_User_Group"
    fi
    # 1. get a List of all User in the "Disabled User" group
    declare -a ZABBIX_ARRAY_disabled_User_userid
    declare -a ZABBIX_ARRAY_disabled_User_RAW
    ZABBIX_ARRAY_disabled_User_userid=()
    if [ "$b_verbose" = "true" ]; then
        printf 'curl -k -s -X POST -H "Content-Type:application/json"  -d '
        printf "'"
        printf '{"jsonrpc": "2.0","method":"user.get","params":{"usrgrpids":"'$ZABBIX_Disabled_Group_UsrGrpId'","output":["userid"],"status":1},"id":42,"auth":"'$ZABBIX_authentication_token'"}'
        printf "'"
        echo $ZABBIX_API_URL
    fi
    tempvar=`curl -k -s -X POST -H "Content-Type:application/json"  -d '{"jsonrpc": "2.0","method":"user.get","params":{"usrgrpids":"'$ZABBIX_Disabled_Group_UsrGrpId'","output":["userid"],"status":1},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
    if [ "$b_verbose" = "true" ]; then echo $tempvar; fi
    IFS='"' # " is set as delimiter
    ZABBIX_ARRAY_disabled_User_RAW=($tempvar)
    IFS=' ' # space is set as delimiter
    for (( i=0; i < ${#ZABBIX_ARRAY_disabled_User_RAW[*]}; i++ )); do
        if [ "${ZABBIX_ARRAY_disabled_User_RAW[$i]}" = "userid" ]; then
            i=$(($i + 2))
            ZABBIX_ARRAY_disabled_User_userid+=("${ZABBIX_ARRAY_disabled_User_RAW[$i]}")
        fi
    done
    unset ZABBIX_ARRAY_disabled_User_RAW
    if [ "$b_verbose" = "true" ]; then Print_Status_Text "STEP 8: Get List of all disabled user in Group $ZABBIX_Disabled_User_Group"; fi
    Print_Status_Done "done" $GREEN
    Print_Status_Text "STEP 9: Remove active user, add inactive user"
    if [ "$b_verbose" = "true" ]; then Print_Status_Done "checking" $LIGHTCYAN; fi
    if [ "$b_verbose" = "true" ]; then
        echo "--------------------------------------------------------------"
        echo "STEP 9: Remove active user, add inactive user"
    fi
    # 2. Remove all active user from this List
    # 3. Add all user wich was removed from LDAP-Group but was in the Zabbix-LDAP-Group found
    declare -a new_ZABBIX_ARRAY_disabled_User_userid
    new_ZABBIX_ARRAY_disabled_User_userid=()
    if [ "$b_verbose" = "true" ]; then Print_Status_Text "Removing active Users from List"; fi
    for (( i=0; i < ${#ZABBIX_ARRAY_disabled_User_userid[*]}; i++ )); do
        b_skip_this_user="false"
        for (( k=0; k < ${#LDAP_ARRAY_Members_UserId[*]}; k++ )); do
            if [ "${ZABBIX_ARRAY_disabled_User_userid[$i]}" = "${LDAP_ARRAY_Members_UserId[$k]}" ]; then
                b_skip_this_user="true"
            fi
        done
        if [ "$b_skip_this_user" = "false" ]; then
            new_ZABBIX_ARRAY_disabled_User_userid+=("${ZABBIX_ARRAY_disabled_User_userid[$i]}")
        fi
    done
    if [ "$b_verbose" = "true" ]; then Print_Status_Done "done" $GREEN; fi
    if [ "$b_verbose" = "true" ]; then Print_Status_Text "Adding inactive Users"; fi
    for (( i=0; i < ${#ZABBIX_ARRAY_LDAP_GroupMember_userid[*]}; i++ )); do
        b_skip_this_user="false"
        for (( k=0; k < ${#LDAP_ARRAY_Members_UserId[*]}; k++ )); do
            if [ "${ZABBIX_ARRAY_LDAP_GroupMember_userid[$i]}" = "${LDAP_ARRAY_Members_UserId[$k]}" ]; then
                b_skip_this_user="true"
            fi
        done
        if [ "$b_skip_this_user" = "false" ]; then
            new_ZABBIX_ARRAY_disabled_User_userid+=("${ZABBIX_ARRAY_LDAP_GroupMember_userid[$i]}")
        fi
    done
    if [ "$b_verbose" = "true" ]; then Print_Status_Done "done" $GREEN; fi
    if [ "$b_verbose" = "true" ]; then Print_Status_Text "STEP 9: Remove active user, add inactive user"; fi
    Print_Status_Done "done" $GREEN
    Print_Status_Text "STEP 10: Replace Members of Group $ZABBIX_Disabled_User_Group"
    if [ "$b_verbose" = "true" ]; then Print_Status_Done "checking" $LIGHTCYAN; fi
    if [ "$b_verbose" = "true" ]; then
        echo "--------------------------------------------------------------"
        echo "STEP 10: Replace Members of Group $ZABBIX_Disabled_User_Group"
    fi
    tempvar=""
    # maybe the list is empty! So we have to check
    # if [ "$list_of_userids" != "" ]; then list_of_userids=${list_of_userids::-1}; fi
    list_of_userids=""
    for (( i=0; i < ${#new_ZABBIX_ARRAY_disabled_User_userid[*]}; i++ )); do
        list_of_userids+='"'${new_ZABBIX_ARRAY_disabled_User_userid[$i]}'"'
        list_of_userids+=","
    done
    list_of_userids=${list_of_userids::-1}
    if [ "$b_verbose" = "true" ]; then
        printf 'curl -k -s -X POST -H "Content-Type:application/json"  -d '
        printf "'"
        printf '{"jsonrpc": "2.0","method":"usergroup.update","params":{"usrgrpid":"'$ZABBIX_Disabled_Group_UsrGrpId'","userids":['$list_of_userids']},"id":42,"auth":"'$ZABBIX_authentication_token'"}'
        printf "' "
        echo $ZABBIX_API_URL
    fi
    tempvar=`curl -k -s -X POST -H "Content-Type:application/json"  -d '{"jsonrpc": "2.0","method":"usergroup.update","params":{"usrgrpid":"'$ZABBIX_Disabled_Group_UsrGrpId'","userids":['$list_of_userids']},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
    if [ "$b_verbose" = "true" ]; then echo $tempvar; fi
    if [ "$b_verbose" = "true" ]; then Print_Status_Text "STEP 10: Replace Members of Group $ZABBIX_Disabled_User_Group"; fi
    Print_Status_Done "done" $GREEN
    #############################################################################################################
    Print_Status_Text "STEP 11: Replace Members of Group $ZABBIX_Groupname_for_Sync (2. Time)"
    if [ "$b_verbose" = "true" ]; then Print_Status_Done "checking" $LIGHTCYAN; fi
    if [ "$b_verbose" = "true" ]; then
        echo "--------------------------------------------------------------"
        echo "STEP 11: Replace Members of Group $ZABBIX_Groupname_for_Sync (2. Time)"
    fi
    # we have to do this twice if we move user between enabled and disabled and they are only in the Zabbix-LDAP-Group - they must be in one Group!"
    # If a user is a now a member of the deactivated user group we can now remove the user from the Zabbix-LDAP-Group
    tempvar=""
    list_of_userids=""
    for (( i=0; i < ${#LDAP_ARRAY_Members_sAMAccountName[*]}; i++ )); do
        list_of_userids+='"'${LDAP_ARRAY_Members_UserId[$i]}'"'
        list_of_userids+=","
    done
    # maybe the list is empty! So we have to check
    if [ "$list_of_userids" != "" ]; then list_of_userids=${list_of_userids::-1}; fi
    tempvar=`curl -k -s -X POST -H "Content-Type:application/json"  -d '{"jsonrpc": "2.0","method":"usergroup.update","params":{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'","userids":['$list_of_userids']},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
    if [ "$b_verbose" = "true" ]; then Print_Status_Text "STEP 11: Replace Members of Group $ZABBIX_Groupname_for_Sync (2. Time)"; fi
    Print_Status_Done "done" $GREEN
else
    Print_Status_Text "STEP 3: Compare Groups for changes"
    Print_Status_Done "no changes" $GREEN
fi
#############################################################################################################
#  ______     _     _     _        _                             _   
# |___  /    | |   | |   (_)      | |                           | |  
#    / / __ _| |__ | |__  ___  __ | |     ___   __ _  ___  _   _| |_ 
#   / / / _` | '_ \| '_ \| \ \/ / | |    / _ \ / _` |/ _ \| | | | __|
#  / /_| (_| | |_) | |_) | |>  <  | |___| (_) | (_| | (_) | |_| | |_ 
# /_____\__,_|_.__/|_.__/|_/_/\_\ |______\___/ \__, |\___/ \__,_|\__|
#                                               __/ |                
#                                              |___/                 
# Logout before exit
if [ "$b_Zabbix_is_logged_in" = "true" ]; then
    Zabbix_Logout
fi
#############################################################################################################
exit 0
