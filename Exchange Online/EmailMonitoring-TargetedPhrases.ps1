<#
.Description
Use this to target phrases/regex in the email body and move them to a user's deleted items. Very helpful if a phishing email get blasted out to your users.
You'll need to grant consent for mail.readwrite,directory.read.all to an Enterpise Application in Entra ID.
#>
############ connection setup ###############
$appID = "your app id"
$tenantID = "your tenant id"
$securePWD = "your special super secret client secret"

$SecuredPasswordPassword = ConvertTo-SecureString -String $securePWD -AsPlainText -Force

$ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $appID, $SecuredPasswordPassword


#The minus two is to make sure there's enough cpu for the system and any other scripts running.
$maxjobs = $([int]$env:NUMBER_OF_PROCESSORS) - 2


Start-Transcript "c:\scripts\$($MyInvocation.MyCommand.Name).log"
Connect-MgGraph -TenantId $tenantID -ClientSecretCredential $ClientSecretCredential -NoWelcome



############## Time Stuff ########################
$scriptStartTime = (get-date).ToUniversalTime()

$lastRunPath = "c:\scripts\$($MyInvocation.MyCommand.Name)_lastrun.txt"

$lastRun = ((Get-Date).AddHours(-18)).ToUniversalTime()



$AllMGUSers = (Get-MgUser -Filter 'assignedLicenses/$count ne 0' -ConsistencyLevel eventual -CountVariable licensedUserCount -Al).UserPrincipalName | select -Unique

$allUsers = $AllMGUSers |sort

#generate base64 encoding of email address
$base64list = @()
foreach ($user in $allUsers){
$encodedBytes = [System.Text.Encoding]::UTF8.GetBytes($user)
$encodedText = [System.Convert]::ToBase64String($encodedBytes)
$base64list += $encodedText
}

$BasePath = "c:\scripts\Email\TargetedPhrases"

#Actionable phrases
Write-Output "$(get-date) - Adding manual entries from local csv"
$targetListManualcsv = "$BasePath\targetListManual.csv"
$targetListManual = Import-Csv $targetListManualcsv

#Test phrases
Write-Output "$(get-date) - Adding test entries from local csv"
$targetListTestcsv = "$BasePath\targetListTest.csv"
$targetListTest = Import-Csv $targetListTestcsv

#Regex phrases
Write-Output "$(get-date) - Adding regex entries from local csv"
$targetListRegexcsv = "$BasePath\targetListRegex.csv"
$targetListRegex = Import-Csv $targetListRegexcsv


$scriptblock = {
param($users,$lastrun,$targetListManual,$base64list,$targetListTest,$targetListRegex)

########## Graph Connection #######
$appID = "your app id"
$tenantID = "your tenant id"
$securePWD = "your special super secret client secret"

$SecuredPasswordPassword = ConvertTo-SecureString -String $securePWD -AsPlainText -Force

$ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $appID, $SecuredPasswordPassword

Connect-MgGraph -TenantId $tenantID -ClientSecretCredential $ClientSecretCredential -NoWelcome > $null
########## Graph Connection #######
$BasePath = "c:\scripts\Email\TargetedPhrases"



#set lookback time and format it.s
$date = (get-date $lastrun).ToUniversalTime().ToString("+yyyy-MM-ddTHH:mm:ss.0000000Z")

foreach ($user in $users){
$deleteCount = 0
$testCount = 0
Start-Transcript "$BasePath\$user\$((get-date).ToString("yyyy-MM-dd"))_transcript.txt" -Append -Force > $null

$AllMessages = $null
$AllMessages = (Get-MgUserMessage -UserId $user -Filter "(ReceivedDateTime ge $date)" -All)
if ($AllMessages -eq $null){continue}
if ($AllMessages.count -eq 0){continue}

$mailFolders = $null
$mailFolders = Get-MgUserMailFolder -All -UserId $user
if ($mailFolders -eq $null){continue}
if ($mailFolders.count -eq 0){continue}

$DeletedItemsID = ($mailFolders | Where-Object {$_.DisplayName -match "Deleted Items"}).Id 
$InboxID = ($mailFolders | Where-Object {$_.DisplayName -imatch "Inbox"}).Id 


    #Create folder for user
    if (!(Test-Path $BasePath\$user)){

    New-Item "$BasePath\$user" -ItemType Directory
    }
    
    foreach ($message in $AllMessages){
            $messageDeleted = $false
            #if the message is already deleted, let's move on
            if ($message.ParentFolderId -match $DeletedItemsID){
            #Write-Host "$($message.Subject) already deleted"
            #Write-Host "Message ID: $($message.Id)"
            continue
            }


            #!!change this to the from email you're using
            if ($message.From.EmailAddress.Address -match 'email@email.com'){
            
            continue
            }

            #date message was received
            $messageDate = $message.ReceivedDateTime.ToString("yyyy-MM-dd")
            $folderName = $null
            $folderName = ($mailFolders | Where-Object {$_.Id -match $message.ParentFolderId}).DisplayName
            ########################
            #manual targeted phrases
            ########################
            foreach ($phrase in $targetListManual.phrases){
                #this is to make sure a literal dot is used and not the regex dot to match anything.
                if ($message.body.Content -imatch $($phrase -replace "\.","\.") ){
                        Write-Output "$user<br>"
                        Write-Output "Subject: $($message.Subject)<br>"
                        Write-Output "Matching Phrase: $($phrase)<br>"
                        Write-Output "Subject: $($message.Subject)" | Add-Content "$BasePath\$user\$((get-date).ToString("yyyy-MM-dd")).txt" > $null
                        Write-Output "Deleted items ID: $DeletedItemsID" | Add-Content "$BasePath\$user\$((get-date).ToString("yyyy-MM-dd")).txt" > $null
                        Write-Output "Inbox ID: $InboxID" | Add-Content "$BasePath\$user\$((get-date).ToString("yyyy-MM-dd")).txt" > $null
                        Write-Output "Message ID: $($message.Id)" | Add-Content "$BasePath\$user\$((get-date).ToString("yyyy-MM-dd")).txt" > $null

                        $moveResults = Move-MgUserMessage -MessageId $message.Id -UserId $user -DestinationId $DeletedItemsID -Confirm:$false
                        Write-Output "New Message ID: $($moveResults.Id)" | Add-Content "$BasePath\$user\$((get-date).ToString("yyyy-MM-dd")).txt" > $null
                        #Write-Output "New Message ID: $($moveResults.Id)<br>"
                        $deleteCount++
                        $messageDeleted = $true
                        break
                
                }
            }
            #if it's going to be deleted already no point in continuing.
            if ($messageDeleted){continue}
            #######################
            #base64 encoding found#
            #######################

            #Deletion not enabled. Only looking for body content with base64 encoding and an htm(l) extension. Advertisers and others use Base64 unfortunately.
            #uses cmatch as it has to be case sensitive obviously.
            foreach ($base64 in $base64list){
                if ($message.body.Content -cmatch "$($base64)\.html|$($base64)\.htm" ){
                        Write-Output "$user<br>"
                        Write-Output "Subject: $($message.Subject)<br>"
                        Write-Output "Matching Base64: $base64<br>"
                        Write-Output "Subject: $($message.Subject)" | Add-Content "$BasePath\$user\$((get-date).ToString("yyyy-MM-dd")).txt" > $null
                        Write-Output "Deleted items ID: $DeletedItemsID" | Add-Content "$BasePath\$user\$((get-date).ToString("yyyy-MM-dd")).txt" > $null
                        Write-Output "Inbox ID: $InboxID" | Add-Content "$BasePath\$user\$((get-date).ToString("yyyy-MM-dd")).txt" > $null
                        Write-Output "Message ID: $($message.Id)" | Add-Content "$BasePath\$user\$((get-date).ToString("yyyy-MM-dd")).txt" > $null

                        #$moveResults = Move-MgUserMessage -MessageId $message.Id -UserId $user -DestinationId $DeletedItemsID -Confirm:$false
                        Write-Output "New Message ID: $($moveResults.Id)" | Add-Content "$BasePath\$user\$((get-date).ToString("yyyy-MM-dd")).txt" > $null
                        #Write-Output "New Message ID: $($moveResults.Id)<br>"
                        $deleteCount++
                        break
                
                }
            }
            
            #######################
            #Regex targeted phrases
            #######################
            if ($targetListRegex.phrases.count -gt 0){
               foreach ($regex in $targetListRegex.phrases){
                if ($message.body.Content -imatch $regex ){
                        #$selectString = Select-String -InputObject $message.body.Content -Pattern $test
                        Write-Output "$user<br>"
                        Write-Output "Subject: $($message.Subject)<br>"
                        Write-Output "Matching Regex: $($regex)<br>"
                        Write-Output "Subject: $($message.Subject)" | Add-Content "$BasePath\$user\$((get-date).ToString("yyyy-MM-dd")).txt" > $null
                        Write-Output "Deleted items ID: $DeletedItemsID" | Add-Content "$BasePath\$user\$((get-date).ToString("yyyy-MM-dd")).txt" > $null
                        Write-Output "Inbox ID: $InboxID" | Add-Content "$BasePath\$user\$((get-date).ToString("yyyy-MM-dd")).txt" > $null
                        Write-Output "Message ID: $($message.Id)" | Add-Content "$BasePath\$user\$((get-date).ToString("yyyy-MM-dd")).txt" > $null

                        $moveResults = Move-MgUserMessage -MessageId $message.Id -UserId $user -DestinationId $DeletedItemsID -Confirm:$false
                        Write-Output "New Message ID: $($moveResults.Id)" | Add-Content "$BasePath\$user\$((get-date).ToString("yyyy-MM-dd")).txt" > $null
                        #Write-Output "New Message ID: $($moveResults.Id)<br>"
                        $deleteCount++
                        $messageDeleted = $true
                        break
                
                }
            }
            }#end targetlist Regex

            #######################
            #test targeted phrases#
            #######################
            if ($targetListTest.phrases.count -gt 0){
               foreach ($test in $targetListTest.phrases){
                if ($message.body.Content -imatch $test ){
                        $selectString = Select-String -InputObject $message.body.Content -Pattern $test
                        Write-Output "$user<br>"
                        Write-Output "Subject: $($message.Subject)<br>"
                        Write-Output "Matching TEST Phrase: $($test)<br>"
                        Write-Output "Matching String: $selectString"
                        Write-Output "Subject: $($message.Subject)" | Add-Content "$BasePath\$user\$((get-date).ToString("yyyy-MM-dd")).txt" > $null
                        Write-Output "Deleted items ID: $DeletedItemsID" | Add-Content "$BasePath\$user\$((get-date).ToString("yyyy-MM-dd")).txt" > $null
                        Write-Output "Inbox ID: $InboxID" | Add-Content "$BasePath\$user\$((get-date).ToString("yyyy-MM-dd")).txt" > $null
                        Write-Output "Message ID: $($message.Id)" | Add-Content "$BasePath\$user\$((get-date).ToString("yyyy-MM-dd")).txt" > $null

                        
                        #Write-Output "New Message ID: $($moveResults.Id)<br>"
                        $testCount++
                        break
                
                }
            }
            }#end targetlist test


    }




    if ($deleteCount -ne 0){
    Write-Output "$deleteCount deleted for $user<br><br>"
    }
    if ($testCount -ne 0){
    Write-Output "$testCount would have been deleted for $user<br><br>"
    }
#Write-Output "$user,Messages: $($AllMessages.count),Folders: $($mailFolders.count)<br>"
Stop-Transcript > $null
}#end for each user

Disconnect-MgGraph > $null
}



$count = 0

$dividingby = $($allUsers.Count/$maxjobs)

For ($i=0; $i -le $($allUsers.Count) ; $i+=$($allUsers.Count/$maxjobs)){
    $endrange = $i + $dividingby
    Start-Job -ScriptBlock $scriptblock -ArgumentList $allUsers[$i..[math]::Round($endrange,0)],$lastRun,$targetListManual,$base64list,$targetListTest,$targetListRegex
    Start-Sleep 1
}

$sleepCount = 0
do{
 #Write-Host "Checking Job State"
 Write-host "Current Jobs Running:" (Get-Job -State Running).count 
 Write-Output "Sleep Count: $sleepCount"
 #if((Get-Job -State 'Running').count -eq 0) {break}

 $receiveJobDetails += get-job -State Completed | Receive-Job 

 Start-Sleep 5

 #lets check on those long jobs
        $longtimejobs = get-job -State Running
        foreach ($longtimejob in $longtimejobs){


        if(((get-date) - (get-date $longtimejob.PSBeginTime)).TotalMinutes -gt 30){

        #Write-Output "Killing $($longtimejob.Name)"

        #Stop-Job $longtimejob -Confirm:$false

        }

        }



 $sleepCount++
 }while (((Get-Job -State 'NotStarted').count -gt 0 -or (Get-Job -State 'Running').count -gt 0) -and ($sleepCount -lt 400))

Get-Job -State 'Running' | Stop-Job -confirm:$false -verbose

$receiveJobDetails += Receive-Job * 

$receiveJobDetails += "<b>Targeted Phrases: $($targetListManual.count)</b><br>"
$receiveJobDetails += "<b>Targeted Test Phrases: $($targetListTest.phrases.count)</b><br>"
$receiveJobDetails += "<b>Targeted Regex Phrases: $($targetListRegex.phrases.count)</b><br>"
$receiveJobDetails += "Total Users: $($allUsers.count)<br>"
$receiveJobDetails += "Total time: $([math]::Round(((get-date).ToUniversalTime() - $scriptStartTime).TotalMinutes,2)) minutes"
$receiveJobDetails
if ($receiveJobDetails){


Send-MailMessage -to email@email.com -From email@email.com -Subject "Email Deletion Results" -SmtpServer "serverip" -BodyAsHtml -Body ($receiveJobDetails | Out-String) -Verbose

}

#only set the date if we complete the script.

Remove-Item $lastRunPath


Write-Output "Total Users: $($allUsers.count)"
write-output "$scriptStartTime"| Add-Content $lastRunPath -Force
Write-Output "End time: $((get-date))"
Write-Output "Total time: $(((get-date).ToUniversalTime() - $scriptStartTime).TotalMinutes)"
