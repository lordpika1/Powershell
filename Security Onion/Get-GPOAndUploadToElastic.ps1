<#
.Description
This is just to keep track of GPO GUIDs and their common name and modifications times to start with.
#>

Start-Transcript "c:\scripts\$($MyInvocation.MyCommand.Name).log"

Import-Module GroupPolicy

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

$url = "https://$ip:9200/$index/"

#create index
$testresults = Invoke-RestMethod -Uri $url -Headers $header -ContentType "applicaion/json" 
if (!$testresults){
Invoke-RestMethod -Uri $url -Headers $header -ContentType "applicaion/json" -Method Put

$mapping = "`"fields`": { 
`"keyword`": {`"type`":  `"keyword`" }}"
$indexbody = @"
{
"mappings": {
 "properties": {
"ModificationTime"        : { "type": "date", $mapping },
"CreationTime"        : { "type": "date", $mapping }
 }
 }
}
"@



Invoke-RestMethod -Uri $url -Headers $header -Method Put -Body $indexbody -ContentType "application/json"
}

$searchBody2 = @"
{
    "query": {
        "match_all": {}
    }
}
"@

$scroll = $false

Write-Host "URL: $url`_search?size=10000&scroll=1m"
$searchResults = Invoke-RestMethod -Uri "$url`_search?size=10000&scroll=1m" -Headers $header -Method post -Body $searchBody2 -ContentType "application/json" -UseBasicParsing

#get all the gpos
$gpos = Get-GPO -All




$searchResults.hits.hits.count
$scroll = $false
$scrollID = $searchResults._scroll_id

#create hash tables for gpos already in elastic
$elasticGPO = @{}
$elasticGPOModification = @{}
$elasticGPOandDocID = @{}
foreach ($result in $searchResults.hits.hits){

if ($result._source.id -eq $null){continue}
$elasticGPO.Add($result._source.Id,$result._source.DisplayName)
$elasticGPOModification.Add($result._source.Id,$result._source.ModificationTime)
$elasticGPOandDocID.Add($result._source.Id,$result._id)

<#
if (!$gpoGUIDandName[$result.source.id]){

#$searchResults = Invoke-RestMethod -Uri "$url`_doc" -Headers $header -Method post -Body $result -ContentType "application/json" -UseBasicParsing

}#>

}#>


$gpoGUIDandName = @{}

foreach ($gpo in $gpos){
if(!$elasticGPO[$gpo.Id.Guid]){
$gpoGUIDandName.Add($gpo.Id.Guid,$gpo.DisplayName)

#$gpo.ModificationTime = (get-date $gpo.ModificationTime -Format "yyyy-MM-ddTHH:mm:ssZ")

#add timestamp
$body = ($gpo | ConvertTo-Json) -replace "^{","{`"`@timestamp`": `"$((get-date $($gpo.ModificationTime) -Format "yyyy-MM-ddTHH:mm:ssZ"))`","
#fix modification and creation times for elastic
$body = $body -replace "`"ModificationTime`":  `"\\/Date\(.*\)\\/","`"ModificationTime`": `"$((get-date $($gpo.ModificationTime) -Format "yyyy-MM-ddTHH:mm:ssZ"))"
$body = $body -replace "`"CreationTime`":  `"\\/Date\(.*\)\\/","`"CreationTime`": `"$((get-date $($gpo.CreationTime) -Format "yyyy-MM-ddTHH:mm:ssZ"))"
$Results = Invoke-RestMethod -Uri "$url`_doc/" -Headers $header -Method post -Body $body -ContentType "application/json" -UseBasicParsing
break
}


if($elasticGPOModification[$gpo.Id.Guid] -notmatch $((get-date $($gpo.ModificationTime) -Format "yyyy-MM-ddTHH:mm:ssZ"))){

Write-Host $gpo.DisplayName
$updateModificationBody = @"
{
"doc":{
    "`@timestamp": "$((get-date $($gpo.ModificationTime) -Format "yyyy-MM-ddTHH:mm:ssZ"))",
"ModificationTime": "$((get-date $($gpo.ModificationTime) -Format "yyyy-MM-ddTHH:mm:ssZ"))"
}
}


"@
$updateModificationBody
$emailbody = ($gpo|ConvertTo-Html -As List) | Out-String
#recommend to send an email here whenever a change happens.
Invoke-RestMethod -Uri "$url`_doc/$($elasticGPOandDocID[$($gpo.id.guid)])" -Headers $header -Method Post -Body $updateModificationBody -ContentType "application/json" -UseBasicParsing

}


}


<#
Don't need this yet
do{





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

}while($scroll -eq $true)#>
# SIG # Begin signature block
# MIIo0AYJKoZIhvcNAQcCoIIowTCCKL0CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU6vFVtSuiqucPiRf6wo/AkL7w
# QAmggiGyMIIDJzCCAg+gAwIBAgIQa066y01m+bBONwK13T0+hTANBgkqhkiG9w0B
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
# BgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUXHFr
# Z1hiOFhFJoifW8XjUxAiwiMwDQYJKoZIhvcNAQEBBQAEggIAwMLc5yUb2/UNT4i0
# Go/84zkjL7XDQRHTJgd3wG5kBlIB5I5Fxa9CNZH8gOA+UR8oUg0B2bNg8JLw5Jiy
# po7CQ5q4OVbcjMC7hBCU32IP7iRaC5TXvhVwoSeRug8Bq0LzteZm8Cpr15irzTeS
# l9iDIcQxJ/OVBlXYnYoTcGH/ZRv0VWWL05LnF2mITGArBuGZV9D+UtAf6WsqRy4J
# WJgqd4QwKn8/2JdsV9J+3T0PU8+C5ub+wn+3pdySGO+oVX3SEwVQOClN9rrFddiz
# rP4IhNoMwQ8pn2Bo2fOJVakSTBJPnzkkGJQQ1Mq49gv8zq3yvZYtDbcAvV+El6r2
# d/LPmH3yiuqvSTOAXac1Isl1Cewagb8mBwxwXpdxyH9TmdrJON059K89BQ1VoRjv
# JgzacLRasn9aYZpsC2zvLxyF8IqRsYD1ZbsYc9OdDnbkgF1qt84galv8Eo8tdsLw
# Osv7EudF9IB+6ZHCoIQqkzn66vl0rP7S+58oNKjYVuWmU9a3/5cpPYEVJSRiKptm
# fTLkyjAO4WzVe3u9aWzDM6ooc+vNBndNC75ZkVvilyAVzUQbfWpORhtclZ5nZf4f
# zUqmOMuxW3eSYujEYp152GopY24YjyZb62uNlibhBvqANKE6kTD4b2ZY1VDXuAGK
# gjroeFh3dtU4hNOd7hVf5YYYVHChggNsMIIDaAYJKoZIhvcNAQkGMYIDWTCCA1UC
# AQEwbzBbMQswCQYDVQQGEwJCRTEZMBcGA1UEChMQR2xvYmFsU2lnbiBudi1zYTEx
# MC8GA1UEAxMoR2xvYmFsU2lnbiBUaW1lc3RhbXBpbmcgQ0EgLSBTSEEzODQgLSBH
# NAIQAUiQPcKKvKehGU0MHFe4KTALBglghkgBZQMEAgGgggE9MBgGCSqGSIb3DQEJ
# AzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTIzMDYxNjE4NTA1OFowKwYJ
# KoZIhvcNAQk0MR4wHDALBglghkgBZQMEAgGhDQYJKoZIhvcNAQELBQAwLwYJKoZI
# hvcNAQkEMSIEIAlBJ/AVHvlPhJ+x3wNUZefExMeRG+aaeePxthxsB3HGMIGkBgsq
# hkiG9w0BCRACDDGBlDCBkTCBjjCBiwQUMQMOF2qkWS6rLIut6DKZ/LVYXc8wczBf
# pF0wWzELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExMTAv
# BgNVBAMTKEdsb2JhbFNpZ24gVGltZXN0YW1waW5nIENBIC0gU0hBMzg0IC0gRzQC
# EAFIkD3CirynoRlNDBxXuCkwDQYJKoZIhvcNAQELBQAEggGAwEDGyqno1ssw1aKH
# UzwI1vFkgLwq68I1dnblC6Em/3Lph+suzTm9Wr93ERrGdofqiYbnX3zI+su6700H
# brq4hljdB+YZns96Iaiomzin3S/1EO90A7F3z6qYQIjbuoCtOMhr7hI45Gau6Qt/
# IJ+NAY1XrIHBqCNn5uiqixqXy5k+zDzQo7g/puo4fww4lS02quUYvzCfH20nuWd3
# MHzGtZPVTvHy3KJIPIeiH8m4nUN/opwZvY09fKkRxeR98+2DAqgtMB2/etxniKpc
# 53Su6bw2DGt1yPPhWVdHz45AqbtwdnIwMfEoG4sI2PxSoq4qHKA54vhQCnP3E2EV
# s1ewm8Y1vGXjvFgjJA6fZwsyCeuXLikXrPO8pvHWwnEYJqs9Yok3Yq/hPs0DI+Z4
# sP0U1aF+7nWAz5FNxOVtxRdaq/5V8GLfcZWB160OtB56QOh9LPH4/o+lYgYJl7na
# pV6Vn1K5ghY8UNYJkkbT37g8+UTC1pL6+yZGmQXQVfVWtDVf
# SIG # End signature block
