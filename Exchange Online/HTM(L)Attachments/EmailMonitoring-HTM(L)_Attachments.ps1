<#
.Description
This makes up for Exchange Online's default spam/phish filter and you're not willing to pay extra for safeattachments.
This script is meant to be ran on a linux box. You'll need to grant consent for mail.readwrite,directory.read.all to an Enterpise Application in Entra ID.
This uses the Client sercrets under App registrations in Entra ID
Paths are set up to run on a linux box. I like to default to scripts cuz you know it be a script. :)
Can be quite cpu intensive. Adjust max jobs/vm specs as needed. 
#>
#if you want to find the files that weren't deleted
#grep -R -i --exclude-dir=Deleted *.htm ./ -l

############ connection setup ###############
$appID = "your app id"
$tenantID = "your tenant id"
$securePWD = "your special super secret client secret"

$SecuredPasswordPassword = ConvertTo-SecureString -String $securePWD -AsPlainText -Force

$ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $appID, $SecuredPasswordPassword


#set the max number of jobs you want running at one time.
$maxjobs = 20

Start-Transcript "/scripts/attachments/$((get-date).ToString("yyyy-MM-dd")).txt" -Append -Force > $null
Connect-MgGraph -TenantId $tenantID -ClientSecretCredential $ClientSecretCredential -NoWelcome


############## Time Stuff ########################
$scriptStartTime = (get-date).ToUniversalTime()

$lastRunPath = "/scripts/$($MyInvocation.MyCommand.Name)_lastrun.txt"


#change this to how far back you want to look. 
$lastRun = ((Get-Date).AddHours(-4)).ToUniversalTime()


#grab all licensed users
$AllMGUsers = (Get-MgUser -Filter 'assignedLicenses/$count ne 0' -ConsistencyLevel eventual -CountVariable licensedUserCount -Al).UserPrincipalName | select -Unique

$allUsers = $AllMGUsers

$scriptblock = {
param($user,$lastrun)
$deleteCount = 0
########## Graph Connection #######
$appID = "your app id"
$tenantID = "your tenant id"
$securePWD = "your special super secreat client secret"

$SecuredPasswordPassword = ConvertTo-SecureString -String $securePWD -AsPlainText -Force

$ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $appID, $SecuredPasswordPassword
Start-Transcript "/scripts/attachments/$user/$((get-date).ToString("yyyy-MM-dd"))_transcript.txt" -Append -Force > $null
Connect-MgGraph -TenantId $tenantID -ClientSecretCredential $ClientSecretCredential -NoWelcome > $null
########## Graph Connection #######


$attachmentDate = (get-date).ToString("yyyy-MM-dd")

$attachmentBasePath = "/scripts/attachments"

#set lookback time and format it. dumb af format
$date = (get-date $lastrun).ToUniversalTime().ToString("+yyyy-MM-ddTHH:mm:ss.0000000Z")

#Write-Host $user
#get all the messages for the time frame and only those that have attachments
$AllMessages = $null
$AllMessages = (Get-MgUserMessage -UserId $user -Filter "(ReceivedDateTime ge $date) AND (HasAttachments eq true)" -All)

#if there's nothing to process might as well stop
if ($AllMessages -eq $null){exit}
if ($AllMessages.count -eq 0){exit}

#Get all the mail folders for the user
$mailFolders = Get-MgUserMailFolder -All -UserId $user

$DeletedItemsID = ($mailFolders | Where-Object {$_.DisplayName -match "Deleted Items"}).Id 
$InboxID = ($mailFolders | Where-Object {$_.DisplayName -imatch "Inbox"}).Id 

    #Create folder for user
    if (!(Test-Path $attachmentBasePath/$user)){

    New-Item "$attachmentBasePath/$user" -ItemType Directory
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

                if (!("/scripts/attachments/$user/$((get-date).ToString("yyyy-MM-dd")).txt")){
                
                #logging file
                New-Item "/scripts/attachments/$user/$((get-date).ToString("yyyy-MM-dd")).txt" -ItemType file

            
                }
                    
                    #Filter 1

                    if ($attachment.Name -imatch "attachmentName"){

                    #Skipping this attachment name. Dependant on your environment
                    continue

                    }

                    #set the attachment path to user\receivedDate
                    $attachmentPath = "$attachmentBasePath/$user/$messageDate"

                    #match on contentype or of the name contains html or htm.
                    if ($attachment.ContentType -imatch "html|htm" -or $attachment.Name -imatch "html|htm"){


                        if (!(Test-Path "$attachmentBasePath/$user/$messageDate")){

                        #if the recieveddate folder isn't created, create it.

                        $newItemOutput = New-Item "$attachmentBasePath/$user/$messageDate" -ItemType Directory
                        }

                        if (Test-Path "$attachmentPath/$($attachment.name)"){
                        #if the attachment is already there, no need to rewrite the file. It obviously hasn't matched any filters.
                        continue
                        
                        }

                        #####
                        #Convert from Base64 and write to file.
                        #####
                        $bytes = [convert]::FromBase64String($attachment.AdditionalProperties.contentBytes)
                        [io.file]::writeallbytes("$attachmentPath/$($attachment.name)", $bytes)

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
                        if (Select-String -Path "$attachmentPath/$($attachment.name)" -Pattern "<script|document\.write\(|atob\(|window\.atob|String\.fromCharCode|window.location.replace\(|\.ru/"){
                            
                 

                        Write-Output "Subject: $($message.Subject)<br>"
                        Write-Output "Attachment: $($attachment.name)<br>"
                        Write-Output "Subject: $($message.Subject)" | Add-Content "/scripts/attachments/$user/$((get-date).ToString("yyyy-MM-dd")).txt" > $null
                        Write-Output "Deleted items ID: $DeletedItemsID" | Add-Content "/scripts/attachments/$user\$((get-date).ToString("yyyy-MM-dd")).txt" > $null
                        Write-Output "Inbox ID: $InboxID" | Add-Content "/scripts/attachments/$user/$((get-date).ToString("yyyy-MM-dd")).txt" > $null
                        Write-Output "Message ID: $($message.Id)" | Add-Content "/scripts/attachments/$user/$((get-date).ToString("yyyy-MM-dd")).txt" > $null

                        Move-MgUserMessage -MessageId $message.Id -UserId $user -DestinationId $DeletedItemsID -Confirm:$false > $null
                        New-Item -Path "$attachmentPath/Deleted" -ItemType Directory > $null
                        Move-Item -Path "$attachmentPath/$($attachment.name)" -Destination "$attachmentPath/Deleted/$($attachment.name)" -ErrorAction Continue -Force > $null

                        $deleteCount++
                 
                        }




                    }
                }

        }
if ($deleteCount -ne 0){
Write-Output "$deleteCount deleted for $user<br><br>"
}
Disconnect-MgGraph > $null
}



##############################
### Get this party started ###
##############################
$receiveJobDetails = $null
$count = 0
foreach ($user in $allUsers){

    $Check = $false
    While($Check -eq $false) {

        if((Get-Job -State 'Running').Count -lt $maxjobs){
        Start-Job -ScriptBlock $scriptblock -Name "$user" -ArgumentList $user,$lastRun
        $Check = $true
        } #end start job stuff

    }<#end while loop. While stops once check is NOt equal to false. Check is set to false at beginning of foreach and set to true if the number of 
        jobs is less than the $maxjobs. So if there are 10 jobs with a state of running check will remain false until one job completes, which at that point the count
        of running jobs is less then $maxjobs.    
        #>
if ($count%$maxjobs -eq 0){Start-Sleep ($maxjobs/3)}
$count ++

#this is to clean up jobs as we go. 
$receiveJobDetails += Get-Job -State Completed -HasMoreData $true | Receive-Job

#remove those jobs that don't have extra data. 
Get-job -HasMoreData $false | Remove-Job -Force



}
$sleepCount = 0



do{
 #Write-Host "Checking Job State"
 Write-host "Current Jobs Running:" (Get-Job -State Running).count 
 Write-host "Current Jobs NotStarted:" (Get-Job -State NotStarted).count
 Write-Output "Sleep Count: $sleepCount"
 Write-Output "Total time: $([math]::Round(((get-date).ToUniversalTime() - $scriptStartTime).TotalMinutes,2))"
 #if((Get-Job -State 'Running').count -eq 0) {break}

 $receiveJobDetails += Receive-Job * 

 Start-Sleep 5
 #lets check on those long jobs
        $longtimejobs = get-job -State Running
        foreach ($longtimejob in $longtimejobs){


        if(((get-date) - (get-date $longtimejob.PSBeginTime)).TotalMinutes -gt 10){

        Write-Output "Killing $($longtimejob.Name)"

        Stop-Job $longtimejob -Confirm:$false

        }

        }
 $sleepCount++
 }while (((Get-Job -State 'NotStarted').count -gt 0 -or (Get-Job -State 'Running').count -gt 0) -and ($sleepCount -le 45 ))

Stop-Job * -confirm:$false


$receiveJobDetails += Receive-Job * 

$receiveJobDetails
$receiveJobDetails += "<br><br>"
$receiveJobDetails +=  "Total Users: $($allUsers.count)"
$receiveJobDetails += "<br>Total time: $([math]::Round(((get-date).ToUniversalTime() - $scriptStartTime).TotalMinutes,2)) minutes"

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

