# ilo-adduser
The ilo-adduser.ps1 script allows to create ilo users thru OneView.

# Examples:

* Example 1
To create an user on a HPE ProLiant/Blade Gen9 server, create a csv file as below
- gen9sy4.0.csv
ServerName,Username,Password,Privileges
"CN754604F4, bay 1",hptest,password,All

Per Gen9 da OneView400
.\ilo-adduser.ps1 -OVApplianceIP 192.168.0.100 -OVAdminName Administrator -OVAdminPassword password -iLOAccountCSV .\gen9sy4.0.csv

* Example 2
To create an user on a HPE ProLiant/Blade Gen10 server, create a csv file as below
- gen10.csv
ServerName,Username,Password,Privileges
"ILOCZ273001F0",hptest3,password,All

Per Gen10 da OneView310 (-OVApplianceIP 192.168.0.100 -OVAdminName Administrator -OVAdminPassword password)
.\ilo-adduser.ps1
