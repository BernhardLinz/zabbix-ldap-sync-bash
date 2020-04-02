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
LDAP_Bind_User_DN="CN=ldapSearch,OU=MyUsers,DC=mydomain,DC=local"
# the passwort og the user (should be marked as never changed)
# Please avoid special chars which were use in bash like $`´'"\/<>()[]^
LDAP_Bind_User_Password="9qA3XB1r.##Xr2+7c1HP--!pq"
# Searchbase - your Domain name or specify OU
LDAP_SearchBase="DC=znil,DC=local"

# Name of Groups in LDAP (Active-Directory) and in Zabbix for Sync with Zabbix
# if you do not want do use one of these groups set both groupnames to "skip" or comment out these lines
# Will be created as User Type "Zabbix Super Admin" (default)
LDAP_Groupname_ZabbixSuperAdmin_for_Sync="Zabbix-Super-Admin"
ZABBIX_Groupname_ZabbixSuperAdmin_for_Sync="LDAP-SuperAdmin"
# Will be created as User Type "Zabbix Admin" (default)
LDAP_Groupname_ZabbixAdmin_for_Sync="Zabbix-Admin"
ZABBIX_Groupname_ZabbixAdmin_for_Sync="LDAP-Admin"
# Will be created as User Type "Zabbix User" (default)
LDAP_Groupname_ZabbixUser_for_Sync="Zabbix-User"
ZABBIX_Groupname_ZabbixUser_for_Sync="LDAP-User"

# When you remove an user from the LDAP-Group, the user will moved in this group which is "Not enabled" = Disabled and Frontend access is "disabled"
ZABBIX_Disabled_User_Group="Disabled"


# Configuration Zabbix API Connection (Tested with Zabbix 4.4)
# if https:// is used, per default ssl checks will be ignored
#ZABBIX_API_URL="http://localhost/zabbix/api_jsonrpc.php"
ZABBIX_API_URL="http://localhost/api_jsonrpc.php"
ZABBIX_API_User="API-User"
ZABBIX_API_Password="strongpassword73#"

# Zabbix User type for new created Users:
# 1 - (default) Zabbix user;
# 2 - Zabbix admin;
# 3 - Zabbix super admin.
ZABBIX_UserType_User=1
ZABBIX_UserType_Admin=2
ZABBIX_UserType_SuperAdmin=3

# Zabbix Media Type Id
# At new Installation:
# 1 - Email
# 2 - Jabber
# 3 - SMS
# Media Type Id can be different if you add own Types, Delete Default Types or If have an Installation witch used "nodes" (Zabbix 2.x) in the past and you have set the bode-Id
ZABBIX_MediaTypeID="1"
#############################################################################################################
#  ______           _          __   ______ _ _      
# |  ____|         | |        / _| |  ____(_) |     
# | |__   _ __   __| |   ___ | |_  | |__   _| | ___ 
# |  __| | '_ \ / _` |  / _ \|  _| |  __| | | |/ _ \
# | |____| | | | (_| | | (_) | |   | |    | | |  __/
# |______|_| |_|\__,_|  \___/|_|   |_|    |_|_|\___|
#############################################################################################################