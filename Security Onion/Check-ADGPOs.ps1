<#

.Description
Check for when GPOs are created or deleted. Send an alert with details.

#>
Start-Transcript c:\scripts\check-adgpos.txt
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
$socreds = Get-Content "path"
##### SO Login ####
$Bytes = [System.Text.Encoding]::ASCII.GetBytes("$socreds")
$EncodedText =[Convert]::ToBase64String($Bytes)
#$EncodedText
$header = @{
Authorization = "Basic $EncodedText"
}


$lastRunPath = "c:\scripts\check-ADGPOslastrun.txt"



$scriptStartTime = (get-date)




if ((get-date (Get-Content $lastRunPath)) -lt ((Get-Date).AddHours(-1))){

#This should catch up on things if there's a power outage. ie the last run time is set at the bottom and if it's over 1 hour it will use the time set in the file.

$lastRun = (get-date (Get-Content $lastRunPath)).AddHours(-1).ToUniversalTime()

}

else{

$lastRun = ((Get-Date).AddHours(-12)).ToUniversalTime()

}

Remove-Item $lastRunPath
write-output "$scriptStartTime"| Add-Content $lastRunPath -Force

$secondsDifference = [math]::Round((((get-date).ToUniversalTime()) - $lastrun).totalseconds)


$year = (get-date).year

$searchBodyGPOCreate = @"
{
  "query": {
  "bool": {
  "must": [
     {
    "match_phrase": {
      "event.code": "5137"
                  }
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




$searchResults = Invoke-RestMethod -Uri "https://$ip:9200/so-beats-$year*/_search?size=10000" -Headers $header -Method post -Body $searchBodyGPOCreate -ContentType "application/json"


foreach ($result in $searchResults.hits.hits){

#need to get the guid of the new gpo. requires parsing it out.
$guid = $result._source.winlog.event_data.ObjectDN -replace "},CN=Policies,CN=System,dc=yourdomaininfo","" -replace "CN={",""

if ($result._source.update_sent -match "Yes"){
Write-Host $guid,$result._source.update_sent
continue}


Write-Host $guid

$gpoinfo = $null
$count = 0
do{

#have to do a loop while we wait for the gpo to replicate.
$gpoinfo = get-gpo -Guid $guid -ErrorAction SilentlyContinue

if ($gpoinfo -ne $null){
$body = ($gpoinfo | ConvertTo-Html -As List -Fragment) | Out-String

$body += "<br><br>Created by <b>$($result._source.user.name)</b> on $($result._source.observer.name)"
}

if ($count -gt 16){break}
$count++
Start-Sleep -Seconds 60
}while ($gpoinfo -eq $null)
Send-MailMessage -to $toemail -From "fromemail" -Subject "New GPO Created - $($gpoinfo.DisplayName)" -Body $body -BodyAsHtml  -SmtpServer "serverip"




$updatebody = @"
        {
        "doc":{
        "update_sent": "Yes"
        }
        }
"@

Invoke-WebRequest -Uri "https://$ip:9200/$($result._index)/_update/$($result._id)" -Headers $header -Method Post -Body $updatebody -ContentType application/json

}


############## GPO Deletion ############
$searchBodyGPODelete = @"
{
  "query": {
  "bool": {
  "must": [
     {
    "match_phrase": {
      "event.code": "5141"
                  }
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

#"gte": "now-$secondsDifference`s"

$searchResultsDelete = Invoke-RestMethod -Uri "https://$ip:9200/so-beats-$year*/_search?size=10000" -Headers $header -Method post -Body $searchBodyGPODelete -ContentType "application/json"


foreach ($result in $searchResultsDelete.hits.hits){

if ($result._source.winlog.event_data.ObjectDN -match "^CN=User|^CN=Machine"){
continue

}
$guid = $result._source.winlog.event_data.ObjectDN -replace "},CN=Policies,CN=System,DC=yourdomaininfo","" -replace "CN={",""

if ($result._source.update_sent -match "Yes"){
#if alert sent we be skippin!
Write-Host $guid,$result._source.update_sent
continue}

Write-Host $guid

#$gpoinfo = get-gpo -Guid $guid

$body = ($gpoinfo | ConvertTo-Html -As List -Fragment) | Out-String

$body += "
Guid: $guid
<br>
Deleted by <b>$($result._source.user.name)</b> on $($result._source.observer.name)"

Send-MailMessage -to $toemail -From "fromemail" -Subject "GPO Deleted" -Body $body -BodyAsHtml  -SmtpServer "serverip"

$updatebody = @"
        {
        "doc":{
        "update_sent": "Yes"
        }
        }
"@

Invoke-WebRequest -Uri "https://$ip:9200/$($result._index)/_update/$($result._id)" -Headers $header -Method Post -Body $updatebody -ContentType application/json

}





############## GPO Changes ############
##requires more work

$searchBodyGPOChanges = @"
{
  "query": {
  "bool": {
  "must": [
     {
    "match_phrase": {
      "event.code": 5136
                  }
     }
     ],
     "filter":[
           {
       "range":{
            "@timestamp":{
            "lte": "now",
            "gte": "now-1d"
            }
            }
            }
      ]
  }
}
}

"@

#"gte": "now-$secondsDifference`s"

$searchResultschanges = Invoke-RestMethod -Uri "https://$ip:9200/so-beats-$year*/_search?size=10000"  -Headers $header -Method post -Body $searchBodyGPOChanges -ContentType "application/json"

$body = ""

foreach ($result in $searchResultschanges.hits.hits){
$type = $null
if ($result._source.winlog.event_data.AttributeLDAPDisplayName -match "gPLink"){
continue
}

$guid = $result._source.winlog.event_data.ObjectDN -replace "},CN=Policies,CN=System,DC=yourdomaininfo","" -replace "CN={",""

if ($result._source.winlog.event_data.OperationType -match "14674"){

$type = "Value Added"

}

if ($result._source.winlog.event_data.OperationType -match "14675"){

$type = "Value Deleted"

}

Write-Host $guid,$type

$gpoinfo = get-gpo -Guid $guid

$body += ($gpoinfo | ConvertTo-Html -as Table -PostContent -Fragment) | Out-String



}

$emailbody += "

$body
Modified by <b>$($result._source.user.name)</b> on $($result._source.observer.name)"

