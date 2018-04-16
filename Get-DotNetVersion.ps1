<#
.DESCRIPTION
Checks if remote computer has .net 4.5 or above
#>
$comps = "List of Comps" | sort
foreach ($c in $comps){
$Release = $null
if (Test-Connection $c -Count 2 -Quiet){

    try{Invoke-Command -ComputerName $c -ErrorAction stop -ScriptBlock{
    $NetRegKey = Get-Childitem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' 
    $Release = $NetRegKey.GetValue("Release")
    Switch ($Release) {
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
            460798 {$NetFrameworkVersion = "4.7"}
            460805 {$NetFrameworkVersion = "4.7"}
            461308 {$NetFrameworkVersion = "4.7.1"}
            461310 {$NetFrameworkVersion = "4.7.1"}
        
            Default {if($Release -ge 378389 -and $Release -lt 393295){
            $NetFrameworkVersion = "At least 4.5 installed"
            }elseif($Release -ge 393295){
            $NetFrameworkVersion = "At least 4.6 installed"
            }else{
            $NetFrameworkVersion = "Net Framework 4.5 or later is not installed."
                }
            }
        }
        Write-Host $env:COMPUTERNAME"-"$NetFrameworkVersion"-"$release
    }
    }catch{#end invoke
    $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey("LocalMachine", "$c")
    $key = $reg.OpenSubKey("SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full")
    $release = $key.getvalue("Release")
 Switch ($Release) {
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
            460798 {$NetFrameworkVersion = "4.7"}
            460805 {$NetFrameworkVersion = "4.7"}
            461308 {$NetFrameworkVersion = "4.7.1"}
            461310 {$NetFrameworkVersion = "4.7.1"}
        
            Default {if($Release -ge 378389 -and $Release -lt 393295){
            $NetFrameworkVersion = "At least 4.5 installed"
            }elseif($Release -ge 393295){
            $NetFrameworkVersion = "At least 4.6 installed"
            }else{
            $NetFrameworkVersion = "Net Framework 4.5 or later is not installed."}
            }
        }
Write-Host $c"-"$NetFrameworkVersion"-"$release
    }
}#end test-connection
    #Write-Host $c"-"$NetFrameworkVersion"-"$release
}


#$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey("LocalMachine", "$c")
#$key = $reg.OpenSubKey("SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full")
#$value = $key.getvalue("Release")