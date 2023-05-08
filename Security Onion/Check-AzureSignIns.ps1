<#
.Description
Check the O365 Signin events from Security Onion.
#>
Start-Transcript "c:\scripts\$($MyInvocation.MyCommand.Name).log"
add-type @”
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy2 : ICertificatePolicy {
public bool CheckValidationResult(
ServicePoint srvPoint, X509Certificate certificate,
WebRequest request, int certificateProblem) {
return true;
}
}
“@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy2
##### Change TLS proto to 1.2 #####
[System.Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if (Test-Path ".\filename.txt"){
$socreds = Get-Content .\filename.txt
}else{

$socreds = Get-Content "path"
}

##### SO Login ####
$Bytes = [System.Text.Encoding]::ASCII.GetBytes("$socreds")
$EncodedText =[Convert]::ToBase64String($Bytes)
#$EncodedText
$header = @{
Authorization = "Basic $EncodedText"
}


##### Exchange online connection #####
$creds = New-Object System.Management.Automation.PSCredential ("emailaddress", ("password"|ConvertTo-SecureString -AsPlainText -force))
Import-Module ExchangeOnlineManagement
# -RequiredVersion 2.0.5 -Force 3>$null
Connect-ExchangeOnline -Credential ($creds) -ShowBanner:$false
######################################




$ErrorActionPreference = "Continue"


###### set up geo ip lookup for outside service #####
###### This uses ipinfo.io free tier ####3
function Get-IPGeolocationIPINFO {
  Param
  (
    [string]$IPAddress
  )
  #the account is registered to casey.krolewicz@crye-leike.com 
  $request = Invoke-RestMethod -Method Get -Uri "https://ipinfo.io/$IPAddress/json?token=Tokenhere" -TimeoutSec 5
 
  [PSCustomObject]@{
    IP      = $request.ip
    City    = $request.city
    Country = $request.country
    Company  = $request.org
    State = $request.region
    Zip = $request.postal
  }
}


######### Abusive Ips ###########
$ipIOCpath = "c:\scripts\ipIOC.txt"
$ipIOCs = Get-Content $ipIOCpath
$ipIOChash = @{}
foreach ($ip in ($ipIOCs | select -Unique)){
if (!($ipIOChash["$ip"])){
$ipIOChash.Add($ip,1) *>$null
}

}

########### email ###############

$toEmail = "email address"



############# setup date info for indexes #####################
$year = (get-date).year

if ((get-date).day -lt 10){

$day = "0$((get-date).day)"

}else{

$day = (get-date).day

}

if ((get-date).month -lt 10){

$month = "0$((get-date).Month)"

}else{

$month = (get-date).Month

}



############## Time Stuff ########################
$scriptStartTime = (get-date)

$lastRunPath = "c:\scripts\Check-AzureSignIns.txt"


if ((get-date (Get-Content $lastRunPath)) -lt ((Get-Date).AddHours(-1))){

#This should catch up on things if there's a power outage. ie the last run time is set at the bottom and if it's over 1 hour it will use the time set in the file.

$lastRun = (get-date (Get-Content $lastRunPath)).AddHours(-12).ToUniversalTime()

}

else{

$lastRun = ((Get-Date).AddHours(-12)).ToUniversalTime()

}

Remove-Item $lastRunPath
write-output "$scriptStartTime"| Add-Content $lastRunPath -Force

$secondsDifference = [math]::Round((((get-date).ToUniversalTime()) - $lastrun).totalseconds)

Write-Host "Looking $secondsDifference in the past"

########################################################
############### pull meraki ip addresses ###############
########################################################

$merakiHeader = @{

    "X-Cisco-Meraki-API-Key" = "apikey"

}

$merakiorgID = "ordid"


$uplinks = Invoke-WebRequest -Uri https://api.meraki.com/api/v1/organizations/$merakiorgID/devices/uplinks/addresses/byDevice -Headers $merakiHeader -UseBasicParsing
$merakiApplianceUplinks = (($uplinks.Content | ConvertFrom-Json) | Where-Object {$_.producttype -eq "appliance"}) 

$merakiPublicIPs = $null

$ipExclusions = $null

$merakiPublicIPs = ((($merakiApplianceUplinks.uplinks).addresses) | Where-Object {($_.public).address -ne $null -and ($_.public).address -notmatch "0.0.0.0"}).public

###### create ip exclusions ######
$ipExclusionshash = @{}
foreach ($ip in $merakiPublicIPs){
if (!($ipExclusionshash["$($ip.address)"])){
$ipExclusionshash.Add("$($ip.address)",1) *>$null
}

}

$ipcount = 1
do{

$ipExclusionshash.Add("208.62.148.$ipcount",1) *>$null
$ipcount++
}while($ipcount -lt 255)



##########################
##### Sensitive Users ####
##########################

#get ad info for potential usernames
$sensitiveUsers = ((Get-ADUser -SearchBase "searchbase" -Properties "mail" -Filter * -ErrorAction SilentlyContinue).mail | sort)

$adUsernames = ((Get-ADUser -SearchBase "searchbase" -Filter * -ErrorAction SilentlyContinue)| sort).samaccountname

#remove the @domain.com incase they use a different username
$sensitiveUsers = $sensitiveUsers  -replace "@domain.com",""

#get the O365 users
$o365users = (Get-Mailbox *@domain.com).WindowsEmailAddress

#remove the @domain.com incase they use a different username
$o365users = $o365users  -replace "@domain.com",""


$sensitiveUsers += $o365users
$sensitiveUsers += $adUsernames

$sensitiveUsers = $sensitiveUsers | select -Unique

$matchSensitiveUsers = ""

foreach ($sensitiveUser in $sensitiveUsers){

$matchSensitiveUsers += "|$sensitiveUser*"

}

Write-Host "# of Sensitive Users:" $sensitiveUsers.Count
#######################################################################
###### list of cities within ~30 miles of certain locations. ###########
#######################################################################

#### Tennessee ####
$TNCityList = $null
$TNCityList = Import-Csv -Path (Get-ChildItem -Path "C:\Scripts\Cities\TN\" -Filter '*.csv').FullName
$TNCityListhash = @{}

$list = ($TNCityList | select * -Unique)
foreach ($name in $list ){

if ($name.name -eq $null){continue}
if ($name.name -eq ' '){continue}
if ($TNCityListhash["$($name.Name)"]){continue}

$TNCityListhash.Add("$($name.name.TrimEnd())",1)

}

#write-host "List of TN Cities"
#$TNCityListhash

#### Arkansas ####
$ARCityList = $null
$ARCityList = Import-Csv -Path (Get-ChildItem -Path "C:\Scripts\Cities\AR\" -Filter '*.csv').FullName
$ARCityListhash = @{}

$list = ($ARCityList | select * -Unique)
foreach ($name in $list ){

if ($name.name -eq $null){continue}
if ($name.name -eq ' '){continue}
if ($ARCityListhash["$($name.Name)"]){continue}

$ARCityListhash.Add("$($name.name.TrimEnd())",1)

}


#### Georgia ####
$GACityList = $null
$GACityList = Import-Csv -Path (Get-ChildItem -Path "C:\Scripts\Cities\GA\" -Filter '*.csv').FullName
$GACityListhash = @{}

$list = ($GACityList | select * -Unique)
foreach ($name in $list ){

if ($name.name -eq $null){continue}
if ($name.name -eq ' '){continue}
if ($GACityListhash["$($name.Name)"]){continue}

$GACityListhash.Add("$($name.name.TrimEnd())",1)

}

#########################
##### Search Body #######
#########################

$searchBody2 = @"
    {
      "query": {
        "bool": {
          "must": [
             {
             "match_phrase": {"event.action": "UserLoggedIn"}
             },
             {
             "match_phrase": {"event.dataset.keyword": "o365.audit"}
             }
          ],
     "filter":[
           {
       "range":{
            "@timestamp":{
            "lte": "now",
            "gte": "now-$secondsDifference`s"
            }
            }
            }
      ]
        }
     }
    }

"@


$scroll = $false

Write-Host "URL: https://$ip:9200/so-o365-$year`.$month*/_search?size=10000&scroll=1m"
$searchResults = Invoke-RestMethod -Uri "https://$ip:9200/so-o365-$year`.$month*/_search?size=10000&scroll=1m" -Headers $header -Method post -Body $searchBody2 -ContentType "application/json" -UseBasicParsing

write-host "
###############################
Total Hits: $($searchResults.hits.total.value)
###############################
"
$scrollID = $searchResults._scroll_id
do{



#####################################################
##### process foreign stuff first - easy peasy ######
#####################################################

foreach ($result in $searchResults.hits.hits){

if ($result._source.update_sent -match "Yes"){
#if alert sent we be skippin!
Write-Host "### Alert already sent ###" $result._source.user.id, $result._source.update_sent, $result._source.source.geo.city_name, $result._source.source.geo.region_name
continue
}




if ($result._source.source.geo.country_name -match "United States|Puerto Rico"){continue}

######## if state and city are empty lets get some info from the ipinfo.io index ########

if ($($result._source.source.geo.city_name) -eq $null -or ($($result._source.source.geo.city_name) -imatch "Louisville|St. Louis")){
#$elasticIP = Get-GeoIPElastic -IP $($result._source.client.ip)
$ipGeo = Get-IPGeolocationIPINFO -IPAddress $($result._source.client.ip)

#map ipgeo to doc values.
if (!$($result._source.source.geo.city_name) -or !$($result._source.source.geo.region_name)){
#New-ItemProperty -Path $result._source.source.geo -Value $ipGeo.City -Name "city_name"

Add-Member -InputObject $result._source.source.geo -Name "city_name" -MemberType NoteProperty -Value $ipGeo.City -Verbose
Add-Member -InputObject $result._source.source.geo -Name "region_name" -MemberType NoteProperty -Value $ipGeo.State -Verbose
Add-Member -InputObject $result._source.source.as -Name "organization.name" -MemberType NoteProperty -Value $ipGeo.Company -Verbose
}
$result._source.source.geo.country_name = $ipGeo.Country
$result._source.source.geo.city_name = $ipGeo.City
$result._source.source.geo.region_name = $ipGeo.State
$result._source.source.as.organization.name = $ipGeo.Company

}


if ($result._source.source.geo.country_name -eq $null){continue}


Write-Host $result._source.user.id + "--" $result._source.source.geo.city_name + "--" $result._source.source.geo.region_name + "--" $result._source.source.geo.country_name

$geobody = $($result._source.source.geo | ConvertTo-Html -Fragment -As List)

$eventTime = (get-date $result._source.'@timestamp').ToLocalTime()

$emailbody = @"


User ID: $($result._source.user.id)<br>
Event Time: $eventTime<br>
IP Address: $($result._source.client.ip)<br>
ISP: $($result._source.source.as.organization.name)<br>
City: $($result._source.source.geo.city_name)<br>
Region/State: $($result._source.source.geo.region_name)<br>
Country: $($result._source.source.geo.country_name)<br>



"@


Send-MailMessage -To $toemail -From "frommail" -Subject "Sign In - Foreign Country - $($result._source.user.id)" -Body $emailbody -SmtpServer "serverip" -BodyAsHtml


$updatebody = @"
        {
        "doc":{
        "update_sent": "Yes"
        }
        }
"@

Invoke-WebRequest -Uri "https://$ip:9200/$($result._index)/_update/$($result._id)" -Headers $header -Method Post -Body $updatebody -ContentType application/json -UseBasicParsing

}






#####################################################
##### the other stuff ######
#####################################################


foreach ($result in $searchResults.hits.hits){

if ($result._source.update_sent -match "Yes"){
#if alert sent we be skippin!
Write-Host "###" $result._source.user.id ,$result._source.update_sent
continue
}


###############################################################
##### Our special buddies that we know are just corrupt af ####
###############################################################

if ($($result._source.source.as.organization.name) -imatch "leaseweb*"){
#Cellco-part is Cellco Partnership DBA Verizon Wireless
Write-Output "$($result._source.user.id) - Not an approved ISP - $($result._source.source.as.organization.name) - $($result._source.client.ip)"
$eventTime = (get-date $result._source.'@timestamp').ToLocalTime()

$emailbody = @"


User ID: $($result._source.user.id)<br>
Event Time: $eventTime<br>
IP Address: $($result._source.client.ip)<br>
ISP: <b>$($result._source.source.as.organization.name)</b>
City: $($result._source.source.geo.city_name)<br>
Region/State: $($result._source.source.geo.region_name)<br>
Country: $($result._source.source.geo.country_name)<br>

"@


Send-MailMessage -To $toEmail -From "fromemail" -Subject "Sign In - SUS ISP - $($result._source.user.id)" -Body $emailbody -SmtpServer "serverip" -BodyAsHtml


$updatebody = @"
        {
        "doc":{
        "update_sent": "Yes"
        }
        }
"@

Invoke-WebRequest -Uri "https://$ip:9200/$($result._index)/_update/$($result._id)" -Headers $header -Method Post -Body $updatebody -ContentType application/json -UseBasicParsing

continue

}




if ($($result._source.user.id) -inotmatch "$matchSensitiveUsers"){

#can't monitor everyone

Write-Host "Skipping - $($result._source.user.id)"

continue


}#>


#Write-Host "Sensitive User - $($result._source.user.id)"

if ($ipExclusionshash[$($result._source.client.ip)] -or $ipExclusionshash["$($result._source.client.ip)"]){

Write-Output "$($result._source.user.id) - Approved IP Address - $($result._source.client.ip) - $($result._source.source.geo.city_name), $($result._source.source.geo.region_name)"

continue

}
#Write-Host $($result._source.user.id), $result._source.client.ip,$result._source.update_sent


#send email if ip is in the ioc list
if ($ipIOChash["$($result._source.client.ip)"]){

Write-Host "ipIOC Match!! -- $result._source.user.id -- $result._source.client.ip"

Send-MailMessage -SmtpServer "serverip" -Port 25 -Body "$($i.userids), $($convert.ClientIP)" -Subject "IOC IP - $($i.userids)" -To $toemail -From "fromemail"


}


######## if state and city are empty lets get some info from the ipinfo.io ########

if ($($result._source.source.geo.city_name) -eq $null -or ($($result._source.source.geo.city_name) -imatch "Louisville|St. Louis")){
#$elasticIP = Get-GeoIPElastic -IP $($result._source.client.ip)
$ipGeo = Get-IPGeolocationIPINFO -IPAddress $($result._source.client.ip)

#map ipgeo to doc values.
if (!$($result._source.source.geo.city_name) -or !$($result._source.source.geo.region_name)){
#New-ItemProperty -Path $result._source.source.geo -Value $ipGeo.City -Name "city_name"

Add-Member -InputObject $result._source.source.geo -Name "city_name" -MemberType NoteProperty -Value $ipGeo.City -Verbose
Add-Member -InputObject $result._source.source.geo -Name "region_name" -MemberType NoteProperty -Value $ipGeo.State -Verbose
Add-Member -InputObject $result._source.source.as -Name "organization.name" -MemberType NoteProperty -Value $ipGeo.Company -Verbose
}
$result._source.source.geo.country_name = $ipGeo.Country
$result._source.source.geo.city_name = $ipGeo.City
$result._source.source.geo.region_name = $ipGeo.State
$result._source.source.as.organization.name = $ipGeo.Company

}





if (($TNCityListhash["$($result._source.source.geo.city_name)"] -and $($result._source.source.geo.region_name) -imatch "tennessee") -or
(($($result._source.source.geo.city_name) -imatch "olive branch|hernando|southaven|Tupelo|brandon") -and $($result._source.source.geo.region_name) -imatch "mississippi") -or 
($GACityListhash["$($result._source.source.geo.city_name)"] -and $($result._source.source.geo.region_name) -imatch "georgia") -or 
($ARCityListhash["$($result._source.source.geo.city_name)"] -and $($result._source.source.geo.region_name) -imatch "Arkansas") -or
(($($result._source.source.geo.city_name) -imatch "Huntsville|madison|florence|athens|Decatur") -and $($result._source.source.geo.region_name) -imatch "Alabama")-or
(($($result._source.source.geo.city_name) -imatch "san juan") -and $($result._source.source.geo.region_name) -imatch "puerto rico")){
Write-Output "$($result._source.user.id) - Approved City and State - $($result._source.source.geo.city_name), $($result._source.source.geo.region_name) - $($result._source.client.ip)"

continue
}

#cell phones roam alot
if ($($result._source.source.as.organization.name) -imatch "ATT-MOBILITY-LLC|CELLCO-PART|T-MOBILE|Verizon|AT&T Mobility LLC"){
#Cellco-part is Cellco Partnership DBA Verizon Wireless
Write-Output "$($result._source.user.id) - Approved ISP - $($result._source.source.as.organization.name) - $($result._source.client.ip)"


continue
}



 #############################
##### per user exceptions #######
  #############################
#removed per user exceptions for security reasons.

Write-Host $result._source.user.id + "--" $result._source.client.ip + "--" $result._source.source.geo.city_name + "--" $result._source.source.geo.region_name + "--" $result._source.source.geo.country_name

$eventTime = (get-date $result._source.'@timestamp').ToLocalTime()

$emailbody = @"


User ID: $($result._source.user.id)<br>
Event Time: $eventTime<br>
IP Address: $($result._source.client.ip)<br>
ISP: $($result._source.source.as.organization.name)<br>
City: $($result._source.source.geo.city_name)<br>
Region/State: $($result._source.source.geo.region_name)<br>
Country: $($result._source.source.geo.country_name)<br>




"@


Send-MailMessage -to $toemail -From "fromemail" -Subject "Sign In -V2- $($result._source.user.id)" -Body $emailbody -SmtpServer "serverip" -BodyAsHtml


$updatebody = @"
        {
        "doc":{
        "update_sent": "Yes"
        }
        }
"@

Invoke-WebRequest -Uri "https://$ip:9200/$($result._index)/_update/$($result._id)" -Headers $header -Method Post -Body $updatebody -ContentType application/json -UseBasicParsing

}





if ($searchResults.hits.hits.Count -ge 10000){

$scroll = $true
$searchResults = $null

Write-Host "
########################
###### Scrolling #######
########################
"

$searchResults =  Invoke-RestMethod -Uri "https://$ip:9200/_search/scroll" -Headers $header -Method post -Body "{`"scroll_id`": `"$scrollID`"}" -ContentType "application/json" -UseBasicParsing

}else{

$scroll = $false
}

}while($scroll -eq $true)




Disconnect-ExchangeOnline -Confirm:$false



# SIG # Begin signature block
# MIIo0AYJKoZIhvcNAQcCoIIowTCCKL0CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUrrF7mM64DRg/3Wn85c49HRuW
# cTOggiGyMIIDJzCCAg+gAwIBAgIQa066y01m+bBONwK13T0+hTANBgkqhkiG9w0B
# AQ0FADAmMSQwIgYDVQQDExtjb3JwLmNyeWUtbGVpa2UuY29tIFJvb3QgQ0EwHhcN
# MTgxMjA0MjMxMTM1WhcNMjgxMjA0MjMyMTM1WjAmMSQwIgYDVQQDExtjb3JwLmNy
# eWUtbGVpa2UuY29tIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
# AoIBAQCpagW9HYtA8VXXxamY01hmJrjULKRbn0S/V6JIx58cp1NJ9glOuzUJq96B
# VGWVqOsj3sj86mxv72gn7Eem9jrPIaE/2JaexsQfddPf9iJVtvfb99Rr2lZMKX6p
# nacLgzNUTfCyGHIMgmPlEwtq9gQ4sOXcgE/i/ntI3SM7fnsvft1VIfMelK4Y1s93
# hMzDvhXPIak0Fg3bbTlBzYBtmtntPD+PhqtT8bDnb5OOAnt4ZU43pUIHgUe48q9A
# hKHbx9LlqgXRa7Sliqwoq6b/yc2XEYTUGyzxyd1VQYSDc5uBXCO/E9cvuYFs1Q+a
# wjVCdKYtTAJX+yMRCYOthO1luIoBAgMBAAGjUTBPMAsGA1UdDwQEAwIBhjAPBgNV
# HRMBAf8EBTADAQH/MB0GA1UdDgQWBBTRu7cWbuKuRWbvsM1q4i3XjnWN8jAQBgkr
# BgEEAYI3FQEEAwIBADANBgkqhkiG9w0BAQ0FAAOCAQEACrXHP6vqZndKy2KwMbWc
# YzyQfNb8rxEJr0/aI4CkFJP0bAAMW+7ycPNocqrfcmPVRRNEVvZZVf//x7iRVwT6
# fuG7psLjiHXleJ6sakg2OsCiD4nI3/f86etXKqkf/yCLjA6aLwr3g4BT7lZTMYXQ
# 0ekjzMrwCM3x7NEN5Fpmw8nzZhiY02e2bEeyYRBfkcgNY/GG8DKxDK5nDrLtEwnv
# KargK4N7R6nzuERiTQh6TVksqSD57S15d7IGL9Y1IO7sfVrd02je+5tjmdy9yxO6
# cryzSMbYKmVY+lkSZx5PibkxiIONFM8eVc5VvVwnWZbWcSQkLQBXlhC5kAs7/WUU
# izCCBO0wggPVoAMCAQICExcAAAAGCoKpmHVlwPYAAAAAAAYwDQYJKoZIhvcNAQEN
# BQAwJjEkMCIGA1UEAxMbY29ycC5jcnllLWxlaWtlLmNvbSBSb290IENBMB4XDTIz
# MDEwNDIxNTY1M1oXDTI4MDEwNDIyMDY1M1owYDETMBEGCgmSJomT8ixkARkWA2Nv
# bTEaMBgGCgmSJomT8ixkARkWCmNyeWUtbGVpa2UxFDASBgoJkiaJk/IsZAEZFgRj
# b3JwMRcwFQYDVQQDEw5TdWIgSXNzdWluZyBDQTCCASIwDQYJKoZIhvcNAQEBBQAD
# ggEPADCCAQoCggEBAM8zmaa4cDyzxNhPQ7klU5PW+DpPMpfFbtAQb2Irs5FRoOzU
# jxghOr8ma4I0D9gMkjwPcRx2S2Z5Wqwz3Zgf+YC+GHT+pwRu4Uxc/kkkI22CGBND
# ICGn0sG4UX4W9r00RVN1Gw2/tV18vRU+1TLsZ1qaHJr5OdkNOAMVy+FDLG2IwGWk
# ORM3++yaz0MbRlf3ggk62n0bsu5+V8n2DUfPX0twpyxrwmvtmpp9RtvVw6GZZpUl
# qGhzCNSLh/QWeoR89KaFgEDBuXNz60WbgSDPsCt4W1wacopDZC46H4tw/rjquRQS
# /ieJ567H0bjZiBX4EwjYvUDt9SPmnHinoEV/FrcCAwEAAaOCAdgwggHUMBAGCSsG
# AQQBgjcVAQQDAgEBMCMGCSsGAQQBgjcVAgQWBBQpPdSAyI37hqpB6kvFCQIu0mj7
# ezAdBgNVHQ4EFgQUUb57i/2C9M2zDw6CKobCNkGYZGowGQYJKwYBBAGCNxQCBAwe
# CgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0j
# BBgwFoAU0bu3Fm7irkVm77DNauIt1451jfIwgagGA1UdHwSBoDCBnTCBmqCBl6CB
# lIZDaHR0cDovL01FTS1WTS1ST09UQ0EvQ2VydEVucm9sbC9jb3JwLmNyeWUtbGVp
# a2UuY29tJTIwUm9vdCUyMENBLmNybIZNaHR0cDovL2NybC5jb3JwLmNyeWUtbGVp
# a2UuY29tL0NlcnRFbnJvbGwvY29ycC5jcnllLWxlaWtlLmNvbSUyMFJvb3QlMjBD
# QS5jcmwwdwYIKwYBBQUHAQEEazBpMGcGCCsGAQUFBzAChltodHRwOi8vY3JsLmNv
# cnAuY3J5ZS1sZWlrZS5jb20vQ2VydEVucm9sbC9NRU0tVk0tUk9PVENBX2NvcnAu
# Y3J5ZS1sZWlrZS5jb20lMjBSb290JTIwQ0EuY3J0MA0GCSqGSIb3DQEBDQUAA4IB
# AQCWzaapGI9CqiaohuMFr+MeuGYCf7gwvSWPFm78+vnB4Wmy7jVXBrseBs8PI/Z5
# DlXDoQxf/UqTQm8k1jYDmlZRASsmhycTqTkXDjXuho+nRjIr1lbP+FpNjiCaPMwP
# si9iIYFEzuJFdeazrfn7Cb/DgyN6F04UG56HgrXj5zTS2ex92QWMy2+umAKSoeFS
# Wkt73A7aRYeDwa+q0kqiOwQyMBA4xXsL3pwJc1kchviUKLWvx/8CViMcdEkfdg9W
# aHQiAHefPNms2XK6IetGq5/FSaWX2u/6bFrymesQrW16Ot8mvH9HXdFAcfXRCkeZ
# oPB8oM22GFMnJpcNBA5UT+TTMIIFgzCCA2ugAwIBAgIORea7A4Mzw4VlSOb/RVEw
# DQYJKoZIhvcNAQEMBQAwTDEgMB4GA1UECxMXR2xvYmFsU2lnbiBSb290IENBIC0g
# UjYxEzARBgNVBAoTCkdsb2JhbFNpZ24xEzARBgNVBAMTCkdsb2JhbFNpZ24wHhcN
# MTQxMjEwMDAwMDAwWhcNMzQxMjEwMDAwMDAwWjBMMSAwHgYDVQQLExdHbG9iYWxT
# aWduIFJvb3QgQ0EgLSBSNjETMBEGA1UEChMKR2xvYmFsU2lnbjETMBEGA1UEAxMK
# R2xvYmFsU2lnbjCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAJUH6HPK
# ZvnsFMp7PPcNCPG0RQssgrRIxutbPK6DuEGSMxSkb3/pKszGsIhrxbaJ0cay/xTO
# URQh7ErdG1rG1ofuTToVBu1kZguSgMpE3nOUTvOniX9PeGMIyBJQbUJmL025eShN
# UhqKGoC3GYEOfsSKvGRMIRxDaNc9PIrFsmbVkJq3MQbFvuJtMgamHvm566qjuL++
# gmNQ0PAYid/kD3n16qIfKtJwLnvnvJO7bVPiSHyMEAc4/2ayd2F+4OqMPKq0pPbz
# lUoSB239jLKJz9CgYXfIWHSw1CM69106yqLbnQneXUQtkPGBzVeS+n68UARjNN9r
# kxi+azayOeSsJDa38O+2HBNXk7besvjihbdzorg1qkXy4J02oW9UivFyVm4uiMVR
# QkQVlO6jxTiWm05OWgtH8wY2SXcwvHE35absIQh1/OZhFj931dmRl4QKbNQCTXTA
# FO39OfuD8l4UoQSwC+n+7o/hbguyCLNhZglqsQY6ZZZZwPA1/cnaKI0aEYdwgQqo
# mnUdnjqGBQCe24DWJfncBZ4nWUx2OVvq+aWh2IMP0f/fMBH5hc8zSPXKbWQULHpY
# T9NLCEnFlWQaYw55PfWzjMpYrZxCRXluDocZXFSxZba/jJvcE+kNb7gu3GduyYsR
# tYQUigAZcIN5kZeR1BonvzceMgfYFGM8KEyvAgMBAAGjYzBhMA4GA1UdDwEB/wQE
# AwIBBjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBSubAWjkxPioufi1xzWx/B/
# yGdToDAfBgNVHSMEGDAWgBSubAWjkxPioufi1xzWx/B/yGdToDANBgkqhkiG9w0B
# AQwFAAOCAgEAgyXt6NH9lVLNnsAEoJFp5lzQhN7craJP6Ed41mWYqVuoPId8AorR
# brcWc+ZfwFSY1XS+wc3iEZGtIxg93eFyRJa0lV7Ae46ZeBZDE1ZXs6KzO7V33EBy
# rKPrmzU+sQghoefEQzd5Mr6155wsTLxDKZmOMNOsIeDjHfrYBzN2VAAiKrlNIC5w
# aNrlU/yDXNOd8v9EDERm8tLjvUYAGm0CuiVdjaExUd1URhxN25mW7xocBFymFe94
# 4Hn+Xds+qkxV/ZoVqW/hpvvfcDDpw+5CRu3CkwWJ+n1jez/QcYF8AOiYrg54NMMl
# +68KnyBr3TsTjxKM4kEaSHpzoHdpx7Zcf4LIHv5YGygrqGytXm3ABdJ7t+uA/iU3
# /gKbaKxCXcPu9czc8FB10jZpnOZ7BN9uBmm23goJSFmH63sUYHpkqmlD75HHTOwY
# 3WzvUy2MmeFe8nI+z1TIvWfspA9MRf/TuTAjB0yPEL+GltmZWrSZVxykzLsViVO6
# LAUP5MSeGbEYNNVMnbrt9x+vJJUEeKgDu+6B5dpffItKoZB0JaezPkvILFa9x8jv
# OOJckvB595yEunQtYQEgfn7R8k8HWV+LLUNS60YMlOH1Zkd5d9VUWx+tJDfLRVpO
# oERIyNiwmcUVhAn21klJwGW45hpxbqCo8YLoRT5s1gLXCmeDBVrJpBAwggZZMIIE
# QaADAgECAg0B7BySQN79LkBdfEd0MA0GCSqGSIb3DQEBDAUAMEwxIDAeBgNVBAsT
# F0dsb2JhbFNpZ24gUm9vdCBDQSAtIFI2MRMwEQYDVQQKEwpHbG9iYWxTaWduMRMw
# EQYDVQQDEwpHbG9iYWxTaWduMB4XDTE4MDYyMDAwMDAwMFoXDTM0MTIxMDAwMDAw
# MFowWzELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExMTAv
# BgNVBAMTKEdsb2JhbFNpZ24gVGltZXN0YW1waW5nIENBIC0gU0hBMzg0IC0gRzQw
# ggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDwAuIwI/rgG+GadLOvdYNf
# qUdSx2E6Y3w5I3ltdPwx5HQSGZb6zidiW64HiifuV6PENe2zNMeswwzrgGZt0ShK
# wSy7uXDycq6M95laXXauv0SofEEkjo+6xU//NkGrpy39eE5DiP6TGRfZ7jHPvIo7
# bmrEiPDul/bc8xigS5kcDoenJuGIyaDlmeKe9JxMP11b7Lbv0mXPRQtUPbFUUweL
# mW64VJmKqDGSO/J6ffwOWN+BauGwbB5lgirUIceU/kKWO/ELsX9/RpgOhz16ZevR
# VqkuvftYPbWF+lOZTVt07XJLog2CNxkM0KvqWsHvD9WZuT/0TzXxnA/TNxNS2SU0
# 7Zbv+GfqCL6PSXr/kLHU9ykV1/kNXdaHQx50xHAotIB7vSqbu4ThDqxvDbm19m1W
# /oodCT4kDmcmx/yyDaCUsLKUzHvmZ/6mWLLU2EESwVX9bpHFu7FMCEue1EIGbxsY
# 1TbqZK7O/fUF5uJm0A4FIayxEQYjGeT7BTRE6giunUlnEYuC5a1ahqdm/TMDAd6Z
# JflxbumcXQJMYDzPAo8B/XLukvGnEt5CEk3sqSbldwKsDlcMCdFhniaI/MiyTdtk
# 8EWfusE/VKPYdgKVbGqNyiJc9gwE4yn6S7Ac0zd0hNkdZqs0c48efXxeltY9GbCX
# 6oxQkW2vV4Z+EDcdaxoU3wIDAQABo4IBKTCCASUwDgYDVR0PAQH/BAQDAgGGMBIG
# A1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYEFOoWxmnn48tXRTkzpPBAvtDDvWWW
# MB8GA1UdIwQYMBaAFK5sBaOTE+Ki5+LXHNbH8H/IZ1OgMD4GCCsGAQUFBwEBBDIw
# MDAuBggrBgEFBQcwAYYiaHR0cDovL29jc3AyLmdsb2JhbHNpZ24uY29tL3Jvb3Ry
# NjA2BgNVHR8ELzAtMCugKaAnhiVodHRwOi8vY3JsLmdsb2JhbHNpZ24uY29tL3Jv
# b3QtcjYuY3JsMEcGA1UdIARAMD4wPAYEVR0gADA0MDIGCCsGAQUFBwIBFiZodHRw
# czovL3d3dy5nbG9iYWxzaWduLmNvbS9yZXBvc2l0b3J5LzANBgkqhkiG9w0BAQwF
# AAOCAgEAf+KI2VdnK0JfgacJC7rEuygYVtZMv9sbB3DG+wsJrQA6YDMfOcYWaxlA
# SSUIHuSb99akDY8elvKGohfeQb9P4byrze7AI4zGhf5LFST5GETsH8KkrNCyz+zC
# VmUdvX/23oLIt59h07VGSJiXAmd6FpVK22LG0LMCzDRIRVXd7OlKn14U7XIQcXZw
# 0g+W8+o3V5SRGK/cjZk4GVjCqaF+om4VJuq0+X8q5+dIZGkv0pqhcvb3JEt0Wn1y
# hjWzAlcfi5z8u6xM3vreU0yD/RKxtklVT3WdrG9KyC5qucqIwxIwTrIIc59eodaZ
# zul9S5YszBZrGM3kWTeGCSziRdayzW6CdaXajR63Wy+ILj198fKRMAWcznt8oMWs
# r1EG8BHHHTDFUVZg6HyVPSLj1QokUyeXgPpIiScseeI85Zse46qEgok+wEr1If5i
# EO0dMPz2zOpIJ3yLdUJ/a8vzpWuVHwRYNAqJ7YJQ5NF7qMnmvkiqK1XZjbclIA4b
# UaDUY6qD6mxyYUrJ+kPExlfFnbY8sIuwuRwx773vFNgUQGwgHcIt6AvGjW2MtnHt
# UiH+PvafnzkarqzSL3ogsfSsqh3iLRSd+pZqHcY8yvPZHL9TTaRHWXyVxENB+SXi
# LBB+gfkNlKd98rUJ9dhgckBQlSDUQ0S++qCV5yBZtnjGpGqqIpswggZoMIIEUKAD
# AgECAhABSJA9woq8p6EZTQwcV7gpMA0GCSqGSIb3DQEBCwUAMFsxCzAJBgNVBAYT
# AkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMTEwLwYDVQQDEyhHbG9iYWxT
# aWduIFRpbWVzdGFtcGluZyBDQSAtIFNIQTM4NCAtIEc0MB4XDTIyMDQwNjA3NDE1
# OFoXDTMzMDUwODA3NDE1OFowYzELMAkGA1UEBhMCQkUxGTAXBgNVBAoMEEdsb2Jh
# bFNpZ24gbnYtc2ExOTA3BgNVBAMMMEdsb2JhbHNpZ24gVFNBIGZvciBNUyBBdXRo
# ZW50aWNvZGUgQWR2YW5jZWQgLSBHNDCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCC
# AYoCggGBAMLJ3AO2G1D6Kg3onKQh2yinHfWAtRJ0I/5eL8MaXZayIBkZUF92IyY1
# xiHslO+1ojrFkIGbIe8LJ6TjF2Q72pPUVi8811j5bazAL5B4I0nA+MGPcBPUa98m
# iFp2e0j34aSm7wsa8yVUD4CeIxISE9Gw9wLjKw3/QD4AQkPeGu9M9Iep8p480Abn
# 4mPS60xb3V1YlNPlpTkoqgdediMw/Px/mA3FZW0b1XRFOkawohZ13qLCKnB8tna8
# 2Ruuul2c9oeVzqqo4rWjsZNuQKWbEIh2Fk40ofye8eEaVNHIJFeUdq3Cx+yjo5Z1
# 4sYoawIF6Eu5teBSK3gBjCoxLEzoBeVvnw+EJi5obPrLTRl8GMH/ahqpy76jdfjp
# yBiyzN0vQUAgHM+ICxfJsIpDy+Jrk1HxEb5CvPhR8toAAr4IGCgFJ8TcO113KR4Z
# 1EEqZn20UnNcQqWQ043Fo6o3znMBlCQZQkPRlI9Lft3LbbwbTnv5qgsiS0mASXAb
# LU/eNGA+vQIDAQABo4IBnjCCAZowDgYDVR0PAQH/BAQDAgeAMBYGA1UdJQEB/wQM
# MAoGCCsGAQUFBwMIMB0GA1UdDgQWBBRba3v0cHQIwQ0qyO/xxLlA0krG/TBMBgNV
# HSAERTBDMEEGCSsGAQQBoDIBHjA0MDIGCCsGAQUFBwIBFiZodHRwczovL3d3dy5n
# bG9iYWxzaWduLmNvbS9yZXBvc2l0b3J5LzAMBgNVHRMBAf8EAjAAMIGQBggrBgEF
# BQcBAQSBgzCBgDA5BggrBgEFBQcwAYYtaHR0cDovL29jc3AuZ2xvYmFsc2lnbi5j
# b20vY2EvZ3N0c2FjYXNoYTM4NGc0MEMGCCsGAQUFBzAChjdodHRwOi8vc2VjdXJl
# Lmdsb2JhbHNpZ24uY29tL2NhY2VydC9nc3RzYWNhc2hhMzg0ZzQuY3J0MB8GA1Ud
# IwQYMBaAFOoWxmnn48tXRTkzpPBAvtDDvWWWMEEGA1UdHwQ6MDgwNqA0oDKGMGh0
# dHA6Ly9jcmwuZ2xvYmFsc2lnbi5jb20vY2EvZ3N0c2FjYXNoYTM4NGc0LmNybDAN
# BgkqhkiG9w0BAQsFAAOCAgEALms+j3+wsGDZ8Z2E3JW2318NvyRR4xoGqlUEy2HB
# 72Vxrgv9lCRXAMfk9gy8GJV9LxlqYDOmvtAIVVYEtuP+HrvlEHZUO6tcIV4qNU1G
# y6ZMugRAYGAs29P2nd7KMhAMeLC7VsUHS3C8pw+rcryNy+vuwUxr2fqYoXQ+6ajI
# eXx2d0j9z+PwDcHpw5LgBwwTLz9rfzXZ1bfub3xYwPE/DBmyAqNJTJwEw/C0l6fg
# TWolujQWYmbIeLxpc6pfcqI1WB4m678yFKoSeuv0lmt/cqzqpzkIMwE2PmEkfhGd
# ER52IlTjQLsuhgx2nmnSxBw9oguMiAQDVN7pGxf+LCue2dZbIjj8ZECGzRd/4amf
# ub+SQahvJmr0DyiwQJGQL062dlC8TSPZf09rkymnbOfQMD6pkx/CUCs5xbL4TSck
# 0f122L75k/SpVArVdljRPJ7qGugkxPs28S9Z05LD7MtgUh4cRiUI/37Zk64UlaiG
# igcuVItzTDcVOFBWh/FPrhyPyaFsLwv8uxxvLb2qtutoI/DtlCcUY8us9GeKLIHT
# FBIYAT+Eeq7sR2A/aFiZyUrCoZkVBcKt3qLv16dVfLyEG02Uu45KhUTZgT2qoyVV
# X6RrzTZsAPn/ct5a7P/JoEGWGkBqhZEcr3VjqMtaM7WUM36yjQ9zvof8rzpzH3sg
# 23IwggdCMIIGKqADAgECAhMQAAABYdY+zmjrwyBcAAAAAAFhMA0GCSqGSIb3DQEB
# DQUAMGAxEzARBgoJkiaJk/IsZAEZFgNjb20xGjAYBgoJkiaJk/IsZAEZFgpjcnll
# LWxlaWtlMRQwEgYKCZImiZPyLGQBGRYEY29ycDEXMBUGA1UEAxMOU3ViIElzc3Vp
# bmcgQ0EwHhcNMjMwMTA0MjEwNjQzWhcNMjMxMjA2MjMwNjE4WjCBvjETMBEGCgmS
# JomT8ixkARkWA2NvbTEaMBgGCgmSJomT8ixkARkWCmNyeWUtbGVpa2UxFDASBgoJ
# kiaJk/IsZAEZFgRjb3JwMRIwEAYDVQQLEwlXaW5kb3dzMTAxCzAJBgNVBAsTAklU
# MRIwEAYDVQQLEwlOYXNodmlsbGUxEzARBgNVBAsTClN1cHBvcnQuQUQxDjAMBgNV
# BAsTBVVzZXJzMRswGQYDVQQDExJDYXNleSBLcm9sZXdpY3ogQUQwggIiMA0GCSqG
# SIb3DQEBAQUAA4ICDwAwggIKAoICAQDojjmDp8M3GqoOG8sqeUwB9fV8DyZXtgcX
# BcfCriVQwwSK4JNa9ZUXPSfm0T6/7UEA0dJD55SR6PdbzSEDmOWNrybgePyY/44j
# 19vb7bentXgC9i498u/76aYjJGlvBGYzF0B+z3YCH70EvbUn+uBvBHcStaSsCJtP
# cY2KYiXZo+GehCzTNeUp8rm1R7smzzQspTaONMyyLId8Vukum2U5pTTkoecXoVP5
# O7xC11ndcS57MAxXnh0anJO56p+LDwYPITCrb284KAuXx51ezYOtG4wVWWQZiu2Q
# 1soOpLftMzjqRut3KM20DRliYlMVTKTuo4utu9blX3Y2D9HRe8ucK9MoU0SXz2CE
# bZxHZDgESbULWfhd7hJSWySaDGDzHD/hzp0rfhskl6rxBa9/HTKlhMkUKKL865NK
# gfdty2VjbLRKFgrrgWVRtuNz+/Cs6fCMzdrrhwOLXxWBfWCtnmtEcMYtmyYD1DRJ
# TQ1yFqp3u0PbbxB6uKg5iq67UM0RVstZFgGoaPcTK752SFmlZoDmw5ji28qIOEfl
# WM4GPwclQGfWEed5x7+9Yf0If8x601areofCL7sDsdy6iSuuaI8pK46QvoG229jM
# G3/DlPnImubO+ga6e68hcDM9FGeX6tcfphS4BPBZALqil5LUhkGg5zEFylfPcxaY
# KLKMKjoW1QIDAQABo4IClDCCApAwPgYJKwYBBAGCNxUHBDEwLwYnKwYBBAGCNxUI
# hMfacoL+mSCDyY81gobwI4HV2CGBMIHy+iWCrtlgAgFkAgEOMBMGA1UdJQQMMAoG
# CCsGAQUFBwMDMA4GA1UdDwEB/wQEAwIHgDAbBgkrBgEEAYI3FQoEDjAMMAoGCCsG
# AQUFBwMDMB0GA1UdDgQWBBTWdQGYzbT913c42zeW/wa6Li2DxTAfBgNVHSMEGDAW
# gBRRvnuL/YL0zbMPDoIqhsI2QZhkajCCAUAGCCsGAQUFBwEBBIIBMjCCAS4wgbwG
# CCsGAQUFBzAChoGvbGRhcDovLy9DTj1TdWIlMjBJc3N1aW5nJTIwQ0EsQ049QUlB
# LENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2VzLENOPUNvbmZp
# Z3VyYXRpb24sREM9Y29ycCxEQz1jcnllLWxlaWtlLERDPWNvbT9jQUNlcnRpZmlj
# YXRlP2Jhc2U/b2JqZWN0Q2xhc3M9Y2VydGlmaWNhdGlvbkF1dGhvcml0eTBtBggr
# BgEFBQcwAoZhaHR0cDovL2NybC5jb3JwLmNyeWUtbGVpa2UuY29tL0NlcnRFbnJv
# bGwvTUVNLVZNLVNVQkNBLmNvcnAuY3J5ZS1sZWlrZS5jb21fU3ViJTIwSXNzdWlu
# ZyUyMENBLmNydDA5BgNVHREEMjAwoC4GCisGAQQBgjcUAgOgIAweY2tyb2xld2lj
# ekBjb3JwLmNyeWUtbGVpa2UuY29tME0GCSsGAQQBgjcZAgRAMD6gPAYKKwYBBAGC
# NxkCAaAuBCxTLTEtNS0yMS02OTg2ODY2NzAtNjY4NDI2MTU1LTIxNDI5MzExMDUt
# OTAyMDANBgkqhkiG9w0BAQ0FAAOCAQEAbVcUKIjbQMiX1l94frzJVOaPussD955C
# yUbDHIbDyCz2RWO4olQg8YlLcp9KxfUrtiRSqn7cxZp++uOG1uigIBLJK/4sL6cw
# 5x+OzvqR5GB5t7FMLyZ4DepTCpo4M2k4dztZU/4YF8E18/mcay2Fj7Bb+ErkM0+W
# +3iMxDfpD5VJuWYsBJUR3p+2skR0BlqYpjcp4xvDqVwz0gk2EdvJLP3HsxT0Ue65
# ZHPf3tp5zrs6v7Vh75iBnXY9UmfJ5fy/NXhxheb/ZHWfoRcM+/sA5v80jeMGFSFB
# s8EyM5FX9cBNWarNvqJYgWd7i2YWG8oE9+GeYzqYk/lhFTdIp4eXCDGCBogwggaE
# AgEBMHcwYDETMBEGCgmSJomT8ixkARkWA2NvbTEaMBgGCgmSJomT8ixkARkWCmNy
# eWUtbGVpa2UxFDASBgoJkiaJk/IsZAEZFgRjb3JwMRcwFQYDVQQDEw5TdWIgSXNz
# dWluZyBDQQITEAAAAWHWPs5o68MgXAAAAAABYTAJBgUrDgMCGgUAoHgwGAYKKwYB
# BAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAc
# BgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUxB07
# QSzMUF7zRtlD+JVE+j7UPt0wDQYJKoZIhvcNAQEBBQAEggIAH/9pg0hLycyNEL99
# zbrc2A2J+kY3Zr2xtNVrRTr5WubyzKD+Npi4Z/8nSmY1KJYRb3oS5tj0PTF4bRLP
# pedv/geyxWApoKm1TOaGNQQ5eTJlBQYAq551qzDsvEDXpofMfMDJZP1lkclA9aN7
# P3Jdtp5LXWHK+vOr94OkKaj9MRq5VXRoCn0SgkP3WPFmQOEbE36nMoDbuHuIhFE1
# kj8RiWiqrScqMU9VnHSg36TuR0BwEUAvSISzbdEMHolmat03GvePqske83IYUSf1
# pFUmplYQL/PHFl0ooWPyU1TIOclwQhiVFzygp9Szstc383NXe2raqYI1pecLcxIi
# vxS1nm8qOy/o6XCnyZcxOchag0BxTsRZy56+grH7mf+eSPT6LAp0ILoINoB83J/k
# m0Y516wFgvuAgYdXcLm22VX9cJHeLdWWSN6u6wbYMXEWTcVB738sK3skyRkqDkYR
# 42K2lZ6TZvhnfzGlNtgSt2YEAqOJlQWDRCqZ7Dd+C33TVJMLrYUoTJMcdyVs+adP
# vkZhg16DFdsh/HmhGdqAbRuuoU9B3f0+L17nl0bJPPlSjw2O0Mmzyqpuh1BIBVIN
# LQSaslnbDpIVV0Z4O/Bj9omeDtjiC0RPRr8dcytnLERH5ZoiujLuToCfy+3nf1ig
# PJv21j/ZUOcIEF2RdO0CQR1xeqGhggNsMIIDaAYJKoZIhvcNAQkGMYIDWTCCA1UC
# AQEwbzBbMQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xvYmFsU2lnbiBudi1zYTEx
# MC8GA1UEAxMoR2xvYmFsU2lnbiBUaW1lc3RhbXBpbmcgQ0EgLSBTSEEzODQgLSBH
# NAIQAUiQPcKKvKehGU0MHFe4KTALBglghkgBZQMEAgGgggE9MBgGCSqGSIb3DQEJ
# AzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTIzMDUwNTE0NDc0NFowKwYJ
# KoZIhvcNAQk0MR4wHDALBglghkgBZQMEAgGhDQYJKoZIhvcNAQELBQAwLwYJKoZI
# hvcNAQkEMSIEIB+uAkOd8fgbtkbtw6W0+tHpqlp/kw7nqTPmBphuZyohMIGkBgsq
# hkiG9w0BCRACDDGBlDCBkTCBjjCBiwQUMQMOF2qkWS6rLIut6DKZ/LVYXc8wczBf
# pF0wWzELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExMTAv
# BgNVBAMTKEdsb2JhbFNpZ24gVGltZXN0YW1waW5nIENBIC0gU0hBMzg0IC0gRzQC
# EAFIkD3CirynoRlNDBxXuCkwDQYJKoZIhvcNAQELBQAEggGASQa1ZrDyFni9nDEP
# 45BZudd5ZlWuYg6J5lTeAav2Hf5mKN48t+h4lf4lH7YdlWRsyeg43FxgUeie6rME
# FEdXFQ6ta0XLsfGUkE7F3vE9GPL/Hw5dgGovnDrFBdupW4kcXoNOcQk0pBsDGafV
# S7omtv0pELZ84V6bEzR4mjP5Y3SNTwgofsIsfTRSXg7OuPTc/vw/A2SonqegewXr
# TsveV70zL8a++//l4kry+xUx70PUi+ePZFlILFIcTFU7U0mT0UpPmQLDNp6V/xaD
# UWmKls/YbIEBxmmdMaBD85Q83GacOJks4nvxpWZW5E6VDWL8leyBU3EsHM+oJG+9
# tE3LSeNzaialXong3W8nVx4CPQI2f0GK2ZfGhRwZZNXLn/21WgQ22quwgUFkXEx+
# 3kEDetTGhhFemOdU2w2rUbs5SgIdJ66eA25c7cEqHNQ0rtc8mYMAREIMeP8vPIz1
# zubrfMtYUgtrmHkpTXTSYRYdrChL8xpKF13wmpcg10quWDr9
# SIG # End signature block
