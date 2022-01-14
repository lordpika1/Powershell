#
# Disable and delete inactive users in AD.
#

Import-Module ActiveDirectory;

##### SETUP #####

$path = "C:\Scripts\UsersDisabled.txt";
$date = get-date;
$disableList = @("")
$deleteList = @("")
#Remove-Item $path;
Add-Content $path "`n";
Add-Content $path "`n";
Add-Content $path "#########################################"
Add-Content $path "########## $date ##########"
Add-Content $path "#########################################"
Write-Output "SamAccountName , DistinguishedName , LastLogonTimestamp" | Add-Content $path
$timespan = "80.00:00:00"


$searchusers = @(Search-ADAccount -UsersOnly -SearchBase "distinguishedname" -AccountInactive -TimeSpan $timespan -ErrorAction SilentlyContinue) + @(Search-ADAccount -UsersOnly -SearchBase "distinguishedname" -AccountInactive -TimeSpan $timespan -ErrorAction SilentlyContinue) |sort -Property Name

    foreach ($user in $searchusers){
    $getuser = Get-ADUser $user -Properties name,enabled,whencreated,lastlogontimestamp
    
    $groups = (Get-ADPrincipalGroupMembership $getuser.SamAccountName).name
    #Write-Host $getuser.SamAccountName "," $getuser.name","$getuser.enabled","$getuser.whencreated","$([datetime]::FromFileTime($getuser.lastlogontimestamp))
    
    #Write-Host $getuser.SamAccountName "," $getuser.name","$getuser.enabled","$getuser.whencreated","$([datetime]::FromFileTime($getuser.lastlogontimestamp))
    #Remove-ADUser $user -Confirm:$false
    if (($getuser.whencreated -ge (Get-Date).AddDays(-30) -and $getuser.Enabled -eq $true)){
    #Write-Host $getuser.SamAccountName
    }
    #else{Write-Host $user.SamAccountName}
        if (($getuser.whencreated -lt (Get-Date).AddDays(-30) -and $getuser.Enabled -eq $true)){
        #Write-Output "$($getuser.SamAccountName) , $($getuser.name) , $($getuser.enabled) , $($getuser.whencreated) , $([datetime]::FromFileTime($getuser.lastlogontimestamp))" | Add-Content $path
            if ($user.Enabled -eq $true){
            Set-ADUser $user -Enabled $false
            $disableList += "$($getuser.SamAccountName)____$([datetime]::FromFileTime($getuser.lastlogontimestamp))`n"
            
            Write-Output "Disabling $($getuser.SamAccountName) , $($getuser.DistinguishedName) , $([datetime]::FromFileTime($getuser.lastlogontimestamp))" | Add-Content $path
            }
            
        }

    ##################
    ##### DELETE #####
    ##################
    #only delete those that have been disabled.
    if (([datetime]::FromFileTime($getuser.lastlogontimestamp) -lt (Get-Date).AddDays(-110) -and $getuser.Enabled -eq $false) -and (!$groups.Contains("Special Group"))){
            #save me group won't delete for 1.5 years
         
        #Write-Output "$($getuser.SamAccountName) , $($getuser.name) , $($getuser.enabled) , $($getuser.whencreated) , $([datetime]::FromFileTime($getuser.lastlogontimestamp))" | Add-Content $path
           Remove-ADUser $getuser.SamAccountName -Confirm:$false
            $deleteList += "$($getuser.SamAccountName)____$([datetime]::FromFileTime($getuser.lastlogontimestamp))`n"
            
            #Write-Output "UP HERE Deleting $($getuser.SamAccountName) , $($getuser.DistinguishedName) , $([datetime]::FromFileTime($getuser.lastlogontimestamp))"
            Write-Output "Deleting $($getuser.SamAccountName) , $($getuser.DistinguishedName) , $([datetime]::FromFileTime($getuser.lastlogontimestamp))" | Add-Content $path
            
            
            
        }elseif([datetime]::FromFileTime($getuser.lastlogontimestamp) -lt (Get-Date).AddDays(-540) -and ($getuser.whencreated -lt (Get-Date).AddDays(-540))){

        #($getuser.lastlogontimestamp -ne $null)
            Remove-ADUser $getuser.SamAccountName -Confirm:$false
            $deleteList += "$($getuser.SamAccountName)____$([datetime]::FromFileTime($getuser.lastlogontimestamp))`n"
            #Write-Output "HII Deleting $($getuser.SamAccountName) , $($getuser.DistinguishedName) , $([datetime]::FromFileTime($getuser.lastlogontimestamp))"
            Write-Output "540 DAY LIMIT MET" | Add-Content $path 
            Write-Output "Deleting $($getuser.SamAccountName) , $($getuser.DistinguishedName) , $([datetime]::FromFileTime($getuser.lastlogontimestamp))" | Add-Content $path
            
            }


    }



 $disableList = $disableList |sort
 $deleteList = $deleteList | sort
 if ($disableList.count -gt 1){
 Send-MailMessage -SmtpServer ipaddress -To email@email.com -Port 25 -From email@email.com -Subject "Users Disabled $date"`
 -Body "$disableList"
 }

 if ($deleteList.count -gt 1){
 Send-MailMessage -SmtpServer ipaddress -To email@email.com -Port 25 -From email@email.com -Subject "Users Deleted $date"`
 -Body "$deleteList"
 }

# SIG # Begin signature block
# MIId2wYJKoZIhvcNAQcCoIIdzDCCHcgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUhvIOuqX+hnrTgZi1a1vTQm1s
# wlSgghgeMIIDJzCCAg+gAwIBAgIQa066y01m+bBONwK13T0+hTANBgkqhkiG9w0B
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
# izCCA+4wggNXoAMCAQICEH6T6/t8xk5Z6kuad9QG/DswDQYJKoZIhvcNAQEFBQAw
# gYsxCzAJBgNVBAYTAlpBMRUwEwYDVQQIEwxXZXN0ZXJuIENhcGUxFDASBgNVBAcT
# C0R1cmJhbnZpbGxlMQ8wDQYDVQQKEwZUaGF3dGUxHTAbBgNVBAsTFFRoYXd0ZSBD
# ZXJ0aWZpY2F0aW9uMR8wHQYDVQQDExZUaGF3dGUgVGltZXN0YW1waW5nIENBMB4X
# DTEyMTIyMTAwMDAwMFoXDTIwMTIzMDIzNTk1OVowXjELMAkGA1UEBhMCVVMxHTAb
# BgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTAwLgYDVQQDEydTeW1hbnRlYyBU
# aW1lIFN0YW1waW5nIFNlcnZpY2VzIENBIC0gRzIwggEiMA0GCSqGSIb3DQEBAQUA
# A4IBDwAwggEKAoIBAQCxrLNJVEuXHBIK2CV5kSJXKm/cuCbEQ3Nrwr8uUFr7FMJ2
# jkMBJUO0oeJF9Oi3e8N0zCLXtJQAAvdN7b+0t0Qka81fRTvRRM5DEnMXgotptCvL
# mR6schsmTXEfsTHd+1FhAlOmqvVJLAV4RaUvic7nmef+jOJXPz3GktxK+Hsz5HkK
# +/B1iEGc/8UDUZmq12yfk2mHZSmDhcJgFMTIyTsU2sCB8B8NdN6SIqvK9/t0fCfm
# 90obf6fDni2uiuqm5qonFn1h95hxEbziUKFL5V365Q6nLJ+qZSDT2JboyHylTkhE
# /xniRAeSC9dohIBdanhkRc1gRn5UwRN8xXnxycFxAgMBAAGjgfowgfcwHQYDVR0O
# BBYEFF+a9W5czMx0mtTdfe8/2+xMgC7dMDIGCCsGAQUFBwEBBCYwJDAiBggrBgEF
# BQcwAYYWaHR0cDovL29jc3AudGhhd3RlLmNvbTASBgNVHRMBAf8ECDAGAQH/AgEA
# MD8GA1UdHwQ4MDYwNKAyoDCGLmh0dHA6Ly9jcmwudGhhd3RlLmNvbS9UaGF3dGVU
# aW1lc3RhbXBpbmdDQS5jcmwwEwYDVR0lBAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/
# BAQDAgEGMCgGA1UdEQQhMB+kHTAbMRkwFwYDVQQDExBUaW1lU3RhbXAtMjA0OC0x
# MA0GCSqGSIb3DQEBBQUAA4GBAAMJm495739ZMKrvaLX64wkdu0+CBl03X6ZSnxaN
# 6hySCURu9W3rWHww6PlpjSNzCxJvR6muORH4KrGbsBrDjutZlgCtzgxNstAxpghc
# Knr84nodV0yoZRjpeUBiJZZux8c3aoMhCI5B6t3ZVz8dd0mHKhYGXqY4aiISo1EZ
# g362MIIEfTCCA2WgAwIBAgITFwAAAAS71Y6qvamh+QAAAAAABDANBgkqhkiG9w0B
# AQ0FADAmMSQwIgYDVQQDExtjb3JwLmNyeWUtbGVpa2UuY29tIFJvb3QgQ0EwHhcN
# MTgxMjA2MjI1NjE4WhcNMjMxMjA2MjMwNjE4WjBgMRMwEQYKCZImiZPyLGQBGRYD
# Y29tMRowGAYKCZImiZPyLGQBGRYKY3J5ZS1sZWlrZTEUMBIGCgmSJomT8ixkARkW
# BGNvcnAxFzAVBgNVBAMTDlN1YiBJc3N1aW5nIENBMIIBIjANBgkqhkiG9w0BAQEF
# AAOCAQ8AMIIBCgKCAQEAzzOZprhwPLPE2E9DuSVTk9b4Ok8yl8Vu0BBvYiuzkVGg
# 7NSPGCE6vyZrgjQP2AySPA9xHHZLZnlarDPdmB/5gL4YdP6nBG7hTFz+SSQjbYIY
# E0MgIafSwbhRfhb2vTRFU3UbDb+1XXy9FT7VMuxnWpocmvk52Q04AxXL4UMsbYjA
# ZaQ5Ezf77JrPQxtGV/eCCTrafRuy7n5XyfYNR89fS3CnLGvCa+2amn1G29XDoZlm
# lSWoaHMI1IuH9BZ6hHz0poWAQMG5c3PrRZuBIM+wK3hbXBpyikNkLjofi3D+uOq5
# FBL+J4nnrsfRuNmIFfgTCNi9QO31I+aceKegRX8WtwIDAQABo4IBaDCCAWQwEAYJ
# KwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFFG+e4v9gvTNsw8OgiqGwjZBmGRqMBkG
# CSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQEAwIBhjAPBgNVHRMBAf8E
# BTADAQH/MB8GA1UdIwQYMBaAFNG7txZu4q5FZu+wzWriLdeOdY3yMF4GA1UdHwRX
# MFUwU6BRoE+GTWh0dHA6Ly9jcmwuY29ycC5jcnllLWxlaWtlLmNvbS9DZXJ0RW5y
# b2xsL2NvcnAuY3J5ZS1sZWlrZS5jb20lMjBSb290JTIwQ0EuY3JsMHcGCCsGAQUF
# BwEBBGswaTBnBggrBgEFBQcwAoZbaHR0cDovL2NybC5jb3JwLmNyeWUtbGVpa2Uu
# Y29tL0NlcnRFbnJvbGwvTUVNLVZNLVJPT1RDQV9jb3JwLmNyeWUtbGVpa2UuY29t
# JTIwUm9vdCUyMENBLmNydDANBgkqhkiG9w0BAQ0FAAOCAQEACRsrA2SMcZ+bSNWs
# SQajq2b/03Whv52sxQ9OScWf1181sRxkPtQCxCj8Y3T6iq3iV4nPqyisvdBwj25i
# 50mROlVxDWpl9GnHpIg3Q+HPJf5NFFNK1cluoAgUMifh/usthvoF9DNFHOwl8aBe
# QCP+8P+oVFQIJiwnz7azKREiqeJfSTPk+nzQvsc5dpUw/GdIA2pq8nlaIiLSvllT
# Ryr1KLfi22T/UnTB8Pa89j4VfMUMLWXldirpqgl1CSE2dxo+qgpho7xfb8R/ozno
# UeMpbC4h2Y1CcRRToy4rHJMblr5mgqIw5tmYOlSbeBKIqWoyLOtXvt0JLA5mH4B3
# SBMZszCCBKMwggOLoAMCAQICEA7P9DjI/r81bgTYapgbGlAwDQYJKoZIhvcNAQEF
# BQAwXjELMAkGA1UEBhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9u
# MTAwLgYDVQQDEydTeW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIENBIC0g
# RzIwHhcNMTIxMDE4MDAwMDAwWhcNMjAxMjI5MjM1OTU5WjBiMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xNDAyBgNVBAMTK1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgU2lnbmVyIC0gRzQwggEiMA0GCSqG
# SIb3DQEBAQUAA4IBDwAwggEKAoIBAQCiYws5RLi7I6dESbsO/6HwYQpTk7CY260s
# D0rFbv+GPFNVDxXOBD8r/amWltm+YXkLW8lMhnbl4ENLIpXuwitDwZ/YaLSOQE/u
# hTi5EcUj8mRY8BUyb05Xoa6IpALXKh7NS+HdY9UXiTJbsF6ZWqidKFAOF+6W22E7
# RVEdzxJWC5JH/Kuu9mY9R6xwcueS51/NELnEg2SUGb0lgOHo0iKl0LoCeqF3k1tl
# w+4XdLxBhircCEyMkoyRLZ53RB9o1qh0d9sOWzKLVoszvdljyEmdOsXF6jML0vGj
# G/SLvtmzV4s73gSneiKyJK4ux3DFvk6DJgj7C72pT5kI4RAocqrNAgMBAAGjggFX
# MIIBUzAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4GA1Ud
# DwEB/wQEAwIHgDBzBggrBgEFBQcBAQRnMGUwKgYIKwYBBQUHMAGGHmh0dHA6Ly90
# cy1vY3NwLndzLnN5bWFudGVjLmNvbTA3BggrBgEFBQcwAoYraHR0cDovL3RzLWFp
# YS53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNlcjA8BgNVHR8ENTAzMDGgL6At
# hitodHRwOi8vdHMtY3JsLndzLnN5bWFudGVjLmNvbS90c3MtY2EtZzIuY3JsMCgG
# A1UdEQQhMB+kHTAbMRkwFwYDVQQDExBUaW1lU3RhbXAtMjA0OC0yMB0GA1UdDgQW
# BBRGxmmjDkoUHtVM2lJjFz9eNrwN5jAfBgNVHSMEGDAWgBRfmvVuXMzMdJrU3X3v
# P9vsTIAu3TANBgkqhkiG9w0BAQUFAAOCAQEAeDu0kSoATPCPYjA3eKOEJwdvGLLe
# Jdyg1JQDqoZOJZ+aQAMc3c7jecshaAbatjK0bb/0LCZjM+RJZG0N5sNnDvcFpDVs
# fIkWxumy37Lp3SDGcQ/NlXTctlzevTcfQ3jmeLXNKAQgo6rxS8SIKZEOgNER/N1c
# dm5PXg5FRkFuDbDqOJqxOtoJcRD8HHm0gHusafT9nLYMFivxf1sJPZtb4hbKE4Ft
# AC44DagpjyzhsvRaqQGvFZwsL0kb2yK7w/54lFHDhrGCiF3wPbRRoXkzKy57udwg
# CRNx62oZW8/opTBXLIlJP7nPf8m/PiJoY1OavWl0rMUdPH+S4MO8HNgEdTCCB9Uw
# gga9oAMCAQICExAAAAASNADQv56BQ1AAAAAAABIwDQYJKoZIhvcNAQENBQAwYDET
# MBEGCgmSJomT8ixkARkWA2NvbTEaMBgGCgmSJomT8ixkARkWCmNyeWUtbGVpa2Ux
# FDASBgoJkiaJk/IsZAEZFgRjb3JwMRcwFQYDVQQDEw5TdWIgSXNzdWluZyBDQTAe
# Fw0xOTAxMTAyMTAzMzdaFw0yMTAxMDkyMTAzMzdaMHExEzARBgoJkiaJk/IsZAEZ
# FgNjb20xGjAYBgoJkiaJk/IsZAEZFgpjcnllLWxlaWtlMRQwEgYKCZImiZPyLGQB
# GRYEY29ycDEOMAwGA1UEAxMFVXNlcnMxGDAWBgNVBAMTD0Nhc2V5IEtyb2xld2lj
# ejCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMxG7/qJ0RJA2TZhrkgl
# gs9uVQ+dwNSM5AUdQGps0VORYLly9dk3ZiMVwHvkXIS6SJp8dkOhYKeTj+dBKA6k
# McRUqdd7wGOoAYCWsyDs2DCzqlkECAYPy6olPitvav/Bl1Yw3hdS8VCwANgPyv14
# lyhKeRlSuYjgRHfPC3UmFdTlSTjHMYazMqdukJAvvWxuI3dbSCvOCp5KXePr2iFz
# W8Ap9OygIwa1MHDVAELxwT+RL/US/cdcED8wMgR/wf1d3ZgrZ7aYbX79jKvWzqf7
# JRwgFfJitDDkthmBDhsmmNkKWZdJDd73veQwyv/iraRw4ifrPya0HUgU39OOaIzA
# 4CMfqlcUjGL1ajB6Qp7F38mx7DTj2aDM4wk1D48puaM5kCFR4s69dtKb8fNZcTKW
# yTJgn6Tmdqa9sdDEI+412XAkRuOk94szweYk/tIznUX21Ro9epdMpiPPmXTgFW/5
# IS+RTa4ykOGikTGl0AVYEQDlSrv4x1QSDNyw8GsLxYRREVGmJhR+KyO5Fz9YGzBy
# 8Trr6JHaB90DSz8HOgTrQI0yUWB5wtyYSyG/ADIheYOSy0jFXKg/7iD8w7AOYvS4
# Byfr1ygdGBFV0ATHRg9uUkzq2iYHMsVtHCvAGmzod1sqjIEzRSmcnVi8YvpSZxWL
# nszA2TNCIlgcIJrtbxxnfQhTAgMBAAGjggN1MIIDcTA+BgkrBgEEAYI3FQcEMTAv
# BicrBgEEAYI3FQiEx9pygv6ZIIPJjzWChvAjgdXYIYEwgfL6JYKu2WACAWQCAQcw
# EwYDVR0lBAwwCgYIKwYBBQUHAwMwDgYDVR0PAQH/BAQDAgeAMBsGCSsGAQQBgjcV
# CgQOMAwwCgYIKwYBBQUHAwMwHQYDVR0OBBYEFJzkPRe1JPqsh03J6/i/Wli1vsoL
# MB8GA1UdIwQYMBaAFFG+e4v9gvTNsw8OgiqGwjZBmGRqMIIBJwYDVR0fBIIBHjCC
# ARowggEWoIIBEqCCAQ6GgclsZGFwOi8vL0NOPVN1YiUyMElzc3VpbmclMjBDQSxD
# Tj1NRU0tVk0tU1VCQ0EsQ049Q0RQLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2Vz
# LENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRpb24sREM9Y29ycCxEQz1jcnllLWxl
# aWtlLERDPWNvbT9jZXJ0aWZpY2F0ZVJldm9jYXRpb25MaXN0P2Jhc2U/b2JqZWN0
# Q2xhc3M9Y1JMRGlzdHJpYnV0aW9uUG9pbnSGQGh0dHA6Ly9jcmwuY29ycC5jcnll
# LWxlaWtlLmNvbS9DZXJ0RW5yb2xsL1N1YiUyMElzc3VpbmclMjBDQS5jcmwwggFA
# BggrBgEFBQcBAQSCATIwggEuMIG8BggrBgEFBQcwAoaBr2xkYXA6Ly8vQ049U3Vi
# JTIwSXNzdWluZyUyMENBLENOPUFJQSxDTj1QdWJsaWMlMjBLZXklMjBTZXJ2aWNl
# cyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9uLERDPWNvcnAsREM9Y3J5ZS1s
# ZWlrZSxEQz1jb20/Y0FDZXJ0aWZpY2F0ZT9iYXNlP29iamVjdENsYXNzPWNlcnRp
# ZmljYXRpb25BdXRob3JpdHkwbQYIKwYBBQUHMAKGYWh0dHA6Ly9jcmwuY29ycC5j
# cnllLWxlaWtlLmNvbS9DZXJ0RW5yb2xsL01FTS1WTS1TVUJDQS5jb3JwLmNyeWUt
# bGVpa2UuY29tX1N1YiUyMElzc3VpbmclMjBDQS5jcnQwPgYDVR0RBDcwNaAzBgor
# BgEEAYI3FAIDoCUMI2Nhc2V5Lmtyb2xld2ljekBjb3JwLmNyeWUtbGVpa2UuY29t
# MA0GCSqGSIb3DQEBDQUAA4IBAQBnr2wEGPz3JUOpqKSCV4jBRe9MUCwKEzgM5/9z
# 6XcH8a32/sOcJVNP93JMzqjqAP2m4NZo1QUjewAoIC+nilO0b8EF1xWbXEWqQm2w
# 4E13MmO8kSKfIXXl0tNB+JEZr35fAZ1wiXSrmaUpSDOsjMobE3YqqBxHye+viJEe
# GCTXWgxcgb6fwEl4ydrXr2I1LCHLH1Ff5SF3scsVXMT1PjWBfMGPac8L0UXcBzIc
# rjzfvZwqde8lTqd88s3Ba2bLWvOU0o95Y1EIk+QkclGkYfZKE5e6qYSuyXvpmb3+
# k8xzCLG25RoV1GW3eNuUH5UUUBzDlv9uOsrrYLCExPkUEM2QMYIFJzCCBSMCAQEw
# dzBgMRMwEQYKCZImiZPyLGQBGRYDY29tMRowGAYKCZImiZPyLGQBGRYKY3J5ZS1s
# ZWlrZTEUMBIGCgmSJomT8ixkARkWBGNvcnAxFzAVBgNVBAMTDlN1YiBJc3N1aW5n
# IENBAhMQAAAAEjQA0L+egUNQAAAAAAASMAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3
# AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisG
# AQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBSKm8i7Lidd
# fvkHbqI7Ht6oIcCcmDANBgkqhkiG9w0BAQEFAASCAgBzdBntkoPL4HLAU0fXzRqv
# 0luVTR5tT8GYUobqbuIhZgQcB1KoUnOqZuhk07RKetl6tZETOHpeBHW8jYs/RLYy
# R+CMS0sRfK+dkW5mvxk9v2oY+A491PvP7fgG4HoKZVQXv8gx6VgTOSXhFxc9vf2n
# cWwRmwBdxjvZFmjUPWnXYeV8j6JEAFpJ17SL3X5CTM/L0azurmeuN6lTs26ZERI5
# YvvqAMVfwsq3WDyIv+9SX4mIZ8vXr1okefGriniyFF1oOU/yqaaLgdIBjA1kreau
# /WrtQIpzLPQ5ZmQPDE1VhKGv+9nd/PPqfzEsY0VMc8YiBVNR6oa8NG+bVNcUWNmC
# WjActexvaPPJuX4i/cCfn0PQSdpGhYI1G+1bk98AS/yHZRBSZtnSBQJFltBTFlhZ
# +wAQQ2oRszrNppZeVs0xnlLj4f/HHbi56lHeLu4H7CpZ5+/kl3ZjRov8Y6BdUf0O
# 6nENSKXXk8Dw1c3vodw4fGNezdPqNELpRxmlNVLxFvI0xTPRn1AdRz5ixQSrgZqe
# PX/pgnYjnvuDVwXoYwK0nlt9MMp9bcaVPhGW2mg/NQwDPi5+12+xnUikQDgEAhPs
# t68n/G7+xO93Rrg5y884pDBa0McNzd7CFoJVsOg9glnwRR7aNQcBIE8CqsCctJ+O
# cO831otn8+t/vXaiy3pfkKGCAgswggIHBgkqhkiG9w0BCQYxggH4MIIB9AIBATBy
# MF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3JhdGlvbjEw
# MC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBDQSAtIEcy
# AhAOz/Q4yP6/NW4E2GqYGxpQMAkGBSsOAwIaBQCgXTAYBgkqhkiG9w0BCQMxCwYJ
# KoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0yMDA4MTAxNjU4MDBaMCMGCSqGSIb3
# DQEJBDEWBBQIfmm9V95D0QjhBSx61xcUjDyI5TANBgkqhkiG9w0BAQEFAASCAQAL
# fyYvIul0ECrNO2WHW1aE4t9ziqGKJoum81N4ag7MprwvoyqHPuGK2rUK4lteJZ4b
# 0yW0W3WL4TkppcME0vgB+aCvgyB7WRgy+88wiJAxkkzSm29wqgTs3Rmzzn7fXBjr
# Ug/iKkKi/6dnuvo8fmg6npq/8q/LzzxGI1wHoPN3oQ51gSvBkqNpVg82IOH5ZWNy
# QJOnacgWsCxhGH1yGZgWV6213DEg15HBjDIWzIiAcTsGNGRmVot7XYYbPuNVaNpf
# jfsum0xYekqyn1CZpVU9fLnUxDZo8HS2iQjDiT9+AXxkbXLyMtlcTgdzwho/LyiT
# d1+dpP08IMiHfD7okU+e
# SIG # End signature block
