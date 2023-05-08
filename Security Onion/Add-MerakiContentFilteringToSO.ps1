<#
.Description
Collect all Content filtering blocks in the Meraki network and add it to Custom SO/Elastic Index
#>

Start-Transcript c:\scripts\add-contentfilteringtoso.txt
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
##### SO Login ####
$Bytes = [System.Text.Encoding]::ASCII.GetBytes("username:apikey")
$EncodedText =[Convert]::ToBase64String($Bytes)
#$EncodedText
$header = @{
Authorization = "Basic $EncodedText"
}

$merakiHeader = @{

    "X-Cisco-Meraki-API-Key" = "key"

}

$merakiorgID = "orgid"


################ last run ###############
$lastRunPath = "c:\scripts\add-contentfilteringtosolastrun.txt"
#$lastRunNewUserPath = "c:\scripts\newuseraccountsazure.txt"

$scriptStartTime = (get-date)

Get-Content $lastRunPath


if ((get-date (Get-Content $lastRunPath)) -lt ((Get-Date).AddHours(-.5))){

#This should catch up on things if there's a power outage. ie the last run time is set at the bottom and if it's over 1 hour it will use the time set in the file.

$lastRun = (get-date (Get-Content $lastRunPath)).ToUniversalTime()

}

else{

$lastRun = ((Get-Date).AddHours(-.5)).ToUniversalTime()

}



#$request = Invoke-WebRequest -Uri https://api.meraki.com/api/v1 -Headers $merakiHeader

$merakiNetworksRequest = Invoke-WebRequest -Uri https://api.meraki.com/api/v1/organizations/$merakiorgID/networks -Headers $merakiHeader -UseBasicParsing

$merakiAppliances = (($merakiNetworksRequest.Content | ConvertFrom-Json) | Where-Object {$_.producttypes -eq "appliance" -and $_.producttypes.count -eq 1})
$date = (get-date $lastRun).ToUniversalTime()
#$date  = (get-date).AddMonths(-1).ToUniversalTime()
$year = $date.Year
$day = (get-date $date -Format dd)
$month = (get-date $date -Format MM)
$hour = (get-date $date -Format HH)
$minutes = (get-date $date -Format mm)
$seconds = (get-date $date -Format ss)
<#
$date2 = (get-date $endRun).ToUniversalTime()
#$date  = (get-date).AddMonths(-1).ToUniversalTime()
$year2 = $date.Year
$day2 = (get-date $date2 -Format dd)
$month2 = (get-date $date2 -Format MM)
$hour2 = (get-date $date2 -Format HH)
$minutes2 = (get-date $date2 -Format mm)
$seconds2 = (get-date $date2 -Format ss)

#>

#$uplinks = Invoke-WebRequest -Uri https://api.meraki.com/api/v1/organizations/$merakiorgID/devices/uplinks/addresses/byDevice -Headers $merakiHeader 
foreach ($appliance in $merakiAppliances){

    $networkEvents = Invoke-WebRequest -Uri "https://api.meraki.com/api/v1/networks/$($appliance.id)/events?productType=appliance&includedEventTypes[]=sf_url_block&includedEventTypes[]=cf_block&startingAfter=$year-$month-$day`T$hour`:$minutes`:$seconds`.000000Z" -Headers $merakiHeader -UseBasicParsing
    #&endingBefore=$year2-$month2-$day2`T$hour2`:$minutes2`:$seconds2`.000000Z
    $events = ($networkEvents.Content | ConvertFrom-Json).events
foreach ($event in $events){

if ($($event.eventData.categories)){

$categories = $($event.eventData.categories)

}else{

$categories = $($event.eventData.category)

}


$eventbody = @"
{
"`@timestamp": "$($event.occurredAt)",
"occurredAt"        : "$($event.occurredAt)",
"networkId"         : "$($event.networkId)",
"type"              : "$($event.type)",
"description"       : "$($event.description)",
"clientId"          : "$($event.clientId)",
"clientDescription" : "$($event.clientDescription)",
"clientMac"         : "$($event.clientMac)",
"deviceSerial"      : "$($event.deviceSerial)",
"deviceName"        : "$($event.deviceName)",
"eventData"         : "$($event.eventData)",
"url" : "$($event.eventData.url)",
"server" : "$($event.eventData.server)",
"categories": "$categories",
"networkName" : "$($appliance.name)"
 }
"@

$eventBody |ft
Invoke-RestMethod -Uri "https://$ip:9200/contentfiltering/_doc/" -Headers $header -Method Post -Body $eventbody -ContentType application/json -Verbose
}
}





    if ((Test-Path $lastRunPath )){

    Remove-Item $lastRunPath -Force


    }

    if (!(Test-Path $lastRunPath )){

    New-Item $lastRunPath -Force


    }



write-output "$scriptStartTime"| Add-Content $lastRunPath -Force



#create index
<#
$mapping = "`"fields`": { 
`"keyword`": {`"type`":  `"keyword`" }}"
$indexbody = @"
{
"mappings": {
 "properties": {
"occurredAt"        : { "type": "text", $mapping },
"networkId"         : { "type": "text", $mapping },
"type"              : { "type": "text", $mapping },
"description"       : { "type": "text", $mapping },
"clientId"          : { "type": "text", $mapping },
"clientDescription" : { "type": "text", $mapping },
"clientMac"         : { "type": "text", $mapping },
"deviceSerial"      : { "type": "text", $mapping },
"deviceName"        : { "type": "text", $mapping },
"eventData"         : { "type": "text", $mapping },
"url" :{ "type": "text", $mapping },
"server" :{ "type": "text", $mapping },
"categories":{ "type": "text", $mapping },
"networkName":{ "type": "text", $mapping }
 }
 }
}
"@



Invoke-RestMethod -Uri "https://$ip:9200/contentfiltering" -Headers $header -Method Put -Body $indexbody -ContentType "application/json"
#>


# SIG # Begin signature block
# MIIo0AYJKoZIhvcNAQcCoIIowTCCKL0CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUJJtkQrgUrUbmnJoxwITCaLHK
# nmOggiGyMIIDJzCCAg+gAwIBAgIQa066y01m+bBONwK13T0+hTANBgkqhkiG9w0B
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
# BgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUyhiS
# g0eHLthmAmcg8uoagDigj6kwDQYJKoZIhvcNAQEBBQAEggIAI0AC6MvlksMUJhfK
# 6r1ZnSl6XhUMpWTgewOzDTlW0LVEdjyJ4IOjReXHeV9g5TR01B0u2oKwy0T5eTVP
# 4kXyUnoRxb3GINbIFu12Lyxm6ZKCOJ7CmHotJ9BiWQQwKh24vIm97S70KCuEUbEy
# grMYnWMwyjF4KeTfcnkuh3yndXhBPL0Hapf8X5ubu562ZrYam0Mn1sjG8L4U5qqZ
# dl1KDsdAUtKMo14CG+G4U+/cXSoopfeLbUf5MW16FgZRqRg8XbH6pweXEFZZJL9J
# J17v3sNnSOP6dacN3aUt35YMF9O6fBWY3rMlgRXrdq6vyyTfvkHbtE3WC8iQ271R
# UVh+NGog1LkQ1nUpJZVIpDam32YQLURTNun3Xf/mUTc28IzwYvkQb1wHKGyRNgKr
# 3g9SJdkteZxkrq41avpEtjpoKt+yfVXQiyKtEP8Red8uD49ozYFO+McC98zeHCac
# X8ZUw0ORPXBO5GI/FvaQAA5vyrcWksZwgbNU/iHpoQlAjsLo21uDl6XXYEJCYXce
# 980PESTVR1cXKyLGXFTgSp77yqFsD97WXUSk/M481+2FdvEqJWAvxxkgqviemHnS
# KUWsSZvivpe7e9Pzm8rrKPsCOf3zLgS3H0XSJiTBmSY9VhCpWS+lYSwvJYyulNAu
# yMNK81HTZS1W5bhgbQPTZS3hS1uhggNsMIIDaAYJKoZIhvcNAQkGMYIDWTCCA1UC
# AQEwbzBbMQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xvYmFsU2lnbiBudi1zYTEx
# MC8GA1UEAxMoR2xvYmFsU2lnbiBUaW1lc3RhbXBpbmcgQ0EgLSBTSEEzODQgLSBH
# NAIQAUiQPcKKvKehGU0MHFe4KTALBglghkgBZQMEAgGgggE9MBgGCSqGSIb3DQEJ
# AzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTIzMDIwNzE4NDMwMVowKwYJ
# KoZIhvcNAQk0MR4wHDALBglghkgBZQMEAgGhDQYJKoZIhvcNAQELBQAwLwYJKoZI
# hvcNAQkEMSIEIFBrCK8WBvlSNaFfQ0+Vyut3o8XXn8k1kKXyyYTnvmxoMIGkBgsq
# hkiG9w0BCRACDDGBlDCBkTCBjjCBiwQUMQMOF2qkWS6rLIut6DKZ/LVYXc8wczBf
# pF0wWzELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExMTAv
# BgNVBAMTKEdsb2JhbFNpZ24gVGltZXN0YW1waW5nIENBIC0gU0hBMzg0IC0gRzQC
# EAFIkD3CirynoRlNDBxXuCkwDQYJKoZIhvcNAQELBQAEggGAIfv/aFoMAug+RoHw
# 2l9f++ageA7XAEenL574g7Z+DJE28RV8H1NQEAJnHJqeMBlMiDXw0TKWMcmMuv1c
# vOdG7q9mt3MhDyyl+lvmgSA6LG8gMbGD/inSQw76vOMD5mZ5Dsl8RPaX/UzZNEl9
# 5jQ9OdFVQcVTOiJx6TT3rcWvABmlE3LWlG9j/uLtwDP1Ko0riAWBVg2FizDGMZ+C
# uVbxM1T83Tmhcab7JC18f4iFGX5BoBwXfHFn7OUQ/lylxy9KJS8vxGZ0fqDB5FTy
# 3QIDpJOJPTHG7zTfCbSqh96JqKKK98HAtlzVP8tFQiBHyzXMp6jHL+926+aD2C7x
# pF5o6WAbMnogo+XmyMuJ62xRWwR3OvrSkMRkxbesV4Q11goWavJyMvbzzcsRBtqD
# o1BHrZCi2tVfUVvSTFgKSgPctuQiKIc+buI58MxsDzixVfMDLCr3QYa1FB25jM/7
# MNCWPUNqSSptlHF18CjGx7QKjJJf8uzMseWRCeiR6Badcgje
# SIG # End signature block
