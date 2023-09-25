<#
.Description
Download's the latest list of Phishing URLS from PhishTank. Requires 7zip.
#>
Start-Transcript "c:\scripts\$($MyInvocation.MyCommand.Name).log"
$outfile = "c:\scripts\online-valid.csv.gz"
$csvfilepath = "C:\scripts\online-valid.csv"
$trimmedcsvfilepath = "C:\scripts\online-valid-trimmed.csv"


if ((Get-Item -Path $outfile).LastWriteTime -lt (Get-Date).AddHours(-12)){

Remove-Item $outfile -Force -Confirm:$false
Remove-Item $csvfilepath -Force -Confirm:$false
Remove-Item $trimmedcsvfilepath -Force -Confirm:$false

Invoke-WebRequest -Uri "http://data.phishtank.com/data/online-valid.csv.gz" -OutFile $outfile -UseBasicParsing -Method Get -UserAgent "phishtank/powershell"


}else{exit}

Start-Process 'cmd.exe' -WorkingDirectory "C:\Program Files\7-Zip\" -ArgumentList "/c `"7z.exe e $outfile -oc:\scripts\`""



$phishingList = Import-Csv $csvfilepath

$count = 0



foreach ($phish in $phishingList){

if ((get-date $($phish.verification_time)) -gt (get-date).AddDays(-30) -and $phish.verified -imatch "yes"){

$phish | Export-Csv -Append -Path $trimmedcsvfilepath -NoTypeInformation

$count++
}


}