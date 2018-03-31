<#
.DESCRIPTION
Update Dell Optiplex 3010/3020 to their most recent bios versions
.NOTES
Uses PSEXEC
#>
Start-Transcript "path" -Force -Append
$comps = "list of computers"

foreach ($comp in $comps){
$bios = $info = $null
$info = Get-wmiobject win32_computersystem -ComputerName $comp -Property Model -ErrorAction SilentlyContinue
if ($info.Model -match " *3010"){
$biosversion = (Get-wmiobject win32_bios -Property SMBIOSBIOSVersion -ComputerName $comp -ErrorAction SilentlyContinue).SMBIOSBIOSVersion
write-host "$comp - $($info.Model) - $($biosversion)"
}


if ($info.model -match " *3010" -and ($biosversion -notmatch "A19") ){
    $model = "Optiplex3010"
    $path = "\\$comp\c$\temp\$model"
    $logfilepath = "\\$comp\c$\temp\$model\updatelog.txt"

    if (!(test-path $path)){
       New-item -Path $path -ItemType Directory -Force -Verbose
        }
        if ($biosversion -notmatch "A19"){
   
    robocopy /r:1 /w:1 /Z /LOG+:"$logfilepath" "\\source\path\" $path "O3010A19.exe"
    $result = & C:\Users\path\to\PsExec.exe \\$comp -s cmd "/c c:\temp\$model\O3010A19.exe /s /r /l=c:\temp\biosupdate.txt"
    
    }
    }#>

 




if ($info.model -match " *3020" -and ($biosversion -notmatch "A17") ){
    $model = "Optiplex3020"
    $path = "\\$comp\c$\temp\$model"
    $logfilepath = "\\$comp\c$\temp\$model\updatelog.txt"
    $biosversion = (Get-wmiobject win32_bios -Property SMBIOSBIOSVersion -ComputerName $comp -ErrorAction SilentlyContinue).SMBIOSBIOSVersion
    write-host "$comp - $($info.Model) - $($biosversion)"
    if (!(test-path $path)){
       New-item -Path $path -ItemType Directory -Force -Verbose
        }
        if ($biosversion -notmatch "A17"){
   
    robocopy /r:1 /w:1 /Z /LOG+:"$logfilepath" "\\source\path\" $path "O3020A17.exe"
    $result = & C:\Users\path\to\PsExec.exe \\$comp -s cmd "/c c:\temp\$model\O3020A17.exe /s /r /l=c:\temp\biosupdate.txt"
    
    }
    }#>
}#end foreach
Stop-Transcript