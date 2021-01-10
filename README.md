# zabbix-ldap-sync-bash
This is a pure bash-script for syncing a Actice-Directory Group via LDAP with a Zabbix-Group

**Changelog:**<br>
 - 2020-04-14 **V1.1** => first public version 
 - 2020-04-17 **V1.1a** => Replace hard coded $2 with push-solution
 - 2020-05-05 **V1.1b** => add ldapsearch parameter `-o ldif-wrap=no` to prevent line breaks after 79 chars
 - 2020-08-06 **V1.1c** => add more debbuging for -v when a new user is created (show the full curl command)
 - 2021-01-10 **V1.2** => add support for Zabbix 5.2 or higher (breaking changes in API) with API-Version check bultin
<br>

## Features
 - Pure Bash Skript for Linux
 - LDAP and LDAPS Support (ignoring SSL possible)
 - Zabbix API via http / https (ignoring SLL per default)
 - Zabbix 3.x, 4.x and 5.x tested (new User Roles since Version 5.2 are supported)
 - Multiple config-files possible for multiple groups and multiple domains
 - Create needed users in Zabbix including Email-Address as media
   - up to Zabbix 5.0.x as User, Admin or SuperAdmin
   - from Zabbix 5.2.x using the User Role (roleid)
 - Disable users in Zabbix which are removed from Group
 - user- or group names with spaces are no problem

## How to Use
### 1. Prepare Active Directory
 - Check if LDAP or LDAPS will be used
 - Create a special User for the LDAP Access. User need no special rights but should be Domain-User
 - Avoid special chars in username and password like `äöü!?>$%` and spaces
 - After creating get the ***distinguished name*** of this user. You can query the name on a domain controller with<br>



```
dsquery user -samid name_of_the_user
```

Output should something like

    
    CN=ldapSearch,OU=MyUsers,DC=exampledomain,DC=local

where ***ldapSearch*** is the example-user
<br>
<br>
 
Create one or more Active Directory Groups and add Members. Empty Groups are allowed (then all members in Zabbix will be removed from Group and disabled).
I suggest Groups for
 - Zabbix Super Admin
 - Zabbix Admin
 - Zabbix User
<br>
as needed. The users must be direct members, do not use nested groups.<br>

In the examples i am using the groupname `Zabbix-Super-Admin`<br>


### 2. Install Prerequisites on Linux
Yes, i am using pure bash to avoid any prerequisites but we need a program for accessing LDAP and some other tools. All of them should be available in the standard repositories:<br>

**Debian/Ubuntu**
    
    apt install ldap-utils
**Red Hat/CentOs/SuSe**
    
    yum install openldap-clients
The other needed programs are
    
    curl
    sed
    dirname
    readlink
which should be already installed

### 3. Create Zabbix-User for API Access
It should be a non LDAP user with **Frontend acccess** `internal` (defined by Group Membership)<br>
The User must have the **User type** `Zabbix Super Admin` for creating new users and changing group memberships.<br>
Also avoid special chars in username and password.<br>
In the examples i am using the username `zabbixapiuser`<br>

### 4. Create Zabbix Target Groups
At least 2 groups are required:<br>
<br>
**Target Group for Users:**<br>
This Group must have **Frontend access** `LDAP`<br>
and should be enabled. 
In the examples i am using the groupname `Zabbix-Super-Admin`<br>
<br>
**Target Group for Disabled Users:**<br>
The build-in Group **Disabled** can be used.<br>
Or create a new group which is **not** enabled (remove checkox) and **Frontend access** `Disabled`<br>
In the examples i am using the groupname`LDAP-Disabled`<br>
<br>
### 5. Check Zabbix LDAP-Settings
Check the Settings for LDAP:

    Administration => Authentication => LDAP settings
I suggest to uncheck the **Case sensitive login** checkbox. The script compares the Windows `SAMAccountnames` and the Zabbix `Alias` case insensitive.
With this settings, the user can log in with `manfred`, `Manfred`and `MaNfReD`and the sync script will find and use the existing user.

### 6. Clone the script
I installed the script on the Zabbix-Server in a separate folder.
Login to Zabbix-Server and move to the root path of the `ExternalScripts` and `AlertScriptsPath` folder, 
the default path is (Debian/Ubuntu/CentOS)
    
    cd /usr/lib/zabbix/
Clone this repository, it will create a new folder named `zabbix-ldap-sync-bash`:
    
    git clone https://github.com/BernhardLinz/zabbix-ldap-sync-bash.git
Change to the new directory:
    
    cd zabbix-ldap-sync-bash
Make the two `*.sh`scripts executeable:
    
    chmod +x *.sh


### 7. Configure the Script
The script `zabbix-ldap-sync.sh`is looking for the `config.sh`in the same folder (if no config-file is specified).<br>
Just make a copy of the `config-example.sh` <br>
    
    cp config-example.sh config.sh
Open the file `config.sh`with an editor and set the needed values:
    
    nano config .sh

#### LDAP_Source_URL
    LDAP_Source_URL="ldaps://172.16.0.10"
Should be `ldap`or `ldaps`, use name or IP-Address of a domain controller.

#### LDAP_Ignore_SSL_Certificate
    LDAP_Ignore_SSL_Certificate="true"
If set to `true`the SSL-Certificate for LDAPS will be ignored. Set to `false`to validate the certificates.



#### LDAP_Bind_User_DN + LDAP_Bind_User_Password
    LDAP_Bind_User_DN="CN=ldapSearch,OU=MyUsers,DC=exampledomain,DC=local"
    LDAP_Bind_User_Password="9qA3XB1r##Xr27c1HPpq"
The distinguished name for the user which was created in Step *1. Prepare Active Directory*

#### LDAP_SearchBase
    LDAP_SearchBase="DC=exampledomain,DC=local"
The domain name or organisation unit

#### LDAP_Groupname_for_Sync + ZABBIX_Groupname_for_Sync
    LDAP_Groupname_for_Sync="Zabbix-Super-Admin"
    ZABBIX_Groupname_for_Sync="LDAP-SuperAdmin"
Change `Zabbix-Super-Admin`to your Active Directory-Groupname and `LDAP-SuperAdmin`to the target Zabbix-Groupname.


#### ZABBIX_Disabled_User_Group
    ZABBIX_Disabled_User_Group="LDAP-Disabled"
Name of the Group for Disabled Users. The Group must have the ***Enabled*** checkbox unchecked or the group will not found.  Every user who is removed from the group ***ZABBIX_Groupname_for_Sync*** becomes a member of this group. The reason is that a user must always be a member of at least one group in Zabbix.

#### ZABBIX_API_URL + ZABBIX_API_User + ZABBIX_API_Password
    ZABBIX_API_URL="http://localhost/api_jsonrpc.php"
    ZABBIX_API_User="zabbixapiuser"
    ZABBIX_API_Password="strongpassword73#"
The **ZABBIX_API_URL** is path to the Zabbix webinterface. Can be `http://` or `https://`, the certificate validation will be ignored.
Depending on the Zabbix installation,  `/api_jsonrpc.php` or `/zabbix/api_jsonrpc.php` must be used.

#### ZABBIX_UserType_User
    ZABBIX_UserType_User=3
up to Zabbix 5.0.x there are 3 bultin Types, 1,2 or 3
from Zabbix 5.2.x there are User Rules. There are 3 predefined user roles which correspond to the pevious user types.
but you can define additional user roles in Zabbix and use here
The bultin Types (<=5.0.x) or predefined Roles (>=5.2.x) are
1 = Zabbix User
2 = Zabbix Admin
3 = Zabbix Super Admin
The script will not update existing zabbix-users.
You can check the ID of the RoleId in the webinterface 

    Administration => User roles => click the name of the role
At the end of the URL you see `roleid=1` with the needed ID

#### ZABBIX_MediaTypeID
    ZABBIX_MediaTypeID="1"
1 is Email at new installations. Will be used for new created users if the **mail** property is not empty (Microsoft Exchange will fill theses property automatically with the sender-address).
You can check the ID of the MediaType in the webinterface 

    Administration => Media types => click the name of the Media
At the end of the URL you see `mediatypeid=1` with the needed ID
### 8. Test the script
    ./zabbix-ldap-sync.sh
You should get some output like this:
    
    ---------------------------------------------------------------------------
    zabbix-ldap-sync.sh (Version V1.2 (2021-01-10)) startup
    Checking prerequisites ............................................... done
    Searching config file ................................................ done
    Reading "/usr/lib/zabbix/zabbix-ldap-sync-bash/config-znil.sh" ....... done
    Check all needed Settings ............................................ done
    STEP 1: Getting all Members from Active Directory / LDAP Group ....... done
    Query sAMAccountName, sn, givenName and primary Email-Address ........ done
    Check Zabbix API Version ............................................. done
    Using User mode ...................................................... roleid
    Login at Zabbix API .................................................. done
    STEP 2: Get Members of Zabbix-LDAP Groups ............................ checking
    determine UsrGrpID of "LDAP-SuperAdmin" .............................. done
    determine UsrGrpID of "LDAP-Disabled" ................................ done
    determine alias and userid for Members of "LDAP-SuperAdmin" .......... done
    STEP 3: Compare Groups for changes ................................... checking
    Check 1: Number of Users LDAP ........................................ 4
    Check 1: Number of Users Zabbix ...................................... 1
    Check 1: Number of Users ............................................. not equal
    STEP 4: Get all Zabbix Users with alias and userid ................... done
    STEP 5: Compare LDAP user with existing Zabbix User .................. must create 3 new user
    STEP 6: Create needed 3 new Zabbix-User .............................. done
    STEP 7: Replace Members of Group LDAP-SuperAdmin ..................... done
    STEP 8: Get List of all disabled user in Group LDAP-Disabled ......... done
    STEP 9: Remove active user, add inactive user ........................ done
    STEP 10: Replace Members of Group LDAP-Disabled ...................... done
    STEP 11: Replace Members of Group LDAP-SuperAdmin (2. Time) .......... done
    Logout Zabbix API .................................................... done

If there is an error with Login to LDAP or Zabbix an Error Message will be displayed. Check Output for more.
## Advanced Debugging
Try

    ./zabbix-ldap-sync.sh -v
for verbose mode with a lot of Output. You will see all `ldapsearch` and `curl` calls with parameter. Passwords are hidden with Stars.
If you want to see the passwords also try

    ./zabbix-ldap-sync.sh -v -p

## Possible commandline parameter
    -c | -C | --config			use a specific configuration file instead config.sh
    -v | -V | --verbose 		Display debugging information, include all commands
    -p | -P | --ShowPassword	Show the passwords in the verbose output
    -s | -S | --silent			Hide all Output except errors. Usefull with crontab

## Syncing Multiple Groups
Just create a separate config file for each group combination:

 - copy the working `config.sh`to a new name like `zabbix-readonly.conf`(the extension doesn't matter)
 - change the groupnames in the new file and the ZABBIX_UserType_User value
 - run the script like this
     
       ./zabbix-ldap-sync.sh -c zabbix-readonly.conf
Do not sync different LDAP-Groups with the same Zabbix-Group! The last sync will win!
Make the users only to a member of one of these groups. If the user is removed from one of the groups, the user will be disabled.

## Sync automatically
Test the sync in the shell with full paths like
     
     /usr/lib/zabbix/zabbix-ldap-sync-bash/zabbix-ldap-sync.sh -c /usr/lib/zabbix/zabbix-ldap-sync-bash/zabbix-readonly.conf
 Just add the line to crontab like
     
     */10 * * * * /usr/lib/zabbix/zabbix-ldap-sync-bash/zabbix-ldap-sync.sh -c /usr/lib/zabbix/zabbix-ldap-sync-bash/zabbix-readonly.conf -s
 for syncing every 10 minutes
Add a line to crontab for each group/configuration you want to sync

## Update the Script to latest Version
Change to the Script folder and just type<br>
    
    git pull
The `zabbix-ldap-sync.sh` and the ´config-example.sh´ maybe overwritten with the new versions.<br>
Your existing files will not be touched or deleted.<br>
