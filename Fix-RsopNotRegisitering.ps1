If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {   
	$arguments = "& '" + $myinvocation.mycommand.definition + "'"
	Start-Process powershell -Verb runAs -ArgumentList $arguments
	Break
}

#Fix RSOP not registering

regsvr32 c:\windows\system32\gpsvc.dll
sleep 3
    Mofcomp c:\windows\system32\wbem\policman.mof
    sleep 3

    Mofcomp c:\windows\system32\wbem\polprocl.mof
    sleep 3
    Mofcomp c:\windows\system32\wbem\polstore.mof
    sleep 3
    Mofcomp c:\windows\system32\wbem\scersop.mof
    sleep 3
    Mofcomp c:\windows\system32\wbem\rsop.mof
    sleep 3
Restart-Service -Name Winmgmt -Force
# SIG # Begin signature block
# MIIEMAYJKoZIhvcNAQcCoIIEITCCBB0CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUzs+bg4tQY6W7fP8ccfT0MB8F
# ZqigggI7MIICNzCCAaSgAwIBAgIQyoKiddi2E61K5oECnHct1TAJBgUrDgMCHQUA
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
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFHK3
# cCT7lrpIVn96CuScDB2R8O8xMA0GCSqGSIb3DQEBAQUABIGA2npK3PyRPfSXN7Bo
# 1bSxSEMAHB4aJcKrfljoxEtR+SgV/jesapyRDY2yTTr5x1y+nLLRtpHXC5VEEZ4f
# 7qRmKBkVOclaB6b7ESJEMw4DAvppScCRBLo/Y+HBnKwd5ALbRi8OZg/jP4cPUOgF
# nDCZ21XA6GN9s6tK2hSBdMPTA5U=
# SIG # End signature block
