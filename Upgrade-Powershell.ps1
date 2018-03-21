<#
.SYNOPSIS
Upgrade Powershell to v4 and then to 5.1

.NOTES
Tested only on Windows 7x64
I have this in a Scheduled task that runs nightly. It would take two runs + reboots to fully upgrade to 5.1
Script originally built to upgrade to v4.
#>
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {   
	$arguments = "& '" + $myinvocation.mycommand.definition + "'"
	Start-Process powershell -Verb runAs -ArgumentList $arguments
	Break
}
###upgrade powershell to 5.1###
Start-Transcript "c:\temp\powershellupdate.txt" -Force
New-Item -Path c:\temp\WMFv4 -ItemType Directory -ErrorAction SilentlyContinue -Force
New-Item -Path C:\temp\WMFv5.1 -Force -ItemType Directory -ErrorAction SilentlyContinue
$Log1 = "C:\temp\WMFv4\$env:COMPUTERNAME`_install.log"
$log2 = "\\path\to\log"
$rand = Get-Random -Minimum 10 -Maximum 1200
#start offset between 10 sec and 16 minutes (1200 sec)
write-output "$rand sec delay" | Add-Content $log1 -Force
$time = (Get-Date).addseconds($rand)
write-output "Update will start at $time" | Add-Content $log1 -Force

Start-Sleep $rand
if ($psversiontable.psversion.major -ge 4 -and ($psversiontable.psversion.major -le 5 -and $psversiontable.psversion.Minor -lt 1)){
$log1 = "c:\temp\WMFv5.1\$env:COMPUTERNAME`_install.log"

Write-Output "Creating Directory c:\temp\WMFv5.1" | Add-Content $log1
Write-Output "Copying update files" | Add-Content $log1
robocopy "\\source\path" "c:\temp\WMFv5.1\" "Windows7-WMF5.1-KB3191566-x64.msu"/r:1 /w:1 /E /Z /LOG+:"C:\temp\WMFv5.1\$env:COMPUTERNAME`_install.log"
Write-Output "Starting Update to WMF5.1" | Add-Content $Log1
#change to /warnrestart if you want to force a restart when it is done.
Start-Process wusa -ArgumentList "C:\temp\WMFv5.1\Windows7-WMF5.1-KB3191566-x64.msu /quiet /norestart"
}

if ($psversiontable.psversion.major -lt 4){
Write-Output "Creating Directory c:\temp\WMFv4" | Add-Content $Log1


$NetFrameworkVersion = $null
    write-output "Powershell version: $($psversiontable.psversion.major)" | Add-Content $Log1
    $NetRegKey = Get-Childitem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full'
    $Release = $NetRegKey.GetValue("Release")
    if (!($Release -ge 378389)){
    Write-Output ".net 4.5 is not installed on $env:COMPUTERNAME" | Add-Content $log2 -Force
    Send-MailMessage -SmtpServer "emailserver" -To "Email" -Port 25 -From "Email" -Subject ".net 4.5 Not Installed" -Body "$env:COMPUTERNAME needs .net 4.5 installed"
    }
    else{
    Write-Output ".net 4.5 or greater is installed" | Add-Content $Log1
    Write-Output "Copying update files" | Add-Content $Log1
    
    robocopy "\\Source\path" "c:\temp\WMFv4\" "Windows7-WMFv4-KB2819745-x64-MultiPkg.msu"/r:1 /w:1 /E /LOG+:"C:\temp\WMFv4\$env:COMPUTERNAME`_install.log"
    Write-Output "Starting Update" | Add-Content $Log1
    Start-Process wusa -ArgumentList "C:\temp\WMFv4\Windows7-WMFv4-KB2819745-x64-MultiPkg.msu /quiet /warnrestart"
    }



    #reg entry values that relate to .net version
    <#Switch ($Release) {
        378389 {$NetFrameworkVersion = "4.5"}
        378675 {$NetFrameworkVersion = "4.5.1"}
        378758 {$NetFrameworkVersion = "4.5.1"}
        379893 {$NetFrameworkVersion = "4.5.2"}
        393295 {$NetFrameworkVersion = "4.6"}
        393297 {$NetFrameworkVersion = "4.6"}
        394254 {$NetFrameworkVersion = "4.6.1"}
        394271 {$NetFrameworkVersion = "4.6.1"}
        394802 {$NetFrameworkVersion = "4.6.2"}
        394806 {$NetFrameworkVersion = "4.6.2"}
        Default {$NetFrameworkVersion = "Net Framework 4.5 or later is not installed."}
    }#>



#Write-Host $netframeworkversion
}
Stop-Transcript
# SIG # Begin signature block
# MIIEMAYJKoZIhvcNAQcCoIIEITCCBB0CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUNSk8q2KLEnBiZmWP9mPjRfne
# vGegggI7MIICNzCCAaSgAwIBAgIQyoKiddi2E61K5oECnHct1TAJBgUrDgMCHQUA
# MCsxKTAnBgNVBAMTIE1FTS1EQzEgUG93ZXJzaGVsbCBMb2NhbCBDQSBSb290MB4X
# DTExMDUwNDE5NTg0N1oXDTM5MTIzMTIzNTk1OVowGjEYMBYGA1UEAxMPUG93ZXJT
# aGVsbCBVc2VyMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQD2jE6GvF6dWFf9
# 0qZeAikhpqxoQKaaYlu8Ez8m4FB1Kmc4p8Om0RuUOdBxnziOWdeyK4+rtjME4Fkj
# ISpCd0Bb/+q7Xu+zOAHV/blZm8XThzkk/VimRLM3OuiMf1RTdqT/nTJsXGfjUtZF
# SbarjqpSNrey4P09XwAtk1kecU/FgQIDAQABo3UwczATBgNVHSUEDDAKBggrBgEF
# BQcDAzBcBgNVHQEEVTBTgBCsRUsazYKpjr2Ef3T4ExmVoS0wKzEpMCcGA1UEAxMg
# TUVNLURDMSBQb3dlcnNoZWxsIExvY2FsIENBIFJvb3SCEKJdFnlrD7ChR9wQGHXB
# b6wwCQYFKw4DAh0FAAOBgQAZHTJj4HHtGTj9PLRqTHQjx2tR5wyI+v5aDz3Nwr0F
# C/UC5ry17IwvUtUdequoeyqyXzUedsutdtH50CymJwAd9zkPSNGwjzZjyb4S7ybK
# M3q9OSbT9sSan2MHmzCM7uJumgIaotMSDrnRGxkCuMSh/5rMSSwhJ72JC2hWHAPH
# dTGCAV8wggFbAgEBMD8wKzEpMCcGA1UEAxMgTUVNLURDMSBQb3dlcnNoZWxsIExv
# Y2FsIENBIFJvb3QCEMqConXYthOtSuaBApx3LdUwCQYFKw4DAhoFAKB4MBgGCisG
# AQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFKL0
# Hn6We3qha0GzURX6M3ewqzAEMA0GCSqGSIb3DQEBAQUABIGAQPyeL5yHpDs6XZXv
# 65A43+RzRnxcnZyLqVAdd3zOPOhF44YnQ2AN3ao+cgtNwVVzaFrvaxveZ8CoUJ29
# sVyCIWpw74599M/JfyNXKpkrw8LEX7WrLoTU1ZtBP+ovTESynVzuvVpumvBPFWtf
# PcyCCbbqS57xKcfOF7Rcr6TG8zM=
# SIG # End signature block
