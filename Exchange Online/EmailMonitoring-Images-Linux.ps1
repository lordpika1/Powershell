<#
.Description
Requires tesseract ocr to be installed.
Uses tesseract for OCR to try an catch the QR code phishing attempts. Typically with "scan this code".
Keep in mind storage space.
tesseract is not perfect and may not get the right text/characters. keep that in mind.
#>

#need build out remove old stuff
#Get-ChildItem -Directory -Recurse -Depth 5 -Force | Where-Object {$_.fullname -match "2023-10-11"} | Remove-Item -Force -Recurse

############ connection setup ###############
$appID = "appid"
$tenantID = "tenant id"
$securePWD = "client secret"

$SecuredPasswordPassword = ConvertTo-SecureString -String $securePWD -AsPlainText -Force

$ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $appID, $SecuredPasswordPassword


#change this to one less than the amount of cpus at minimum. Adjust as necessary.
$maxjobs = 5
Write-Host "Max Jobs: $maxjobs"

Start-Transcript "/scripts/$($MyInvocation.MyCommand.Name).log"
Connect-MgGraph -TenantId $tenantID -ClientSecretCredential $ClientSecretCredential -NoWelcome



############## Time Stuff ########################
$scriptStartTime = (get-date).ToUniversalTime()

$lastRunPath = "/scripts/$($MyInvocation.MyCommand.Name)_lastrun.txt"

#adjust this as you see fit.
$lastRun = ((Get-Date).AddHours(-3)).ToUniversalTime()



$AllMGUSers = (Get-MgUser -Filter 'assignedLicenses/$count ne 0' -ConsistencyLevel eventual -CountVariable licensedUserCount -Al).UserPrincipalName | select -Unique

$allUsers = $AllMGUSers |sort




$BasePath = "/scripts/email/ImageOCRProcessing"

if (Test-Path $BasePath){

New-Item -Path $BasePath -ItemType Directory -Force

}

<#
$base64list = @()
foreach ($user in $allUsers){
$encodedBytes = [System.Text.Encoding]::UTF8.GetBytes($user)
$encodedText = [System.Convert]::ToBase64String($encodedBytes)
$base64list += $encodedText
}#>

#create the csvs under the base path. make sure to have phrases on the first line as it's the column header/title.
Write-Output "$(get-date) - Adding manual entries from local csv"
$targetListManualcsv = "$BasePath/targetListManual.csv"
$targetListManual = Import-Csv $targetListManualcsv

Write-Output "$(get-date) - Adding test entries from local csv"
$targetListTestcsv = "$BasePath/targetListTest.csv"
$targetListTest = Import-Csv $targetListTestcsv



$scriptblock = {
param($users,$lastrun,$targetListManual, $targetListTest)

########## Graph Connection #######
$appID = "appid"
$tenantID = "tenant id"
$securePWD = "client secret"

$SecuredPasswordPassword = ConvertTo-SecureString -String $securePWD -AsPlainText -Force

$ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $appID, $SecuredPasswordPassword

Connect-MgGraph -TenantId $tenantID -ClientSecretCredential $ClientSecretCredential -NoWelcome > $null
########## Graph Connection #######

#where you want the images and what not stored.
$BasePath = "/scripts/email/ImageOCRProcessing"



#set lookback time and format it. 
$date = (get-date $lastrun).ToUniversalTime().ToString("+yyyy-MM-ddTHH:mm:ss.0000000Z")

foreach ($user in $users){
$deleteCount = 0
$testCount = 0
Start-Transcript "$BasePath/$user/$((get-date).ToString("yyyy-MM-dd"))_transcript.txt" -Append -Force > $null

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
    if (!(Test-Path $BasePath/$user)){

    New-Item "$BasePath/$user" -ItemType Directory > $null
    }
    
    foreach ($message in $AllMessages){
            $messageDeleted = $false
            $messageDate = $message.ReceivedDateTime.ToString("yyyy-MM-dd")

            #if the message is already deleted, let's move on
            if ($message.ParentFolderId -match $DeletedItemsID){
            #Write-Host "$($message.Subject) already deleted"
            #Write-Host "Message ID: $($message.Id)"
            continue
            }
            #CHANGE This to your environment.
            if ($message.From.EmailAddress.Address -match 'yourFromEmail@email.com'){
            
            continue
            }
            
            #test if the date folder for the user has been created
            if (!(Test-Path "$BasePath/$user/$messageDate")){

            New-Item "$BasePath/$user/$messageDate" -ItemType Directory > $null
            }

            #folder message is stored in currently.
            $folderName = $null
            $folderName = ($mailFolders | Where-Object {$_.Id -match $message.ParentFolderId}).DisplayName

            #if it's going to be deleted already no point in continuing.
            #if ($messageDeleted){continue}
            $attachments = $null            
            $attachments = Get-MgUserMessageAttachment -MessageId $message.Id -UserId $user

            if ($attachments -eq $null){continue}
            if ($attachments.count -eq 0){continue}

            if (!(Test-Path "$BasePath/$user/$messageDate/$($message.Id)")){

            New-Item "$BasePath/$user/$messageDate/$($message.Id)" -ItemType Directory > $null
            }else{
            
            #This is so we don't continue to rewrite/grab attachments. that adds time and storage. 
            continue 
            
            }

            foreach ($attachment in $attachments){
            $attachmentPath = "$BasePath/$user/$messageDate/$($message.Id)"
            
            if ($attachment.ContentType -imatch "image"){
                    #Write-Output "Writing Image to Disk - $($attachment.name)<br>"
                    #####
                    #Convert from Base64 and write to file.
                    #####
                    $bytes = [convert]::FromBase64String($attachment.AdditionalProperties.contentBytes)
                    [io.file]::writeallbytes("$attachmentPath/$($attachment.name)", $bytes)
                    
                    #use tesseract to grab text from image and write it to text file with image name.txt. tesseract adds .txt to file output automatically.
                    #Write-Output "Running Tesseract now<br>"
                    tesseract $attachmentPath/$($attachment.name) $attachmentPath/$($attachment.name)

                    #Filter 1
                    ########################
                    #manual targeted phrases
                    ########################
                    foreach ($phrase in $targetListManual.phrases){
                        #May need to be reworked as time/more phrases are added.
                        if (Select-String -Path "$attachmentPath\$($attachment.name).txt" -Pattern "$($phrase -replace "\.","\.")"){
                                Write-Output "$user<br>"
                                Write-Output "Subject: $($message.Subject)<br>"
                                Write-Output "Matching Phrase: $($phrase)<br>"
                                Write-Output "Subject: $($message.Subject)" | Add-Content "$BasePath/$user/$((get-date).ToString("yyyy-MM-dd")).txt" > $null
                                Write-Output "Deleted items ID: $DeletedItemsID" | Add-Content "$BasePath/$user/$((get-date).ToString("yyyy-MM-dd")).txt" > $null
                                Write-Output "Inbox ID: $InboxID" | Add-Content "$BasePath/$user/$((get-date).ToString("yyyy-MM-dd")).txt" > $null
                                Write-Output "Message ID: $($message.Id)" | Add-Content "$BasePath/$user/$((get-date).ToString("yyyy-MM-dd")).txt" > $null

                                $moveResults = Move-MgUserMessage -MessageId $message.Id -UserId $user -DestinationId $DeletedItemsID -Confirm:$false
                                Write-Output "New Message ID: $($moveResults.Id)" | Add-Content "$BasePath/$user/$((get-date).ToString("yyyy-MM-dd")).txt" > $null
                                #Write-Output "New Message ID: $($moveResults.Id)<br>"
                                $deleteCount++
                                $messageDeleted = $true
                                break
                
                        }
            }
            
            }
            
            
            }



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
    Write-Host "i: $i"
    Write-Host "Endrange: $endrange"
    Start-Job -ScriptBlock $scriptblock -ArgumentList $allUsers[$i..[math]::Round($endrange,0)],$lastRun, $targetListManual, $targetListTest
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
