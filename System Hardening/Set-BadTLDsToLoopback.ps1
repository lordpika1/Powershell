<#
.Description
Set certain just baaaad TLDs to the local loopback interface
Thanks to @NathanMcNulty for the idea/commands
#>
If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {   
	$arguments = "& '" + $myinvocation.mycommand.definition + "'"
	Start-Process powershell -Verb runAs -ArgumentList $arguments
	Break
}

$tlds = @(".ing",".meme",".zip",".mov")

$NRPTRules = $null
$NRPTRules = Get-DnsClientNrptRule
$NRPTHash = @{}



foreach ($tld in $tlds){

if ($NRPTRules -eq $null){

    
    
        
    Add-DnsClientNrptRule -Namespace "$tld" -NameServers "127.0.0.1" -DisplayName "Block $tld"
    
    
    
    

}else{
foreach ($rule in $NRPTRules){
#generate hash table for quick easy comparison.
$NRPTHash.Add($rule.Namespace[0],1)


}

if (!($NRPTHash[$tld])){

#if the TLD is not in this table add it and set the dns server to the loopback address


#Write-Output "Name: $($rule.namespace[0])"
#$tld
Add-DnsClientNrptRule -Namespace "$tld" -NameServers "127.0.0.1" -DisplayName "Block $tld"

}




}

    


}
