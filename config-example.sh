#!/bin/bash
#############################################################################################################
#   _____             __ _                       _   _             
#  / ____|           / _(_)                     | | (_)            
# | |     ___  _ __ | |_ _  __ _ _   _ _ __ __ _| |_ _  ___  _ __  
# | |    / _ \| '_ \|  _| |/ _` | | | | '__/ _` | __| |/ _ \| '_ \ 
# | |___| (_) | | | | | | | (_| | |_| | | | (_| | |_| | (_) | | | |
#  \_____\___/|_| |_|_| |_|\__, |\__,_|_|  \__,_|\__|_|\___/|_| |_|
#                           __/ |                                  
#                          |___/                                   
#############################################################################################################
# Configuration LDAP-Connection (Tested LDAPS with Windows Server 2019)
# URL of LDAP / LDAPS Server:
# LDAP:
# LDAP_Source_URL="ldap://IP_or_DNS_Name_Domain_Controller"
# LDAPS
LDAP_Source_URL="ldaps://172.16.0.10"
# If using LDAPS you can supress the check of the ssl certificate
LDAP_Ignore_SSL_Certificate="true"

# Bind user for accessing,
# to get the Distinguished Name of the User run the following command on a domain controller (replace ldapsearch with your Username):
# dsquery user -samid ldapSearch
LDAP_Bind_User_DN="CN=ldapSearch,OU=MyUsers,DC=exampledomain,DC=local"
# the passwort og the user (should be marked as never changed)
# Please avoid special chars which were use in bash like $`´'"\/<>()[]^
LDAP_Bind_User_Password="9qA3XB1r##Xr27c1HPpq"
# Searchbase - your Domain name or specify OU
LDAP_SearchBase="DC=exampledomain,DC=local"

# Name of Groups in LDAP (Active-Directory) and in Zabbix for Sync with Zabbix
LDAP_Groupname_for_Sync="Zabbix-Super-Admin"
ZABBIX_Groupname_for_Sync="LDAP-SuperAdmin"

# When you remove an user from the LDAP-Group, the user will moved in this group which is "Not enabled" = Disabled and Frontend access is "disabled"
ZABBIX_Disabled_User_Group="LDAP-Disabled"


# Configuration Zabbix API Connection (Tested with Zabbix 4.4)
# if https:// is used, per default ssl checks will be ignored
#ZABBIX_API_URL="http://localhost/zabbix/api_jsonrpc.php"
ZABBIX_API_URL="http://localhost/api_jsonrpc.php"
ZABBIX_API_User="zabbixapiuser"
ZABBIX_API_Password="strongpassword73#"

# Zabbix User type (up to Zabbix Version 5.0.x) oder RoleId (from Version 5.2.x) for new created Users.
# up to Zabbix 5.0.x there are 3 bultin Types, 1,2 or 3
# from Zabbix 5.2.x there are User Rules. There are 3 predefined user roles which correspond to the pevious user types.
# but you can define additional user roles in Zabbix and use here
# 1 - Zabbix user;
# 2 - Zabbix admin;
# 3 - Zabbix super admin.
ZABBIX_UserType_User=3

# Zabbix Media Type Id
# At new Installation
# 1 - Email
# 2 - Jabber
# 3 - SMS
# 4 - Email (HTML)
# 5 - Mattermost
# 6 - Opsgenie
# 7 - PagerDuty
# 8 - Pushover
# 9 - Slack
# 10 - Discord
# 11 - SIGNL4
# 12 - Jira
# 13 - Jira with CustomFields
# 14 - MS Teams
# 15 - Redmine
# 16 - Telegram
# 17 - Zendesk
# 18 - ServiceNow
# 19 - Zammad
# 20 - Jira ServiceDesk
# 21 - OTRS
# 22 - iLert
# 23 - SolarWinds Service Desk
# 24 - SysAid
# 25 - TOPdesk
# 26 - iTop

# Media Type Id can be different if you added own Types, delete Default Types or if you have an installation witch used "nodes" (Zabbix 2.x) in the past and you have set the node-Id
ZABBIX_MediaTypeID="1"

#############################################################################################################
#  ______           _          __   ______ _ _      
# |  ____|         | |        / _| |  ____(_) |     
# | |__   _ __   __| |   ___ | |_  | |__   _| | ___ 
# |  __| | '_ \ / _` |  / _ \|  _| |  __| | | |/ _ \
# | |____| | | | (_| | | (_) | |   | |    | | |  __/
# |______|_| |_|\__,_|  \___/|_|   |_|    |_|_|\___|
#############################################################################################################
