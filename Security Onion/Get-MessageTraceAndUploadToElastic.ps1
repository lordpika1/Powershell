<#
.Description
This will pull message trace logs from O365 and upload them in to Elastic/SO for further/easier analysis. It uploads 5000 entries at a time via the bulk api that way if the script errors our for some
reason then all progress won't be lost.
#>

Start-Transcript "c:\scripts\$($MyInvocation.MyCommand.Name).log"
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
#test to see if today's index is created
#so set up
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
if (Test-Path ".\creds.txt"){
$socreds = Get-Content .\creds.txt
}else{

$socreds = Get-Content c:\scripts\creds.txt
}

##### SO Login ####
$Bytes = [System.Text.Encoding]::ASCII.GetBytes("$socreds")
$EncodedText =[Convert]::ToBase64String($Bytes)
#$EncodedText
$header = @{
Authorization = "Basic $EncodedText"
}

$curlHeader =@"
Authorization = Basic $EncodedText
"@



#find orginal script here:
#https://docs.elastic.co/integrations/microsoft_exchange_online_message_trace
# Username and Password
#$username = "USERNAME@DOMAIN.TLD"
#$password = "PASSWORD"
############## Time Stuff ########################
$scriptStartTime = (get-date)

$lastRunPath = "c:\scripts\$($MyInvocation.MyCommand.Name)_lastrun.txt"


if ((get-date (Get-Content $lastRunPath)) -lt ((Get-Date).AddHours(-2))){

#This should catch up on things if there's a power outage. ie the last run time is set at the bottom and if it's over 1 hour it will use the time set in the file.

$lastRun = (get-date (Get-Content $lastRunPath)).AddHours(-5).ToUniversalTime()

}

else{

$lastRun = (get-date (Get-Content $lastRunPath)).AddHours(12).ToUniversalTime()

}#>

Remove-Item $lastRunPath
write-output "$scriptStartTime"| Add-Content $lastRunPath -Force

$secondsDifference = [math]::Round((((get-date).ToUniversalTime()) - $lastrun).totalseconds)

Write-Host "Looking $secondsDifference in the past"

# Lookback in Hours
#$lookback = "-1"
# Page Size, should be no problem with 1k
$pageSize = "5000"
# Output of the json file

$output_location = "C:\scripts\messageTrace.json"
$output_location_bulk = "C:\scripts\messageTrace_bulk.json"


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

#check to see if this month's indexes are created.

for ($i = 1; $i -le 9;$i++){
$testresults = $null
$testresults = Invoke-RestMethod -Uri "https://$ip:9200/$indexname-$year.$month.0$i/" -Headers $header -ContentType "application/json" -TimeoutSec 10
if (!$testresults){

Write-Host "Creating Index $indexname-$year.$month.0$i"
Invoke-RestMethod -Uri "https://$ip:9200/$indexname-$year.$month.0$i/" -Headers $header -ContentType "applicaion/json" -Method Put


}
}

for ($i = 10; $i -le 31;$i++){
$testresults = $null
#Invoke-RestMethod -Uri "https://$ip:9200/$indexname-$year.$month.0$i/" -Headers $header -ContentType "applicaion/json" -Method Delete
$testresults = Invoke-RestMethod -Uri "https://$ip:9200/$indexname-$year.$month.$i/" -Headers $header -ContentType "application/json" -TimeoutSec 10
if (!$testresults){

Write-Host "Creating Index $indexname-$year.$month.0$i"
Invoke-RestMethod -Uri "https://$ip:9200/$indexname-$year.$month.$i/" -Headers $header -ContentType "applicaion/json" -Method Put


}
}


#connect to exchangeonline
$creds = New-Object System.Management.Automation.PSCredential ("username", ("password"|ConvertTo-SecureString -AsPlainText -force))
Import-Module ExchangeOnlineManagement
# -RequiredVersion 2.0.5 -Force 3>$null
Connect-ExchangeOnline -Credential ($creds) -ShowBanner:$false


#########################
##### Search Body #######
#########################

$searchBody2 = @"
    {
      "query": {
        "bool": {
          "must": [
             {
             "wildcard": {"_index": "$indexname-$year.$month*"}
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
$searchResults = Invoke-RestMethod -Uri "https://$ip:9200/$indexname-$year.$month*/_search?size=10000&scroll=1m" -Headers $header -Method post -Body $searchBody2 -ContentType "application/json" -UseBasicParsing

#hashtable for ids and recipients

$messageIDandRecipient = @{}

$searchResults.hits.hits
$scroll = $false
$scrollID = $searchResults._scroll_id
do{
foreach ($result in $searchResults.hits.hits){

#if key returns value add to it
if ($messageIDandRecipient[$result._source.MessageId]){

$messageIDandRecipient[$result._source.MessageId] += $result._source.RecipientAddress
}

#if key doesn't return value add key and value
if (!$messageIDandRecipient[$result._source.MessageId]){

$messageIDandRecipient.Add($result._source.MessageId,@($result._source.RecipientAddress))
}



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
$startDate = $lastrun
$endDate = (Get-Date).AddHours(-1).ToUniversalTime()

Write-Host "From $startDate to $endDate"

#Connect-ExchangeOnline -Credential $Credential
$paginate = 1
$page = 1

while ($paginate -eq 1)
{
    $output = @()
    $messageTrace = Get-MessageTrace -PageSize $pageSize -StartDate $startDate -EndDate $endDate -Page $page
    $page
    if (!$messageTrace)
    {
        $paginate = 0
    }
    else
    {
        $page++
        $output = $output + $messageTrace
    }




if (Test-Path $output_location)
{
    Remove-Item $output_location
}

if (Test-Path $output_location_bulk)
{
    Remove-Item $output_location_bulk
}

$count = 0
$bulkbody = ""
foreach ($event in $output)
{
$count++
Write-Progress -PercentComplete ($count/$($output.Count) *100) -Status "$count of $($output.Count)" -Activity "Activity"

    $eventConvert = $null

    $eventdate = (get-date $event.Received).ToLocalTime()
    if ($eventdate.Day -lt 10){

    $eventday = "0$(($eventdate.Day))"

    }else{

    $eventday = $eventdate.Day

    }

    if ($eventdate.Month -lt 10){

    $eventmonth = "0$(($eventdate.month))"

    }else{

    $eventmonth = $eventdate.Month

    }

    $event.StartDate = [Xml.XmlConvert]::ToString(($event.StartDate), [Xml.XmlDateTimeSerializationMode]::Utc)
    $event.EndDate = [Xml.XmlConvert]::ToString(($event.EndDate), [Xml.XmlDateTimeSerializationMode]::Utc)
    $event.Received = [Xml.XmlConvert]::ToString(($event.Received), [Xml.XmlDateTimeSerializationMode]::Utc)
    Add-Member -InputObject $event -MemberType NoteProperty -Name "source.ip" -Value $event.FromIP -Force
    $eventConvert = ($event | ConvertTo-Json -Compress)
    
    if ($messageIDandRecipient[$event.MessageId] -icontains $event.RecipientAddress){
    #prevent adding duplicate documents to the index.
    Write-Host "Skipping $($event.RecipientAddress), $($event.MessageId)"
    continue
    }
    #add timestamp field
    $eventConvert1 =  $eventConvert -replace "^{","{`"`@timestamp`": `"$($event.Received)`","
    #Add-Content $output_location $eventConvert -Encoding UTF8
    if ($eventConvert1 -ne $null){

    
    $bulkbody += "{ `"index`":{`"_index`":`"$indexname-$($eventdate.Year).$eventmonth.$eventday`"} }`n"
    #convert to utf8
    $bytes = [System.Text.Encoding]::GetEncoding(1252).GetBytes("$eventConvert1`n")
    $bulkbody += [System.Text.Encoding]::UTF8.GetString($Bytes)
    #$bulkbody += write-output "$eventConvert1`n" | Add-Content $bulkbody

    #Add-Content $output_location_bulk "{ `"index`":{`"_index`":`"$indexname-$($eventdate.Year).$eventmonth.$eventday`"} }`n" -NoNewline
    
    #Add-Content $output_location_bulk "$eventConvert1`n" -NoNewline
    }

    


    
    #Invoke-RestMethod -Uri "https://$ip:9200/$indexname-$($eventdate.Year).$eventmonth.$eventday/_doc" -Headers $header -Method Post -ContentType "application/json" -Body $eventConvert1
}


#$enc = [System.Text.Encoding]::UTF8
#$bulkbody2 = $enc.GetBytes($bulkbody)

#Add-Content $output_location_bulk "`n" -NoNewline

Write-Output "Uploading $count items"

#$bulkresults = Invoke-RestMethod -Uri "https://$ip:9200/_bulk" -Headers $header -ContentType "application/x-ndjson" -Method Post -body (((Get-Content $output_location_bulk -Raw) -replace "`r`n","`n")) -UseBasicParsing
$bulkresults = Invoke-RestMethod -Uri "https://$ip:9200/_bulk" -Headers $header -ContentType "application/x-ndjson" -Method Post -body (($bulkbody) -replace "`r`n","`n") -UseBasicParsing


$errors = $bulkresults.items.index | Where-Object {$_.result -notmatch "created"}
Write-Output "Errors"
$errors
}
#$bulk_body = Get-Content $output_location_bulk

#$details = Get-MessageTraceDetail -MessageTraceId $event.MessageTraceId -RecipientAddress $event.RecipientAddress
#([xml]$details[3].Data).root.mep
$totaltime = (get-date)-$scriptStartTime

Write-Output "This took $($totaltime.TotalMinutes) minutes to complete"
Disconnect-ExchangeOnline -Confirm:$false
