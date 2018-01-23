Import-Module ActiveDirectory
# 
$comps = @(Get-ADComputer -SearchBase "ldap\path" -Filter "*")
$path = "path\to\save\to.csv"
$maxjobs = 10
Remove-Item $path -ErrorAction SilentlyContinue
Remove-Item -Path path\to\save\to\ErrorLogs\*.* -ErrorAction SilentlyContinue
Write-Output "Computer,Task,NextRunTime,Status,LogonMode,LastRunTime,LastResult,TaskToRun,ScheduleTaskState,RunAsUser,Schedule,ScheduleType,StartTime,EndTime,Days,Months,RepeatEvery,RepeatUntilTime,RepeatUntilDuration,RepeatStopIfStillRunning" | Add-Content $path
$scriptblock = {
    PARAM($scomputer);
    $tasks = schtasks /s "$scomputer" /query /fo list 2>>"path\to\save\to$scomputer.error"
    $limit = $false
    $split = @()
    $taskname = [System.Collections.ArrayList]@()
    #taskname cast as array
########################Parse List of Tasks on computer to get Root (\) Folder only#################################
    foreach ($t in $tasks){
    if ($t -match "^TaskName:\s+\\" -and !($t -match "^TaskName:\s+\\.*\\")){
    #Write-Host $t
    $split += $t -replace "TaskName:\s+\\",""
    }
        #switch -Regex ($t){
        #"Folder: \\$" {Write-Host $t ($t.ToString()).count
        #$limit = $true
        #}#end switch
        #}#end contidion 1
      <# Old Code   
        if ($t -match "Folder: \\$" -and $limit -eq $false){
        #write-host $t
        }elseif($t -match "Folder: \\*" -and $limit -eq $false){
        #
        $limit = $true
        #Write-Host "Matching First...ElseIf $t"
        }elseif($limit -eq $false){
        #Write-Host "$t"
        $split += $t -replace "=","" -replace "  "," " -split "`n"
        }
        #>

    }#end foreach t in task
##################################################Split list of tasks to obtain name only##############################
    foreach ($s in $split){
    $taskname += ($s -replace "TaskName\s+Next Run Time\s+Status" -split " *\s+[0-9]*[0-9]*/*[0-9]*[0-9]*/*[0-9]*[0-9]*[0-9]*[0-9]* [0-9]*[0-9]*:*[0-9]*[0-9]*:*[0-9]*[0-9]*\s+[N/A]*[AM]*[PM]*\s+[Ready|Queued]*\s")
    }

###############################################Convert $taskname to proper array collection#############################
    $collect = {$taskname}.Invoke() #Convert $taskname to array collection. Allows .Remove() usage
    $count = $collect.Count
    for ($i=0;$i -le $Count;$i++){
        #Write-Host "Count $i....$($collect[$i])"
        if ($collect[$i] -match "^\s+$"){
            $removal = $collect.Remove($collect[$i])
            #remove Array entries with spaces only
            #Write-Host "Delete Count $i....$($collect[$i])"
            }
    
        }#end For loop to remove array entries with spaces only
########################################Foreach task in $collect + parse the info that is returned########################        
    foreach ($t in $collect){
     $NextRunTime=$status=$LogonMode = $LastRunTime = $LastResult = $TaskToRun = $Schedule = $RunAsUser = $Schedule=$ScheduleType=$StartTime=$EndTime=$Days=$Months=$null
     $RepeatEvery=$RepeatUntilTime=$RepeatUntilDuration=$RepeatStopIfStillRunning=$taskdetails=$ScheduleTaskState = $null
    
    if (!($t -match "^\s+")){
        $taskdetails = (schtasks /s "$scomputer" /tn "$t" /fo list /v 2>>"path\to\saveto\Get-ScheduledTaskList$scomputer.error") #query computer $c for taskname $t to get taskdetails
        }
        foreach ($detail in $taskdetails){
            
            switch -Regex ($detail) {
                "HostName:"{#Write-Host $c.name
                        }
                "TaskName:"{#Write-Host $t
                        }
                "Next Run Time:"{$NextRunTime = $detail -replace "Next Run Time:\s+",""
                        #Write-Host "Next Run Time: $NextRunTime"
                        }
                "Status:"{$status = $detail -replace "Status:\s+",""
                        #Write-Host $status
                        }
                "Logon Mode:"{$LogonMode = $detail -replace "Logon Mode:\s+",""
                        #Write-Host $LogonMode
                        }
                "Last Run Time:"{$LastRunTime = $detail -replace "Last Run Time:\s+",""
                        #Write-Host $LastRunTime 
                        }
                "Last Result:"{$LastResult = $detail -replace "Last Result:\s+",""
                        #write-host $LastResult
                        }
                "Author:"{}
                "Task To Run:"{$TaskToRun = $detail -replace "Task To Run:\s+",""
                        #write-host $TaskToRun
                        }
                "Start In:"{}
                "Comment:"{}
                "Scheduled Task State:"{$ScheduleTaskState = $detail -replace "Scheduled Task State:\s+"}
                "Idle Time:"{}
                "Power Management:"{}
                "Run As User:"{$RunAsUser = $detail -replace "Run As User:\s+",""}
                "Delete Task If Not Resecheduled:"{}
                "Stop Task if Runs X Hours and X Mins:"{}
                "Schedule:"{$Schedule = $detail -replace "Schedule:\s+"}
                "Schedule Type:"{$ScheduleType = $detail -replace "Schedule Type:\s+",""}
                "Start Time:"{$StartTime = $detail -replace "Start Time:\s+",""}
                "End Date:"{$EndTime = $detail -replace "End Date:\s+",""}
                "Days:"{$Days = $detail -replace "Days:\s+","" -replace ",",":"}
                "Months:"{$Months =  $detail -replace "Months:\s+",""}
                "Repeat: Every:"{$RepeatEvery = $detail -replace "Repeat: Every:\s+","" -replace ",",":"}
                "Repeat: Until: Time:"{$RepeatUntilTime = $detail -replace "Repeat: Until: Time:\s+",""}
                "Repeat: Until: Duration:"{$RepeatUntilDuration = $detail -replace "Repeat: Until: Duration:\s+"-replace ",",":"}
                "Repeat: Stop If Still Running:"{$RepeatStopIfStillRunning = $detail -replace "Repeat: Stop If Still Running:\s+"}
                }#End Switch
                
        }#end foreach Detail in Taskdetail
        write-output ("$scomputer,$t,$NextRunTime,$status,$LogonMode,$LastRunTime,$LastResult,$TaskToRun,$ScheduleTaskState,$RunAsUser,$Schedule,$ScheduleType,$StartTime,$EndTime,$Days,$Months,$RepeatEvery,$RepeatUntilTime,$RepeatUntilDuration,$RepeatStopIfStillRunning")
    }#end foreach t(taskname) in the collect variable

}#end scriptblock


Foreach($computer in $comps) {
#Write-Host $computer
$Check = $false
While($Check -eq $false) {

if((Get-Job -State 'Running').Count -lt $maxjobs)
    {
    Start-Job -ScriptBlock $scriptblock -ArgumentList $computer.name -Name $computer.name 
    $Check = $true
    } #end start job stuff
}<#end while loop. While stops once check is NOt equal to false. Check is set to false at beginning of foreach and set to true if the number of 
    jobs is less than the $maxjobs. So if there are 10 jobs with a state of running check will remain false until one job completes, which at that point the count
    of running jobs is less then $maxjobs.    
    #>
  
 } 
 
 do{
 #Write-Host "Checking Job State"
 Write-host "Current Jobs Running:" (Get-Job -State Running).count 
 if((Get-Job -State 'Running').count -eq 0) {break}
 Start-Sleep 5
 }while ((Get-Job -State 'Completed') -ne $true)#>

 foreach($computer in $comps){
 #Write-Host $computer
 Write-Output (Receive-Job -Name $computer.name) | Add-Content $path
 Start-Sleep 2

 
 }
