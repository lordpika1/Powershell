<#
.Description
This makes up for Exchange Online's default spam/phish filter and you're not willing to pay extra for safeattachments.
This script is meant to be ran on a Windows box (for the paths). You'll need to grant consent for mail.readwrite,directory.read.all to an Enterpise Application in Entra ID.
This uses the Client sercrets under App registrations in Entra ID
I like to default to scripts cuz you know it be a script. :)
With this set up cpu usage starts high but doesn't peg it like the other version.
#>

############ connection setup ###############
$appID = "your app id"
$tenantID = "your tenant id"
$securePWD = "your special super secret client secret"


$SecuredPasswordPassword = ConvertTo-SecureString -String $securePWD -AsPlainText -Force

$ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $appID, $SecuredPasswordPassword


$maxjobs = $([int]$env:NUMBER_OF_PROCESSORS) - 1

Start-Transcript "c:\scripts\attachments\$((get-date).ToString("yyyy-MM-dd")).txt" -Append -Force > $null
Connect-MgGraph -TenantId $tenantID -ClientSecretCredential $ClientSecretCredential -NoWelcome


############## Time Stuff ########################
$scriptStartTime = (get-date).ToUniversalTime()

$lastRunPath = "c:\scripts\$($MyInvocation.MyCommand.Name)_lastrun.txt"


#your choice. adjust as you see fit.
#if you use the last run path (it has the last run time) this will start the recieved time search to the 12 hours before the last run time.
#$lastRun = ((Get-Date $lastRunPath).AddHours(-12)).ToUniversalTime()
#look at the last 12 hours.
$lastRun = ((Get-Date).AddHours(-12)).ToUniversalTime()


$AllMGUSers = (Get-MgUser -Filter 'assignedLicenses/$count ne 0' -ConsistencyLevel eventual -CountVariable licensedUserCount -Al).UserPrincipalName | select -Unique

$allUsers = $AllMGUSers | sort

$scriptblock = {
param($users,$lastrun)

########## Graph Connection #######
$appID = "your app id"
$tenantID = "your tenant id"
$securePWD = "your special super secret client secret"


$SecuredPasswordPassword = ConvertTo-SecureString -String $securePWD -AsPlainText -Force

$ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $appID, $SecuredPasswordPassword

Connect-MgGraph -TenantId $tenantID -ClientSecretCredential $ClientSecretCredential -NoWelcome > $null
########## Graph Connection #######


$attachmentDate = (get-date).ToString("yyyy-MM-dd")

$attachmentBasePath = "c:\scripts\attachments"

#set lookback time and format it.
$date = (get-date $lastrun).ToUniversalTime().ToString("+yyyy-MM-ddTHH:mm:ss.0000000Z")
foreach ($user in $users){
Start-Transcript "c:\scripts\attachments\$user\$((get-date).ToString("yyyy-MM-dd"))_transcript.txt" -Append -Force > $null
$deleteCount = 0
#Write-Host $user
#get all the messages for the time frame and only those that have attachments
$AllMessages = $null
$AllMessages = (Get-MgUserMessage -UserId $user -Filter "(ReceivedDateTime ge $date) AND (HasAttachments eq true)" -All)

if ($AllMessages -eq $null){continue}
if ($AllMessages.count -eq 0){continue}

#Write-Output "$user,Total Messages:$($AllMessages.count)<br>"
#get the deleted items folder id
$mailFolders = $null
$mailFolders = Get-MgUserMailFolder -All -UserId $user
if ($mailFolders -eq $null){continue}

$DeletedItemsID = ($mailFolders | Where-Object {$_.DisplayName -match "Deleted Items"}).Id 
$InboxID = ($mailFolders | Where-Object {$_.DisplayName -imatch "Inbox"}).Id 

    #Create folder for user
    if (!(Test-Path $attachmentBasePath\$user)){

    New-Item "$attachmentBasePath\$user" -ItemType Directory
    }
    

    #work through each message
    foreach ($message in $AllMessages){
    
    if ($message.ParentFolderId -match $DeletedItemsID){
    #Write-Host "$($message.Subject) already deleted"
    #Write-Host "Message ID: $($message.Id)"
    continue
    }
    $messageDate = $message.ReceivedDateTime.ToString("yyyy-MM-dd")



            #get all the attachments for a specific message
            $allAttachments = Get-MgUserMessageAttachment -UserId $user -MessageId $message.id
            #work through each attachment
            foreach ($attachment in $allAttachments){

            if (!("c:\scripts\attachments\$user\$((get-date).ToString("yyyy-MM-dd")).txt")){
            
            New-Item "c:\scripts\attachments\$user\$((get-date).ToString("yyyy-MM-dd")).txt" -ItemType file

            
            }
                    
                    #Filter 1

                    if ($attachment.Name -imatch "attachmentName"){

                    #Skipping this attachment name. Dependant on your environment
                    continue

                    }

                    #set the attachment path to user\receivedDate
                    $attachmentPath = "$attachmentBasePath\$user\$messageDate"

                    if ($attachment.ContentType -imatch "html|htm" -or $attachment.Name -imatch "html|htm"){


                        if (!(Test-Path "$attachmentBasePath\$user\$messageDate")){

                        #if the recieveddate folder isn't created, create it.

                        $newItemOutput = New-Item "$attachmentBasePath\$user\$messageDate" -ItemType Directory
                        }

                        if (Test-Path "$attachmentPath\$($attachment.name)"){
                        #if the attachment is already there, no need to rewrite the file. It obviously hasn't matched any filters.
                        continue
                        
                        }

                        #####
                        #Convert from Base64 and write to file.
                        #####
                        $bytes = [convert]::FromBase64String($attachment.AdditionalProperties.contentBytes)
                        [io.file]::writeallbytes("$attachmentPath\$($attachment.name)", $bytes)

                        ############################################
                        ########## Pattern matching ################
                        ############################################

                        #Filter 2
                        #Use this to skip attachments that are legit. Just looking at the contents of the file. You may need multiple.
                        if (Select-String -Path "$attachmentPath/$($attachment.name)" -Pattern 'your pattern here.'){
                        
                        
                        continue
                    
                    
                        }

                        #Filter 3
                        #Common sus/malicious strings I've seen in htm(l) attachments that should be filtered out. MSFT doesn't allow exchange transport rules to handle these.
                        if (Select-String -Path "$attachmentPath\$($attachment.name)" -Pattern "<script|document\.write\(|atob\(|window\.atob|String\.fromCharCode|window.location.replace\(|\.ru/"){
                            
                 

                        Write-Output "Subject: $($message.Subject)<br>"
                        Write-Output "Attachment: $($attachment.name)<br>"
                        Write-Output "Subject: $($message.Subject)" | Add-Content "c:\scripts\attachments\$user\$((get-date).ToString("yyyy-MM-dd")).txt" > $null
                        Write-Output "Deleted items ID: $DeletedItemsID" | Add-Content "c:\scripts\attachments\$user\$((get-date).ToString("yyyy-MM-dd")).txt" > $null
                        Write-Output "Inbox ID: $InboxID" | Add-Content "c:\scripts\attachments\$user\$((get-date).ToString("yyyy-MM-dd")).txt" > $null
                        Write-Output "Message ID: $($message.Id)" | Add-Content "c:\scripts\attachments\$user\$((get-date).ToString("yyyy-MM-dd")).txt" > $null

                        Move-MgUserMessage -MessageId $message.Id -UserId $user -DestinationId $DeletedItemsID -Confirm:$false > $null
                        New-Item -Path "$attachmentPath\Deleted" -ItemType Directory > $null
                        $moveResults = ""
                        $moveResults = Move-Item -Path "$attachmentPath\$($attachment.name)" -Destination "$attachmentPath\Deleted\$($attachment.name)" -ErrorAction Continue -Force > $null

                        $deleteCount++
                 
                        }




                    }
                }

        }
        
        if ($deleteCount -ne 0){
        Write-Output "$deleteCount deleted for $user<br><br>"
        }

        Stop-Transcript > $null
    }

Disconnect-MgGraph > $null
}

$receiveJobDetails = $null

$count = 0
$dividingby = $($allUsers.Count/$maxjobs)

For ($i=0; $i -le $($allUsers.Count) ; $i+=$($allUsers.Count/$maxjobs)){
    $endrange = $i + $dividingby
    Write-Output "i: $i"
    Write-Output "endrange: $endrange"
    Start-Job -ScriptBlock $scriptblock -ArgumentList $allUsers[$i..[math]::Round($endrange,0)],$lastRun
    Start-Sleep 2
}
$sleepCount = 0



do{
 #Write-Host "Checking Job State"
 Write-host "Current Jobs Running:" (Get-Job -State Running).count 
 Write-host "Current Jobs NotStarted:" (Get-Job -State NotStarted).count
 Write-Output "Sleep Count: $sleepCount"
 Write-Output "Total time: $([math]::Round(((get-date).ToUniversalTime() - $scriptStartTime).TotalMinutes,2))"
 #if((Get-Job -State 'Running').count -eq 0) {break}

 $receiveJobDetails += get-job -State Completed -HasMoreData $true | Receive-Job * 

 Start-Sleep 5
 #lets check on those long jobs
        $longtimejobs = get-job -State Running
        foreach ($longtimejob in $longtimejobs){


        if(((get-date) - (get-date $longtimejob.PSBeginTime)).TotalMinutes -gt 25){

        #Write-Output "Killing $($longtimejob.Name)"

        #Stop-Job $longtimejob -Confirm:$false

        }

        }
 $sleepCount++
 }while (((Get-Job -State 'NotStarted').count -gt 0 -or (Get-Job -State 'Running').count -gt 0) -and ($sleepCount -le 245 ))

$receiveJobDetails += Get-Job -State 'Running' | Stop-Job -confirm:$false -verbose



$receiveJobDetails += Receive-Job * 



$receiveJobDetails += "<br><b> Windows V2 </b><br>"
$receiveJobDetails += "<br>Job count: $((get-job).count)<br>"
$receiveJobDetails +=  "Total Users: $($allUsers.count)"
$receiveJobDetails += "<br>Total time: $([math]::Round(((get-date).ToUniversalTime() - $scriptStartTime).TotalMinutes,2)) minutes"
$receiveJobDetails
if ($receiveJobDetails){

#adjust this as necessary
Send-MailMessage -to email@email.com -From email@email.com -Subject "Email Deletion Results" -SmtpServer "serverip" -BodyAsHtml -Body ($receiveJobDetails | Out-String) -Verbose

}

#only set the date if we complete the script.

Remove-Item $lastRunPath


Write-Output "Total Users: $($allUsers.count)"
write-output "$scriptStartTime"| Add-Content $lastRunPath -Force
Write-Output "End time: $((get-date))"
Write-Output "Total time: $(((get-date).ToUniversalTime() - $scriptStartTime).TotalMinutes)"