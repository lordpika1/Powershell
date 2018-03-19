#Modify Chromebook marks for restricted users.
$comp = #computerlist
$count = 0


Function get-agentusername {

Param ($computer)

$ipaddress = (Resolve-DnsName $computer -ErrorAction SilentlyContinue).ipaddress
    If ($ipaddress -match "X.X.X.*"){
    $user = "user_login"
    return $user
    }

    #Write-host $user
}


foreach ($c in $comp){
if (Test-Connection $c.name -Count 2 -Quiet -ErrorAction SilentlyContinue){
$username = get-agentusername ($c.name)
Write-Host ($c.name)
$bookmarkarray = @(Get-Content "\\$($c.name)\c$\Users\$username\AppData\Roaming\Chrome\Default\Bookmarks")
#$bookmarkarray = ConvertFrom-Json $bookmarkarray
$path = "\\$($c.name)\c$\Users\$username\AppData\Roaming\Chrome\Default\Bookmarks"
#if (Test-Path -LiteralPath $path){
Rename-Item "\\$($c.name)\c$\Users\$username\AppData\Roaming\Chrome\Default\Bookmarks" -NewName "Bookmarks.old2" -ErrorAction SilentlyContinue
Rename-Item "\\$($c.name)\c$\Users\$username\AppData\Roaming\Chrome\Default\Bookmarks.bak" -NewName "Bookmarks.bak.old" -ErrorAction SilentlyContinue
    for ($i=0; $i -le $bookmarkarray.Count;$i++){
        if ($bookmarkarray[$i] -match '"checksum":*'){
        Write-Host ($c.name + $username + $bookmarkarray[$i])
        $bookmarkarray[$i] = ""
        Write-Host ($c.name + $username + $bookmarkarray[$i])
        }
        if ($bookmarkarray[$i] -match '"name": "name of bookmark to be replaced'){
        #Write-Host $i
        #write-Host $bookmarkarray[$i]
        Write-Host ($c.name + $username + $bookmarkarray[$i])
        $bookmarkarray[$i] = '"name": "replacement bookmark name",'
        Write-Host ($c.name + $username + $bookmarkarray[$i])
        #Write-Host $i
        }#>
        if ($bookmarkarray[$i] -match '"url": "URL to be replaced"'){
        #Rename-Item "\\$($c.name)\c$\Users\$username\AppData\Roaming\Chrome\Default\Bookmarks.bak" -NewName "Bookmarks.bak.old" -ErrorAction SilentlyContinue
        #Write-Host $i
        #write-Host $bookmarkarray[$i]
        Write-Host ($c.name + $username + $bookmarkarray[$i])
        $bookmarkarray[$i] = '"url": "url doing the replacement"'
        Write-Host ($c.name + $username + $bookmarkarray[$i])
        #Write-Host $i
        }
        Write-Output $bookmarkarray[$i] | Add-Content $path
        
    }
    
    #} #end test path
    #else{write-host $c.name " File not found"}#end filenot found
 }#end if test-connection 
 else {write-host $c.name "Not on network"}
 $count++
}
