#https://docs.microsoft.com/en-us/windows-hardware/drivers/ddi/content/d3dkmdt/ne-d3dkmdt-_d3dkmdt_video_output_technology
$comps = #list of computers | Sort
$path = "log\path"
function DeterminCableType(){
Param ([int]$cable)
switch ($cable){
-2 {$type = "Uninitialized"}
-1 {$type = "Other"}
0  {$type = "VGA (HD15)"}
1  {$type = "SVIDEO"}
2  {$type = "COMPOSITE VIDEO"}
3  {$type = "COMPONENT VIDEO"}
4  {$type = "DVI"}
5  {$type = "HDMI"}
6  {$type = "LVDS"}
8  {$type = "D_JPN"}
9  {$type = "SDI"}
10 {$type = "DISPLAYPORT_EXTERNAL"}
11 {$type = "DISPLAYPORT_EMBEDDED"}
12 {$type = "UDI_EXTERNAL"}
13 {$type = "UDI_EMBEDDED"}
14 {$type = "SDTVDONGLE"}
Default {$type = "Unknown"}
}
return $type
}
foreach ($c in $comps){
$rtype = $cablenum = $null
if (Test-Connection $c -Quiet -Count 2){

try {([int]$cablenum = ((get-ciminstance -namespace root/wmi -classname WmiMonitorConnectionParams -ComputerName $c -ErrorAction stop).Videooutputtechnology))}catch{Write-Host "$c`:Error in CimInstance";continue}
$rtype = (DeterminCableType ($cablenum))
write-output "$c,$rtype"# |Add-Content $path
}
}