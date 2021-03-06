$compname = Read-Host "Enter source computer name"
$compnametocompare = Read-Host "Enter computer to compare"
#get Share security info
$names = gwmi -Class win32_logicalsharesecuritysetting -ComputerName $compname | sort-object
$namestocompare = gwmi -Class win32_logicalsharesecuritysetting -ComputerName $compnametocompare | sort-object
$hash1 = @{}
$hash2 = @{}
$namehash = @{}
$comparehash = @{}
foreach ($name in $names){
$hash1.Add($name.Name,"1")
}

$name = $null

foreach ($name in $namestocompare){
$hash2.Add($name.Name,"1")
}

Write-Host "Comparing $compname to $compnametocompare"
Compare-Object $($hash1.keys) $($hash2.keys)


<#foreach ($name in $names){
$share = "Name=$($name.name)"
$share = Get-WmiObject -Class win32_share -ComputerName $compname -filter "name='$($name.name)'"
#Write-Host $name.name $share.path
$acllist = $name.GetSecurityDescriptor().Descriptor.DACL | Sort-Object
$namehash.Add($name.Name,$acllist.Trustee.Name)
    foreach ($acl in $acllist){
    $user = $acl.Trustee.name
    if (!($user)){$user = $acl.trustee.sid}
    $domain = $acl.trustee.domain
   
    switch($ACL.AccessMask)
            {
                2032127 {$Perm = "Full Control"}
                1245631 {$Perm = "Change"}
                1179817 {$Perm = "Read"}
            }
    #write-host "     $domain\$user   $perm"
    
    }

}


$name = $null

foreach ($name in $namestocompare){
$share = "Name=$($name.name)"
$share = Get-WmiObject -Class win32_share -ComputerName $compname -filter "name='$($name.name)'"
#Write-Host $name.name $share.path
$acllist = $name.GetSecurityDescriptor().Descriptor.DACL | Sort-Object
$comparehash.Add($name.Name,$acllist.Trustee.Name)
    foreach ($acl in $acllist){
    $user = $acl.Trustee.name
    if (!($user)){$user = $acl.trustee.sid}
    $domain = $acl.trustee.domain
   
    switch($ACL.AccessMask)
            {
                2032127 {$Perm = "Full Control"}
                1245631 {$Perm = "Change"}
                1179817 {$Perm = "Read"}
            }
    #write-host "     $domain\$user   $perm"
    
    }

}
foreach ($name in $names){
    if($($name.Name).ToString() -match $null){
    Compare-Object $($namehash[$name.name]) $($comparehash[$name.Name])
    }
}#>