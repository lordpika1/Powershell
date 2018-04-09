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

