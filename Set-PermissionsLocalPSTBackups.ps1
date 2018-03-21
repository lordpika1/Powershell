<#
.SYNOPSIS
Monitor and modify permissions that are required for a computer account to backup to a Synology nas.

.DESCRIPTION
This will check permissions on the pst backup path and if the computer account is not listed it will then grant the computer account permission to create.

.NOTES
#### Requires PoSHSSH #####
The Set-Acl commandlet does not work on Synology Nases for some reason.
Use this in a domain environment
I store the password as a secure string in a text file.
you could do the same! read-host -assecurestring | convertfrom-securestring | out-file C:\cred.txt
There are two different methods it uses to try and apply permissions via ssh as it doesn't always work the first round.
#### Requires PoshSSH #####
#>
$comps = "list of computer names"
$password = get-content "c:\scripts\localcreds.txt" | convertto-securestring
$cred = New-Object System.Management.Automation.PSCredential ("user", $password)
$logpath = "c:\scripts\set-permissions.txt"
Write-Output "`n################################" | Add-Content $logpath
Write-Output (get-date) | Add-Content $logpath
Write-Output "################################" | Add-Content $logpath

foreach ($comp in $comps){
Write-Output "`n-----" | Add-Content $logpath
Write-Output "Computer: $comp" |Add-Content $logpath
$ip = $null
try {$ip=(get-WmiObject Win32_NetworkAdapterConfiguration -ComputerName $comp) | Where {$_.IPAddress -gt 1 -and $_.DNSDomainSuffixSearchOrder -match "matching criteria"}}catch{$ip=$null}

$acltophash = $aclnexthash = $null
$aclstop = $aclsnext = $null




$ipsplit = $ip.IPAddress -split "\."
#put take split ip and create subnet var
$subnet = "$($ipsplit[0]).$($ipsplit[1]).$($ipsplit[2]).0"
#assumption branch ip is .15
$branchserverip = "$($ipsplit[0]).$($ipsplit[1]).$($ipsplit[2]).ip"
$branchservername = (nslookup $branchserverip)[3] -replace "Name:\s+",""


$psttoplevelbackuppath = "\\path"
$pstnextlevelbackuppath = "\\path"
if ($comp -like "you put something here"){
write-output "some random debugging text" |Add-Content $logpath
$branchservername = "server"
$psttoplevelbackuppath = "\\path"
$pstnextlevelbackuppath = "\\path"
}

write-output $branchserverip|Add-Content $logpath
write-output $branchservername|Add-Content $logpath
write-output $psttoplevelbackuppath|Add-Content $logpath
write-output $pstnextlevelbackuppath|Add-Content $logpath

if (!(Test-Path -Path "$pstnextlevelbackuppath"-ErrorAction SilentlyContinue) -and $ip -ne $null){
        #test and see if the localpstbackups folder is there. if not create it
        New-Item -Path "$pstnextlevelbackuppath" -ItemType Directory -Force -Verbose
        }



if (!($comp -match "matching criteria") -and $ip -ne $null){

$aclstop = (Get-item $psttoplevelbackuppath).GetAccessControl('Access')
$aclsnext = (Get-item $pstnextlevelbackuppath).GetAccessControl('Access')

$acltophash = $aclnexthash = @{}

$comptocompare = "----domainname---\$comp$"
Write-Output "Comptocompare: $comptocompare" |Add-Content $logpath
foreach ($acl in $aclstop.access){
#write-output "$($acl.IdentityReference)"
    if (!($acltophash.containskey("$($acl.IdentityReference)"))){
    #write-output "Adding..$($acl.IdentityReference) to hash"
    $acltophash.add("$($acl.IdentityReference)","1")
    }

}
if ($acltophash.containskey($comptocompare)){
write-output "$comptocompare is already added to $psttoplevelbackuppath"|Add-Content $logpath
}elseif($ip -ne $null){
Write-Output "Ip: $ip"|Add-Content $logpath
write-output "$comptocompare needs to be added to $psttoplevelbackuppath"|Add-Content $logpath






    $command = "sudo synoacltool -add /volume1/Users/ user:----domainname---\\$comp$`:allow:-wxp--aARWc--:---n"
    $createsession = New-SSHSession -ComputerName $branchservername -Credential $cred -AcceptKey
    
    try {$seshid = Get-SSHSession -ComputerName $branchservername}catch{}

    $stream = New-SSHShellStream -SessionId $seshid.SessionId
   
    try {$output = (Invoke-SSHStreamExpectSecureAction -Verbose -ShellStream $stream -SecureAction $cred.Password -TimeOut 10 -Command $command -ExpectString 'Password:')}catch{}
    $stream.read()
    $stream.WriteLine($cred.GetNetworkCredential().Password)
    $stream.Read()
    write-output $comp|Add-Content $logpath
    write-output $output|Add-Content $logpath
    Start-Sleep 1
    $permnextlevel = icacls \\path\to\ /grant "----domainname---"\$comp$`:`(CI`)`(M`)
    Write-Output $permnextlevel|Add-Content $logpath
    $stream.Close()
    }#end acl hash check
}

if ($comp -match "matching criteria"){
$aclstop = (Get-item $psttoplevelbackuppath).GetAccessControl('Access')
$aclsnext = (Get-item $pstnextlevelbackuppath).GetAccessControl('Access')

$acltophash = $aclnexthash = @{}

$comptocompare = "---domainname---\$comp$"
Write-Output "Comptocompare: $comptocompare" |Add-Content $logpath
foreach ($acl in $aclstop.access){
#write-output "$($acl.IdentityReference)"
    if (!($acltophash.containskey("$($acl.IdentityReference)"))){
    #write-output "Adding..$($acl.IdentityReference) to hash"
    $acltophash.add("$($acl.IdentityReference)","1")
    }

}
if ($acltophash.containskey($comptocompare)){
write-output "$comptocompare is already added to $psttoplevelbackuppath"|Add-Content $logpath
}elseif($ip -ne $null){
Write-Output "Ip: $ip"|Add-Content $logpath
write-output "$comptocompare needs to be added to $psttoplevelbackuppath"|Add-Content $logpath

write-output "Setting permmisions for $comp on $pstnextlevelbackuppath"|Add-Content $logpath
$permnextlevel = icacls $pstnextlevelbackuppath /grant "----domainname---"\$comp$`:`(CI`)`(M`)
Write-Output $permnextlevel|Add-Content $logpath
}




}

$sessions = Get-SSHSession
foreach ($session in $sessions){
remove-sshsession $session
}