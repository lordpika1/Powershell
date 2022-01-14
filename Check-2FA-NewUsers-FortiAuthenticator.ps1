#This script is useful if you have FortiAuthenticator tied to Active Directory

#get the encrypted password.
$password = get-content "c:\Scripts\tokenCred.txt" | convertto-securestring
$apicred  = New-Object System.Management.Automation.PSCredential ("token_checker", $password)
#$apicred = (Get-Credential)
#ignore self signed certs
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

$users = @(Get-ADUser -SearchBase "DistinguishedName" -Properties name,enabled,whencreated,lastlogontimestamp,memberof -Filter * | sort SamAccountName)
Write-Host (Get-Date) | Add-Content C:\scripts\TokenCheck.txt

foreach ($user in $users){
Write-Host $user.SamAccountName | Add-Content C:\scripts\TokenCheck.txt

#only run on users created within last 10 days.
if ($user.whenCreated -gt ((Get-Date).AddDays(-10))){
#if ($user.whenCreated -gt ((Get-Date).AddDays(-100))){

#I add them to a temporary exclusion group.
Add-ADGroupMember -Identity "AD Group" -Members $user

#Get info from FortiAuthenticator about user.
$facuser = Invoke-RestMethod -Method GET -Uri "https://fac/api/v1/ldapusers/?username=$($user.samaccountname)" -Credential $apicred

$facuserObjects  = $facuser.objects
        if ($facuserobjects.token_auth -match "False"){
            
            #If email field is blank, send an email
                if ($facuser.objects[0].email -eq ""){
                
                Send-MailMessage -To email@email.com  -From email@emil.com -Subject "FAC - No Email for user" -Bodyashtml "<html>$($facuserObjects.username)<br>$($facuserObjects.dn)</html>" -SmtpServer ipaddress -Port 25
                
                }
            #resend activation email. ftm = fortitoken mobile
            #`"is_active:`": `"True`",`"active:`": `"True`", 
            #Invoke-RestMethod -Method Patch -Uri "https://fac/api/v1/ldapusers/$($facuserObjects.id)/" -Body "{`"active`": `"True`"}" -Credential $apicred
            #enable user and set token type to FortiToken Mobile

            Invoke-RestMethod -Method Patch -Uri "https://fac/api/v1/ldapusers/$($facuserObjects.id)/" -Body "{`"active`": `"True`",`"token_auth`": `"True`",`"token_type`": `"ftm`"}" -Credential $apicred
            }





    }else{
    #remove them from group if it's all good. 
    Remove-ADGroupMember -Identity "AD Group" -Members $user -Server mem-vm-dc1 -Confirm:$false
    
    
    
    
    
    }#END when created


}#END Foreach User

