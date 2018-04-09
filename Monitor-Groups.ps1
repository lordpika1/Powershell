If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {   
	$arguments = "& '" + $myinvocation.mycommand.definition + "'"
	Start-Process powershell -Verb runAs -ArgumentList $arguments
	Break
}
#system time is in milliseconds. Set for 25 hours
#4728 Add user to Global security group
#4729 Remove user from Global group
#4756 Add user to Universal group
#4757 Remove user from Universal group
#4732 Add user to Domain Local group
#4733 Remove user from Domain Local group
#http://www.itguydiaries.net/2012/08/monitor-group-membership-changes-in.html
#http://www.powershellish.com/blog/2014-12-09-get-winevent-filterxpath#UnderstandingTimeValues
$allevents = (Get-WinEvent -LogName Security -FilterXPath "*[System[(EventID=4729 or EventID=4728 or EventID=4756 or EventID=4757 or EventID=4732 or EventID=4733) and TimeCreated[timediff(@SystemTime) <= 89000000]]]" -ErrorAction SilentlyContinue) | sort -Property TimeCreated
$tablegroup = $tablegroupdata = $null
foreach ($all in $allevents){

[xml]$allconvert = $all.toxml()
##### Resolve sid for Username #######
$membersid = ($allconvert.Event.EventData.Data | Where-Object {$_.Name -EQ "Membersid"}).innertext

$objSID = New-Object System.Security.Principal.SecurityIdentifier("$membersid")
$objUser = $objSID.Translate( [System.Security.Principal.NTAccount])
$username = $objUser.Value

##### Get group #####
$group = ($allconvert.Event.EventData.Data | Where-Object {$_.Name -EQ "TargetUserName"}).innertext

if ($allconvert.event.System.EventID -eq 4729){
$action = "Removed (Global)"

}
if ($allconvert.event.System.EventID -eq 4728){
$action = "Added (Global)"

}

if ($allconvert.event.System.EventID -eq 4757){
$action = "Removed (Universal)"

}
if ($allconvert.event.System.EventID -eq 4756){
$action = "Added (Universal)"

}
if ($allconvert.event.System.EventID -eq 4733){
$action = "Removed (Domain Local)"

}
if ($allconvert.event.System.EventID -eq 4732){
$action = "Added (Domain Local)"

}
$tablegroupdata += "<tr><th>$username</th><th>$action</th><th>$group</th><th>$($all.Id)<th>$($all.TimeCreated)</th></tr>"
}

$tablegroup = "<table>
                <caption> Group Modification</caption>
                <tr>
                <th>User</th>
                <th>Action</th>
                <th>Group</th>
                <th>Event ID</th>
                <th>Time</th>
                </tr>
                $tablegroupdata
                </table>"

$webpage = "<DOCTYPE html>
                <html>
                    <head>
                        <style>
                        table, td {
                        border-spacing: 5px;
                        text-align: left;
                        border: 1px solid black;
                        border-collapse: collapse;
                        padding: 5px;
                        white-space: nowrap;
                        }
                        th {
                        padding: 5px;
                        border-spacing: 5px;
                        font-size: 125%;
                        text-align: left;
                        border: 1px solid black;
                        border-collapse: collapse;
                        white-space: nowrap;
                        }
                        table td.uhoh {
                        background-color:#FF0000
                        }
                        tr:hover {background-color:#FFFF99}
                        </style>
                    </head>
                <body>
                $tablegroup
                </body>
</html>"


if ($tablegroupdata -ne $null){
Send-MailMessage -SmtpServer "servername" -To "email" -Port "port" -From "email" -Subject "AD Group Account Management $env:COMPUTERNAME" -bodyashtml "$webpage"
}

