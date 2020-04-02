#!/bin/bash
#############################################################################################################
# Script Name ...: zabbix-ldap-sync.sh
# Version .......: V1.0
# Date ..........: 30.03.2020
# Description....: Synchronise Members of a Actice Directory Group with Zabbix via API
#                  User wich are removed will be deactivated
# Args ..........: 
# Author ........: Bernhard Linz
# Email Business : Bernhard.Linz@datagroup.de
# Email Private  : Bernhard@znil.de
#############################################################################################################
#   _____             __ _                       _   _             
#  / ____|           / _(_)                     | | (_)            
# | |     ___  _ __ | |_ _  __ _ _   _ _ __ __ _| |_ _  ___  _ __  
# | |    / _ \| '_ \|  _| |/ _` | | | | '__/ _` | __| |/ _ \| '_ \ 
# | |___| (_) | | | | | | | (_| | |_| | | | (_| | |_| | (_) | | | |
#  \_____\___/|_| |_|_| |_|\__, |\__,_|_|  \__,_|\__|_|\___/|_| |_|
#                           __/ |                                  
#                          |___/                                   
# Configuration LDAP-Connection (Tested LDAPS with Windows Server 2019)
LDAP_Source_URL="ldaps://10.100.12.51"
LDAP_Bind_User_DN="CN=ldapSearch,OU=3.Funktionsbenutzer,DC=znil,DC=local"
LDAP_Bind_User_Password="bier2017"
LDAP_SearchBase="DC=znil,DC=local"
LDAP_Groupname_ZabbixSuperAdmin_for_Sync="Zabbix-Admins"
LDAP_Ignore_SSL_Certificate="true"

# Configuration Zabbix API Connection (Tested Zabbix 4.4)
#ZABBIX_API_URL="http://localhost/zabbix/api_jsonrpc.php"
ZABBIX_API_URL="http://localhost/api_jsonrpc.php"
ZABBIX_API_Username="zbxapi"
ZABBIX_API_Password="2015zbxapi2015"
ZABBIX_Groupname_ZabbixSuperAdmin_for_Sync="LDAP-SuperAdmin"
ZABBIX_Disabled_User_Group="Disabled"

# Zabbix User type for new created Users:
# 1 - (default) Zabbix user;
# 2 - Zabbix admin;
# 3 - Zabbix super admin.
ZABBIX_Default_User_Type=1

# Zabbix Media Type Id
# At new Installation:
# 1 - Email
# 2 - Jabber
# 3 - SMS
ZABBIX_MediaTypeID="1"

ZABBIX_MediaTypeID="4204200000000001"

#############################################################################################################
#############################################################################################################
#############################################################################################################
#############################################################################################################
#############################################################################################################
#############################################################################################################
#############################################################################################################
#############################################################################################################
#   _____ _               _                                          _     _ _            
#  / ____| |             | |                                        (_)   (_) |           
# | |    | |__   ___  ___| | __  _ __  _ __ ___ _ __ ___  __ _ _   _ _ ___ _| |_ ___  ___ 
# | |    | '_ \ / _ \/ __| |/ / | '_ \| '__/ _ \ '__/ _ \/ _` | | | | / __| | __/ _ \/ __|
# | |____| | | |  __/ (__|   <  | |_) | | |  __/ | |  __/ (_| | |_| | \__ \ | ||  __/\__ \
#  \_____|_| |_|\___|\___|_|\_\ | .__/|_|  \___|_|  \___|\__, |\__,_|_|___/_|\__\___||___/
#                               | |                         | |                           
#                               |_|                         |_|                           
# ldapsearch installed?
if ! type "ldapsearch" > /dev/null; then
    echo "+- ERROR -----------------------"
    echo "| ldapsearch is not installed!"
    echo "| try:"
    echo "| apt install ldap-utils"
    echo "| yum install openldap-clients"
    echo "+-------------------------------"
    exit 1
fi
# curl installed?
if ! type "curl" > /dev/null; then
    echo "+- ERROR -----------------------"
    echo "| curl is not installed!"
    echo "| try:"
    echo "| apt install curl"
    echo "| yum install curl"
    echo "+-------------------------------"
    exit 1
fi
# sed installed?
if ! type "sed" > /dev/null; then
    echo "+- ERROR -----------------------"
    echo "| sed is not installed!"
    echo "| try:"
    echo "| apt install sed"
    echo "| yum install sed"
    echo "+-------------------------------"
    exit 1
fi
# printf installed?
if ! type "printf" > /dev/null; then
    echo "+- ERROR -----------------------"
    echo "| printf is not installed!"
    echo "| try:"
    echo "| apt install sed"
    echo "| yum install sed"
    echo "+-------------------------------"
    exit 1
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
echo
echo "STEP 1: Getting all Members from Active Directory / LDAP Group"
echo "--------------------------------------------------------------"
echo "Group Name ......: $LDAP_Groupname_ZabbixSuperAdmin_for_Sync"
echo "LDAP Server .....: $LDAP_Source_URL"
echo "LDAP User .......: $LDAP_Bind_User_DN"
echo "LDAP Search Base : $LDAP_SearchBase"
echo "--------------------------------------------------------------"
if [ LDAP_Ignore_SSL_Certificate = "false" ]; then
    # normal ldapsearch call
    tempvar=`ldapsearch -x -H $LDAP_Source_URL -D "$LDAP_Bind_User_DN" -w "$LDAP_Bind_User_Password" -b "$LDAP_SearchBase" "(&(objectClass=group)(cn=$LDAP_Groupname_ZabbixSuperAdmin_for_Sync))" o member | grep member:`
else
    # ignore SSL ldapsearch
    tempvar=`LDAPTLS_REQCERT=never ldapsearch -x -H $LDAP_Source_URL -D "$LDAP_Bind_User_DN" -w "$LDAP_Bind_User_Password" -b "$LDAP_SearchBase" "(&(objectClass=group)(cn=$LDAP_Groupname_ZabbixSuperAdmin_for_Sync))" o member | grep member:`
fi
LDAP_ARRAY_Members_RAW=($tempvar) # Split the raw output into an array
LDAP_ARRAY_Members_DN=()
for (( i=0; i < ${#LDAP_ARRAY_Members_RAW[*]}; i++ )); do
    # Search for the word "member:" in Array - the next value is the DN of a Member
    if [ "${LDAP_ARRAY_Members_RAW[$i]:0:7}" = "member:" ]; then
        i=$(($i + 1))
        LDAP_ARRAY_Members_DN+=("${LDAP_ARRAY_Members_RAW[$i]}") # add new Item to the end of the array
    else
        # Ok, no "member:" found and the Item was not skipped by i=i+1 - must still belong to the previous Item, which was separated by a space
        last_item_of_array=${#LDAP_ARRAY_Members_DN[*]} # get the Number of Items in the array
        last_item_of_array=$(($last_item_of_array - 1)) # get the Index of the last one (0 is the first index but the number of Items would be 1)
        LDAP_ARRAY_Members_DN[$last_item_of_array]+=" ${LDAP_ARRAY_Members_RAW[$i]}" # without ( ) -> replace the Item-Value, add no new Item to the array
    fi
done
if [ "${#LDAP_ARRAY_Members_DN[*]}" -eq 0 ]; then
    # No Members in Group or an error with ldapsearch
    echo "+- ERROR -----------------------"
    echo " No Members in Group or an Error with ldapsearch"
    echo " try the following commands manual for testing:"
    echo 'ldapsearch -x -H '$LDAP_Source_URL' -D "'$LDAP_Bind_User_DN'" -w "'$LDAP_Bind_User_Password'" -b "'$LDAP_SearchBase'" "(&(objectClass=group)(cn='$LDAP_Groupname_ZabbixSuperAdmin_for_Sync'))"'
    echo "With ignore SSL Certificate:"
    echo 'LDAPTLS_REQCERT=never ldapsearch -x -H '$LDAP_Source_URL' -D "'$LDAP_Bind_User_DN'" -w "'$LDAP_Bind_User_Password'" -b "'$LDAP_SearchBase'" "(&(objectClass=group)(cn='$LDAP_Groupname_ZabbixSuperAdmin_for_Sync'))"'
    
    echo "+-------------------------------"
    exit 1
else
    echo 'Got "Distinguished Name" for '${#LDAP_ARRAY_Members_DN[*]}' members:'
    for (( i=0; i < ${#LDAP_ARRAY_Members_DN[*]}; i++ )); do
        echo "$i: ${LDAP_ARRAY_Members_DN[$i]}"
    done
    echo "--------------------------------------------------------------"
fi
printf "Query sAMAccountName, sn, givenName and primary Email-Address "
declare -a LDAP_ARRAY_Members_sAMAccountName
declare -a LDAP_ARRAY_Members_Surname
declare -a LDAP_ARRAY_Members_Givenname
declare -a LDAP_ARRAY_Members_Email
LDAP_ARRAY_Members_sAMAccountName=()
LDAP_ARRAY_Members_Surname=()
LDAP_ARRAY_Members_Givenname=()
LDAP_ARRAY_Members_Email=()
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
            LDAP_ARRAY_Members_Surname+=("   ")
        fi
        if [ "$b_check_Givenname" = "false" ]; then
            LDAP_ARRAY_Members_Givenname+=("   ")
        fi
        if [ "$b_check_Email" = "false" ]; then
            LDAP_ARRAY_Members_Email+=("   ")
        fi

    fi
    if [ LDAP_Ignore_SSL_Certificate = "false" ]; then
        # sed replace all ": " and "new line" to "|"
        tempvar=`ldapsearch -x -H $LDAP_Source_URL -D "$LDAP_Bind_User_DN" -w "$LDAP_Bind_User_Password" -b "${LDAP_ARRAY_Members_DN[$i]}" o sAMAccountName o sn o givenName o mail | grep "^sn: \|^givenName: \|^sAMAccountName: \|^mail:" | sed 's/$/|/' | sed 's/: /|/'`
    else
        # sed replace all ": " and "new line" to "|"
        tempvar=`LDAPTLS_REQCERT=never ldapsearch -x -H $LDAP_Source_URL -D "$LDAP_Bind_User_DN" -w "$LDAP_Bind_User_Password" -b "${LDAP_ARRAY_Members_DN[$i]}" o sAMAccountName o sn o givenName o mail | grep "^sn: \|^givenName: \|^sAMAccountName: \|^mail:" | sed 's/$/|/' | sed 's/: /|/'`
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
            printf "."
            LDAP_ARRAY_Members_sAMAccountName+=("${LDAP_ARRAY_Members_RAW[$k]}")
            b_check_sAMAccountName="true"
        fi
        if [ "${LDAP_ARRAY_Members_RAW[$k]}" = "sn" ]; then
            k=$(($k + 1))
            # echo "add SN: ${LDAP_ARRAY_Members_RAW[$k]}"
            printf "."
            LDAP_ARRAY_Members_Surname+=("${LDAP_ARRAY_Members_RAW[$k]}")
            b_check_Surname="true"
        fi
        if [ "${LDAP_ARRAY_Members_RAW[$k]}" = "givenName" ]; then
            k=$(($k + 1))
            # echo "add givenName: ${LDAP_ARRAY_Members_RAW[$k]}"
            printf "."
            LDAP_ARRAY_Members_Givenname+=("${LDAP_ARRAY_Members_RAW[$k]}")
            b_check_Givenname="true"
        fi
        if [ "${LDAP_ARRAY_Members_RAW[$k]}" = "mail" ]; then
            k=$(($k + 1))
            # echo "add Email: ${LDAP_ARRAY_Members_RAW[$k]}"
            printf "."
            LDAP_ARRAY_Members_Email+=("${LDAP_ARRAY_Members_RAW[$k]}")
            b_check_Email="true"
        fi
    done
done
echo " done"
unset LDAP_ARRAY_Members_RAW
echo "------------------------------------------------------------------------------------------------"
echo "Result from STEP 1: Getting all Members from Active Directory / LDAP Group $LDAP_Groupname_ZabbixSuperAdmin_for_Sync"
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
echo

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
ZABBIX_authentication_token=$(curl -k -s -X POST -H "Content-Type:application/json" -d '{"jsonrpc": "2.0","method":"user.login","params":{"user":"'$ZABBIX_API_Username'","password":"'$ZABBIX_API_Password'"},"id":42}' $ZABBIX_API_URL | cut -d'"' -f8)
#echo Anmeldetoken: $ZABBIX_authentication_token
if [ "${#ZABBIX_authentication_token}" -ne 32 ]; then
    # Token have 32 Chars - something went wrong
    echo "+- ERROR -----------------------"
    echo " Login Zabbix API failed!"
    echo " try the following commands manual for testing:"
    printf 'curl -k -s -X POST -H "Content-Type:application/json" -d '
    printf "'"
    printf '{"jsonrpc": "2.0","method":"user.login","params":{"user":"'$ZABBIX_API_Username'","password":"'$ZABBIX_API_Password'"},"id":42}'
    printf "'"
    echo " $ZABBIX_API_URL"
    echo "+-------------------------------"
    exit 1
fi
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
echo
echo "STEP 2: Get Members of Zabbix-LDAP Group"
echo "--------------------------------------------------------------"
echo "Zabbix LDAP Group Name .........: $ZABBIX_Groupname_ZabbixSuperAdmin_for_Sync"
echo "Zabbix Disabled User Group Name : $ZABBIX_Disabled_User_Group"
echo "Zabbix API URL .................: $ZABBIX_API_Username"
echo "Zabbix API User ................: $LDAP_Bind_User_DN"
echo "--------------------------------------------------------------"
#############################################################################################################
# Get UsrGrpIds
printf "determine UsrGrpID of $ZABBIX_Groupname_ZabbixSuperAdmin_for_Sync ... "
declare -a ZABBIX_ARRAY_usrgrpid_RAW
tempvar=`curl -k -s -X POST -H "Content-Type:application/json"  -d '{"jsonrpc":"2.0","method":"usergroup.get","params":{"filter":{"name":"'$ZABBIX_Groupname_ZabbixSuperAdmin_for_Sync'"},"output":"extend","status":0},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
#echo $tempvar
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
echo " done"
tempvar=""
printf "determine UsrGrpID of $ZABBIX_Disabled_User_Group ... "
tempvar=`curl -k -s -X POST -H "Content-Type:application/json"  -d '{"jsonrpc":"2.0","method":"usergroup.get","params":{"filter":{"name":"'$ZABBIX_Disabled_User_Group'"},"output":"extend","status":1},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
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
echo " done"
tempvar=""
unset ZABBIX_ARRAY_usrgrpid_RAW
#############################################################################################################
# Get alias and userid of Zabbix Group Members
printf "determine alias and userid of all Members of $ZABBIX_Groupname_ZabbixSuperAdmin_for_Sync "
declare -a ZABBIX_ARRAY_LDAP_GroupMember_alias
declare -a ZABBIX_ARRAY_LDAP_GroupMember_userid
declare -a ZABBIX_ARRAY_LDAP_GroupMember_RAW
ZABBIX_ARRAY_LDAP_GroupMember_alias=()
ZABBIX_ARRAY_LDAP_GroupMember_userid=()

tempvar=`curl -k -s -X POST -H "Content-Type:application/json"  -d '{"jsonrpc": "2.0","method":"user.get","params":{"usrgrpids":"'$ZABBIX_LDAP_Group_UsrGrpId'","output":["alias","userid"]},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
IFS='"' # " is set as delimiter
ZABBIX_ARRAY_LDAP_GroupMember_RAW=($tempvar)
IFS=' ' # space is set as delimiter
for (( i=0; i < ${#ZABBIX_ARRAY_LDAP_GroupMember_RAW[*]}; i++ )); do
    #echo "Wert $i: ${ZABBIX_ARRAY_LDAP_GroupMember_RAW[$i]}"
    # Wir gehen davon aus das UserId und Alias immer - in beliebiger Reihenfolge - hintereinander kommen, der Index der beiden Arrays sollte also zueinander passen
    if [ "${ZABBIX_ARRAY_LDAP_GroupMember_RAW[$i]}" = "userid" ]; then
        i=$(($i + 2))
        ZABBIX_ARRAY_LDAP_GroupMember_userid+=("${ZABBIX_ARRAY_LDAP_GroupMember_RAW[$i]}")
        printf "."
    fi
    if [ "${ZABBIX_ARRAY_LDAP_GroupMember_RAW[$i]}" = "alias" ]; then
        i=$(($i + 2))
        ZABBIX_ARRAY_LDAP_GroupMember_alias+=("${ZABBIX_ARRAY_LDAP_GroupMember_RAW[$i]}")
        printf "."
    fi
done
echo " done!"
unset ZABBIX_ARRAY_LDAP_GroupMember_RAW
echo "------------------------------------------------------------------------------------------------"
echo "Result from STEP 2: Get Members of Zabbix-LDAP Group $ZABBIX_Groupname_ZabbixSuperAdmin_for_Sync"
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
echo
echo
#############################################################################################################
#   _____                                        _____                           
#  / ____|                                      / ____|                          
# | |     ___  _ __ ___  _ __   __ _ _ __ ___  | |  __ _ __ ___  _   _ _ __  ___ 
# | |    / _ \| '_ ` _ \| '_ \ / _` | '__/ _ \ | | |_ | '__/ _ \| | | | '_ \/ __|
# | |___| (_) | | | | | | |_) | (_| | | |  __/ | |__| | | | (_) | |_| | |_) \__ \
#  \_____\___/|_| |_| |_| .__/ \__,_|_|  \___|  \_____|_|  \___/ \__,_| .__/|___/
#                       | |                                           | |        
#                       |_|                                           |_|        
echo
echo "STEP 3: Compare Groups for changes"
echo "--------------------------------------------------------------"
echo "AD / LDAP Group Name ...........: $LDAP_Groupname_ZabbixSuperAdmin_for_Sync"
echo "Zabbix LDAP Group Name .........: $ZABBIX_Groupname_ZabbixSuperAdmin_for_Sync"
echo "--------------------------------------------------------------"
b_Must_Sync_Users="false"
# Check 1:
printf "Check 1: Compare Number of Users ... "
printf "should: ${#LDAP_ARRAY_Members_sAMAccountName[*]} ... "
printf "Is: ${#ZABBIX_ARRAY_LDAP_GroupMember_alias[*]} ... "
if [ "${#LDAP_ARRAY_Members_sAMAccountName[*]}" -eq "${#ZABBIX_ARRAY_LDAP_GroupMember_alias[*]}" ]; then
    echo "equal!"
else
    echo "differently! Start synchronizing!"
    b_Must_Sync_Users="true"
fi
# Check 2:
if [ "$b_Must_Sync_Users" = "false" ]; then
    # make Compare case insensitive, save original settings
    orig_nocasematch=$(shopt -p nocasematch)
    shopt -s nocasematch
    printf "Check 2: Compare Active Directory sAMAccountName with Zabbix Alias "
    # Check every sAMAccountName and find a alias for it
    for (( i=0; i < ${#LDAP_ARRAY_Members_sAMAccountName[*]}; i++ )); do
        b_alias_was_found="false"
        for (( k=0; k < ${#ZABBIX_ARRAY_LDAP_GroupMember_alias[*]}; k++ )); do
            if [[ "${LDAP_ARRAY_Members_sAMAccountName[$i]}" == "${ZABBIX_ARRAY_LDAP_GroupMember_alias[$k]}" ]]; then
                printf "."
                b_alias_was_found="true"
                break
            fi
        done
        if [ "$b_alias_was_found" = "false" ]; then
            b_Must_Sync_Users="true"
            echo " ${LDAP_ARRAY_Members_sAMAccountName[$i]} not found! Start synchronizing!"
            break
        fi
    done
    # restore original case sensitive/insenstive settings
    $orig_nocasematch
    echo " done!"
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
    echo
    echo "--------------------------------------------------------------"
    echo "STEP 4: Get all Zabbix Users with alias and userid"
    # get a List of all Zabbix Users to get the possible UserIds of new Users
    tempvar=""
    declare -a ZABBIX_ARRAY_AllUser_alias
    declare -a ZABBIX_ARRAY_AllUser_userid
    declare -a ZABBIX_ARRAY_AllUser_RAW
    ZABBIX_ARRAY_AllUser_alias=()
    ZABBIX_ARRAY_AllUser_userid=()
    tempvar=`curl -k -s -X POST -H "Content-Type:application/json"  -d '{"jsonrpc": "2.0","method":"user.get","params":{"output":["alias","userid"]},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
    IFS='"' # " is set as delimiter
    ZABBIX_ARRAY_AllUser_RAW=($tempvar)
    IFS=' ' # space is set as delimiter
    printf "Processing ."
    for (( i=0; i < ${#ZABBIX_ARRAY_AllUser_RAW[*]}; i++ )); do
        # We assume that the UserId and Alias always come one after the other in any order, so the index of the two arrays should match
        if [ "${ZABBIX_ARRAY_AllUser_RAW[$i]}" = "userid" ]; then
            i=$(($i + 2))
            ZABBIX_ARRAY_AllUser_userid+=("${ZABBIX_ARRAY_AllUser_RAW[$i]}")
            printf "."
        fi
        if [ "${ZABBIX_ARRAY_AllUser_RAW[$i]}" = "alias" ]; then
            i=$(($i + 2))
            ZABBIX_ARRAY_AllUser_alias+=("${ZABBIX_ARRAY_AllUser_RAW[$i]}")
            printf "."
        fi
    done
    echo " done!"
    unset ZABBIX_ARRAY_AllUser_RAW
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
    echo
    echo
    echo
    echo
    echo "--------------------------------------------------------------"
    echo "STEP 5: Compare LDAP user with existing Zabbix User"
    # additional Array for Zabbix-UserId
    declare -a LDAP_ARRAY_Members_UserId
    LDAP_ARRAY_Members_UserId=()
    # Merker ob wir neue Benutzer anlegen müssen
    b_have_to_create_new_user="false"
    # Compare LDAP-User with Zabbix-User
    # make Compare case insensitive, save original settings
    orig_nocasematch=$(shopt -p nocasematch)
    shopt -s nocasematch
    for (( i=0; i < ${#LDAP_ARRAY_Members_sAMAccountName[*]}; i++ )); do
        b_we_have_a_winner="false"
        for (( k=0; k < ${#ZABBIX_ARRAY_AllUser_alias[*]}; k++ )); do
            if [[ "${LDAP_ARRAY_Members_sAMAccountName[$i]}" == "${ZABBIX_ARRAY_AllUser_alias[$k]}" ]]; then
                LDAP_ARRAY_Members_UserId+=("${ZABBIX_ARRAY_AllUser_userid[$k]}")
                b_we_have_a_winner="true"
                break
            fi
        done
        # User was found?
        if [ "$b_we_have_a_winner" = "false" ]; then
            # User was not found - but we need an array item to have all array index identical and matched to each other
            # also mark this User to have to be created
            LDAP_ARRAY_Members_UserId+=("create-user")
            b_have_to_create_new_user="true"
        fi
    done
    # restore original case sensitive/insenstive settings
    $orig_nocasematch
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
    echo
    echo
    echo
    #############################################################################################################
    if [ "$b_have_to_create_new_user" = "true" ]; then
        echo "--------------------------------------------------------------"
        echo "STEP 6: Create needed new Zabbix-User"
        declare -a ZABBIX_ARRAY_New_User_RAW
        # Search for all User with UserId "create-user"
        for (( i=0; i < ${#LDAP_ARRAY_Members_sAMAccountName[*]}; i++ )); do
            if [ "${LDAP_ARRAY_Members_UserId[$i]}" = "create-user" ]; then
                printf "Create new user ${LDAP_ARRAY_Members_sAMAccountName[$i]} ... "
                tempSAM='"'"${LDAP_ARRAY_Members_sAMAccountName[$i]}"'"'
                # Check the things we have
                create_combination=""
                if [ "${LDAP_ARRAY_Members_Surname[$i]}" != "   " ]; then
                    create_combination+="X"
                    tempSURNAME='"'"${LDAP_ARRAY_Members_Surname[$i]}"'"'
                else
                    create_combination+="O"
                fi
                if [ "${LDAP_ARRAY_Members_Givenname[$i]}" != "   " ]; then
                    create_combination+="X"
                    tempNAME='"'"${LDAP_ARRAY_Members_Givenname[$i]}"'"'
                else
                    create_combination+="O"
                fi
                if [ "${LDAP_ARRAY_Members_Email[$i]}" != "   " ]; then
                    create_combination+="X"
                    tempEmail='"'"${LDAP_ARRAY_Members_Email[$i]}"'"'
                else
                    create_combination+="O"
                fi
                # create_combination should be OOO, OOX, OXO, OXX, XOO, XOX, XXO or XXX
                tempvar=""
                case "$create_combination" in
                    "OOO")  # No Surname, Givenname or Email
                            tempvar=`curl -k -s -X POST -H "Content-Type:application/json" -d '{"jsonrpc":"2.0","method":"user.create","params":{"alias":'"$tempSAM"',"usrgrps":[{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'"}],"type":'$ZABBIX_Default_User_Type'},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
                            ;;
                    "OOX")  # Email, but no Surname or Givenname
                            tempvar=`curl -k -s -X POST -H "Content-Type:application/json" -d '{"jsonrpc":"2.0","method":"user.create","params":{"alias":'"$tempSAM"',"user_medias":[{"mediatypeid": "'$ZABBIX_MediaTypeID'","sendto":['"$tempEmail"']}],"usrgrps":[{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'"}],"type":'$ZABBIX_Default_User_Type'},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
                            
                            ;;
                    "OXO")  # Givenname, but no Surname or Email
                            tempvar=`curl -k -s -X POST -H "Content-Type:application/json" -d '{"jsonrpc":"2.0","method":"user.create","params":{"alias":'"$tempSAM"',"name":'"$tempNAME"',"usrgrps":[{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'"}],"type":'$ZABBIX_Default_User_Type'},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
                            ;;
                    "OXX")  # Givenname and Email, no Surname
                            tempvar=`curl -k -s -X POST -H "Content-Type:application/json" -d '{"jsonrpc":"2.0","method":"user.create","params":{"alias":'"$tempSAM"',"user_medias":[{"mediatypeid": "'$ZABBIX_MediaTypeID'","sendto":['"$tempEmail"']}],"name":'"$tempNAME"',"usrgrps":[{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'"}],"type":'$ZABBIX_Default_User_Type'},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
                            ;;
                    "XOO")  # Surname, but no Givenname or Email
                            tempvar=`curl -k -s -X POST -H "Content-Type:application/json" -d '{"jsonrpc":"2.0","method":"user.create","params":{"alias":'"$tempSAM"',"surname":'"$tempSURNAME"',"usrgrps":[{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'"}],"type":'$ZABBIX_Default_User_Type'},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
                            ;;
                    "XOX")  # Surname and Email, but no Givenname
                            tempvar=`curl -k -s -X POST -H "Content-Type:application/json" -d '{"jsonrpc": "2.0","method":"user.create","params":{"alias":'"$tempSAM"',"surname":'"$tempSURNAME"',"user_medias":[{"mediatypeid": "'$ZABBIX_MediaTypeID'","sendto":['"$tempEmail"']}],"usrgrps":[{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'"}],"type":'$ZABBIX_Default_User_Type'},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
                            ;;
                    "XXO")  # Surname and Givenname, but no Email
                            tempvar=`curl -k -s -X POST -H "Content-Type:application/json" -d '{"jsonrpc":"2.0","method":"user.create","params":{"alias":'"$tempSAM"',"name":'"$tempNAME"',"surname":'"$tempSURNAME"',"usrgrps":[{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'"}],"type":'$ZABBIX_Default_User_Type'},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
                            ;;
                    "XXX")  # Surname, Givenname and Email
                            tempvar=`curl -k -s -X POST -H "Content-Type:application/json" -d '{"jsonrpc": "2.0","method":"user.create","params":{"alias":'"$tempSAM"',"name":'"$tempNAME"',"surname":'"$tempSURNAME"',"user_medias":[{"mediatypeid": "'$ZABBIX_MediaTypeID'","sendto":['"$tempEmail"']}],"usrgrps":[{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'"}],"type":'$ZABBIX_Default_User_Type'},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
                            ;;
                esac
                #echo "$tempvar"
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
                echo " done (UserId: LDAP_ARRAY_Members_UserId[$i])"
            fi
        done
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
        echo
        echo
        echo
    fi
    
    #############################################################################################################
    echo "--------------------------------------------------------------"
    echo "STEP 7: Replace Members of Group $ZABBIX_LDAP_Group"
    printf "Create list of UserIds ..."
    tempvar=""
    list_of_userids=""
    for (( i=0; i < ${#LDAP_ARRAY_Members_sAMAccountName[*]}; i++ )); do
        list_of_userids+='"'${LDAP_ARRAY_Members_UserId[$i]}'"'
        list_of_userids+=","
    done
    list_of_userids=${list_of_userids::-1}
    echo " done"
    printf "Update Zabbix Group $ZABBIX_LDAP_Group via API (Replace) ... "
    tempvar=`curl -k -s -X POST -H "Content-Type:application/json"  -d '{"jsonrpc": "2.0","method":"usergroup.update","params":{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'","userids":['$list_of_userids']},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
    echo "done!"
    echo
    echo
    echo
    echo
    #############################################################################################################
    # 1. get a List of all User in the "Disabled User" group
    # 2. Remove all active user from this List
    # 3. Add all user wich was removed from LDAP-Group but was in the Zabbix-LDAP-Group found
    # 4. Update Members of Group "Disabled User" via Zabbix API
    echo "--------------------------------------------------------------"
    echo "STEP 8: Get List of all disabled user in Group $ZABBIX_Disabled_User_Group"
    # 1. get a List of all User in the "Disabled User" group
    printf "Fetching UserIds ... "
    declare -a ZABBIX_ARRAY_disabled_User_userid
    declare -a ZABBIX_ARRAY_disabled_User_RAW
    ZABBIX_ARRAY_disabled_User_userid=()
    tempvar=`curl -k -s -X POST -H "Content-Type:application/json"  -d '{"jsonrpc": "2.0","method":"user.get","params":{"usrgrpids":"'$ZABBIX_Disabled_Group_UsrGrpId'","output":["userid"],"status":1},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
    #echo $tempvar
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
    echo " done!"
    echo
    echo
    echo
    echo
    echo "--------------------------------------------------------------"
    echo "STEP 9: Remove active user, add inactive user"
    # 2. Remove all active user from this List
    # 3. Add all user wich was removed from LDAP-Group but was in the Zabbix-LDAP-Group found
    declare -a new_ZABBIX_ARRAY_disabled_User_userid
    new_ZABBIX_ARRAY_disabled_User_userid=()
    printf "Removing active Users from List ... "
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
    echo "done!"
    printf "Adding inactive Users ... "
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
    echo "done!"
    
    echo
    echo
    echo
    echo
    echo "--------------------------------------------------------------"
    echo "STEP 9: Replace Members of Group $ZABBIX_Disabled_User_Group"
    printf "Create list of UserIds ..."
    tempvar=""
    list_of_userids=""
    for (( i=0; i < ${#new_ZABBIX_ARRAY_disabled_User_userid[*]}; i++ )); do
        list_of_userids+='"'${new_ZABBIX_ARRAY_disabled_User_userid[$i]}'"'
        list_of_userids+=","
    done
    list_of_userids=${list_of_userids::-1}
    printf "Update Zabbix Group $ZABBIX_Disabled_User_Group via API (Replace) ... "
    tempvar=`curl -k -s -X POST -H "Content-Type:application/json"  -d '{"jsonrpc": "2.0","method":"usergroup.update","params":{"usrgrpid":"'$ZABBIX_Disabled_Group_UsrGrpId'","userids":['$list_of_userids']},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
    echo "done!"
    echo
    echo
    echo
    echo
    #############################################################################################################
    echo "--------------------------------------------------------------"
    echo "STEP 10: Replace Members of Group $ZABBIX_LDAP_Group (2. Time)"
    # we have to do this twice if we move user between enabled and disabled and they are only in the Zabbix-LDAP-Group - they must be in one Group!"
    # If a user is a now a member of the deactivated user group we can now remove the user from the Zabbix-LDAP-Group
    printf "Create list of UserIds ..."
    tempvar=""
    list_of_userids=""
    for (( i=0; i < ${#LDAP_ARRAY_Members_sAMAccountName[*]}; i++ )); do
        list_of_userids+='"'${LDAP_ARRAY_Members_UserId[$i]}'"'
        list_of_userids+=","
    done
    list_of_userids=${list_of_userids::-1}
    echo " done"
    printf "Update Zabbix Group $ZABBIX_LDAP_Group via API (Replace) ... "
    tempvar=`curl -k -s -X POST -H "Content-Type:application/json"  -d '{"jsonrpc": "2.0","method":"usergroup.update","params":{"usrgrpid":"'$ZABBIX_LDAP_Group_UsrGrpId'","userids":['$list_of_userids']},"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL`
    echo "done!"
    echo
    echo
    echo
    echo
else
    echo
    echo "No Changes found! Nothing to do!"
    echo
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
echo
printf "Logout Zabbix API ... "
myJSON=$(curl -k -s -X POST -H "Content-Type:application/json"  -d '{"jsonrpc": "2.0","method":"user.logout","params":[],"id":42,"auth":"'$ZABBIX_authentication_token'"}' $ZABBIX_API_URL)
echo "done"
echo
exit 0
