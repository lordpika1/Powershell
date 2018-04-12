<#
.DESCRIPTION
Creates a status screen of nases bases on ping response.
.NOTES
Attempting to learn some drawing in .net
#>
Start-Transcript "C:\scripts\nas.txt" -Force
Add-Type -AssemblyName System.Windows.Forms
$timer = New-Object System.Windows.Forms.Timer

function Click(){
Write-Host "CLiCK!"
$form.WindowState = "Normal";
$form.Show();
$form.BringToFront();
$form.MinimizeBox=$false;
$form.Visible = $true
}
#$timer.Enabled = $true

#$proaffin =(Get-Process -Id $pid)
#$proaffin.ProcessorAffinity = 4

$dcs = @((Get-ADDomainController -Filter *).name)

$nases ="list of nases (your choice on how to pull them)"
$timer.add_tick({
$form.Text = "Network Watch " + (get-date)
#(Get-Variable -Name "nases" -ValueOnly -scope Global)
Write-Host "disabling timer"
#disable timer so it can complete work
#https://stackoverflow.com/questions/4962172/why-does-a-system-timers-timer-survive-gc-but-not-system-threading-timer
$timer.Enabled = $false
[System.Windows.Forms.Application]::DoEvents()
$maxjobs = 10
foreach ($nas in $nases ){
#keep $timer from being garbage collected
Write-Host $timer.GetType().FullName
$sb = {param($nas)
Test-Connection $nas -Quiet -Count 2
}
[System.Windows.Forms.Application]::DoEvents()
$Check = $false
While($Check -eq $false) {

if((Get-Job -State 'Running').Count -lt $maxjobs)
    {
    Start-Job -Name $nas -ScriptBlock $sb -ArgumentList $nas
    $Check = $true
    } #end start job stuff
    [System.Windows.Forms.Application]::DoEvents()
}

}

 

do{
 #Write-Host "Checking Job State"
 #Write-host "Current Jobs Running:" (Get-Job -State Running).count "Name:"(Get-Job -State Running).Name
 if((Get-Job -State 'Running').count -eq 0) {break}
 [System.Windows.Forms.Application]::DoEvents()
 Start-Sleep -Milliseconds 50
 }while ((Get-Job -State 'Completed') -ne $true)

[System.Windows.Forms.Application]::DoEvents()
foreach ($nas in $nases){
if (!(Receive-Job $nas)){
            (Get-Variable -name "$nas`_label" -ValueOnly).BackColor = "Red"
            (Get-Variable -name "$nas`_label" -ValueOnly).ForeColor = "Yellow"
            #write-host "Bad Connection"
            $badStart = Get-Date
            (Get-Variable -name "$nas`_label" -ValueOnly).Text = "$($nas.ToUpper())`nBad Connection @`n$badStart"
            (Get-Variable -name "$nas`_label" -ValueOnly).Update()
            }else{
            (Get-Variable -name "$nas`_label" -ValueOnly).BackColor = "LightGreen"
            (Get-Variable -name "$nas`_label" -ValueOnly).ForeColor = "Black"
            (Get-Variable -name "$nas`_label" -ValueOnly).Update()
            }
}





Write-Host "enabling timer"
$timer.Enabled = $true

Remove-Job * -Force

$form.BringToFront()
})#end add tick
$timer.Interval = 1000
Write-Host $timer.Interval
$Form = New-Object system.Windows.Forms.Form
New-Variable -Scope Global -Name "term" -Force -Value $false
#$term = $false
$Form.Text = "Network Watch"
$Form.AutoSize = $true
$Form.AutoSizeMode = "GrowAndShrink"
$Form.WindowState = "Maximized"
$Form.ControlBox = $true
$Form.BackColor = "LightGreen"
$form.Focus()

$form.ShowInTaskbar = $true
$form.add_click({Click})

#$form.CancelButton = $true
New-Variable -Scope Global -Name "ProcessID" -Value $pid -Force
#$processid = $pid
$form.add_FormClosing({stop-process $pid -force;$Form.Close();$Form.Dispose();stop-process $processid -Force -PassThru;})
#Set-Variable -Name "term" -Value $true -Force -Scope Global;for formclosing
#$Form.ActivateControl()

#############VARIABLE SETUP##########
$nextrow = $reset = $false
$count = $widthtotal = 0
$heightcount = 1
New-Variable -Name "tilesToShow" -Value 2 -Scope Global -Force
New-Variable -Name "heighttotal" -Scope Global -Force
#######################################



#$tilesToShow = 6
#####create tilestoshow dynamically ######
#$tilesToShow = $nases.count
$termed = $form.formclosing

$Form.Show()
$Form.Activate()
#$form.ActivateControl()
$form.BringToFront()
$Form.UseWaitCursor = $false

#set drawing location. Have to initialize new object(x,y)
#(Get-Variable -name "$nas`_label" -ValueOnly).Location = New-Object System.Drawing.Point ($Label.Right,$Label.Top)
$CloseButton = New-Object System.Windows.Forms.Button
$CloseButton.Text = "Close"
$CloseButton.Location = New-Object System.Drawing.Point(140,260)
#$CloseButton.AutoSize = $true

#$Form.Controls.Add($CloseButton)
Function Draw(){

 Param([string[]]$nases,[int]$tilesToShow)
 Set-variable -name "heighttotal" -Value 0 -Force -Scope Global
 $nextrowcount = 0
 $h = 0
 $count=0
 $widthtotal = 0
 $nextrow = $false
 Write-Host "Heighttotal before Foreach:"(Get-Variable -Name "heighttotal" -ValueOnly -Scope Global)
foreach ($nas in $nases){
#####Set up very first label only#######
New-Variable -Name "$nas`_label" -Value (New-Object System.Windows.Forms.Label) -Scope Script -Force

(Get-Variable -name "$nas`_label" -ValueOnly).Text = "$($nas.toupper())"
(Get-Variable -name "$nas`_label" -ValueOnly).Font = New-Object System.Drawing.Font("Microsoft Sans Serif",10,[System.Drawing.FontStyle]::Bold)
(Get-Variable -name "$nas`_label" -ValueOnly).BackColor = "LightGreen"
(Get-Variable -name "$nas`_label" -ValueOnly).BorderStyle = "FixedSingle"
(Get-Variable -name "$nas`_label" -ValueOnly).TextAlign = "MiddleCenter"
(Get-Variable -name "$nas`_label" -ValueOnly).Width = ($Form.ClientRectangle.Width/(Get-Variable -Name "tilesToShow" -valueonly -Scope Global))
(Get-Variable -name "$nas`_label" -ValueOnly).Height = ($form.ClientRectangle.Height/(Get-Variable -Name "tilesToShow" -valueonly -Scope Global))
#####END Set up very first label only#######

Write-Host "NAS:$nas"
Write-Host "NasLabelHeight:"(Get-Variable -name "$nas`_label" -ValueOnly).Height
Write-Host "NasLabelWidth:"(Get-Variable -name "$nas`_label" -ValueOnly).Width
#(Get-Variable -name "$nas`_label" -ValueOnly).AutoSize = $true

if ($count -eq 0){
Write-Host "Count -eq 0"
$widthtotal +=(Get-Variable -name "$nas`_label" -ValueOnly).Width
Write-Host "Heighttotal before set if count is 0:"(Get-Variable -Name "heighttotal" -ValueOnly -Scope Global)
Write-Host (Get-Variable -name "$nas`_label" -ValueOnly).Height
$t = (Get-Variable -name "$nas`_label" -ValueOnly).Height
Write-Host "T:"$t
Set-Variable -Name "heighttotal" -Value $t -Force -Verbose -Scope Global
Write-Host "Heighttotal after set if count is 0:"(Get-Variable -Name "heighttotal" -ValueOnly -Scope Global)

Write-host "Heighttotal:"(get-variable -name "heighttotal" -ValueOnly -Scope Global)
}
Write-host "Form Width:"$Form.ClientRectangle.Width
Write-Host "Count:$count"
Write-Host "Before: $nas`_label" + "$($nases[$($count-1)])`_label"
Write-Host "(Get-Variable -name `$(`$nases[`$count])`_label -ValueOnly).Width" (Get-Variable -name "$($nases[$count])`_label" -ValueOnly).Width
$CurrentNasLabelName = "$($nases[$count])`_label"
if ($count -gt 0){
Write-Host "Count -gt 0"
$PreviousNasLabelName = "$($nases[$count-1])`_label"
Write-Host "PreviousNasLabelName:"$PreviousNasLabelName
}
#if count is gt than 0 and the difference between the form width and the total counted width so far is greater than the width of 
#the previousnas label in nases based on $count
Write-Host "(`$Form.ClientRectangle.Width - `$widthtotal) Difference:"($Form.ClientRectangle.Width - $widthtotal)
#Write-Host (Get-Variable -name $($labelname) -ValueOnly).Width
Write-Host "((`$count -gt 0) -and ((`$Form.ClientRectangle.Width - `$widthtotal) -ge (Get-Variable -name `$PreviousNasLabelName -ValueOnly).Width))Result:"(($count -gt 0) -and (($Form.ClientRectangle.width - $widthtotal) -ge (Get-Variable -name $PreviousNasLabelName -ValueOnly).Width))
<#if(!(($Form.Width - $widthtotal) -ge (Get-Variable -name $PreviousNasLabelName -ValueOnly).Width)){
$nextrow = $true
$reset = $False
}#>


#set up all labels after very first label based on $count


if (($count -gt 0) -and (($Form.ClientRectangle.Width - $widthtotal) -ge (Get-Variable -name $PreviousNasLabelName -ValueOnly).Width)){
#Write-Host "IF - $($nases[$count])`_label"
#set up label size for next label want it to be the same size as the previous one
(Get-Variable -name "$nas`_label" -ValueOnly).Width = (Get-Variable -name $PreviousNasLabelName -ValueOnly).Width
(Get-Variable -name "$nas`_label" -ValueOnly).Height = (Get-Variable -name $PreviousNasLabelName -ValueOnly).Height

$widthtotal += (Get-Variable -name "$nas`_label" -ValueOnly -Verbose).Width

#Write-Host "IN: $nas`_label" + "CountMinusOne$($nases[$($count-1)])`_label"

#write-host "LabelName:$labelname`nLabelRight:$((Get-Variable -name $($labelname) -ValueOnly).right)"
#set location of next label/nas. Does this with the help of$count. You have to get the previous variable's x and y value.
(Get-Variable -name "$nas`_label" -ValueOnly -Verbose).location = New-Object System.Drawing.Point (((Get-Variable -name $PreviousNasLabelName -ValueOnly).Right),((Get-Variable -name $PreviousNasLabelName -ValueOnly).top)) -Verbose

}elseif($nextrow){
Write-Host "Nextrow:"$nextrow
(Get-Variable -name "$nas`_label" -ValueOnly -Verbose).Width = (Get-Variable -name $PreviousNasLabelName -ValueOnly).Width
(Get-Variable -name "$nas`_label" -ValueOnly -Verbose).Height = (Get-Variable -name $PreviousNasLabelName -ValueOnly).Height
#set location of next label/nas. Does this with the help of$count. You have to get the previous variable's x and y value.
$widthtotal += (Get-Variable -name "$nas`_label" -ValueOnly).Width
if ($reset){
Write-Host "Reset"
(Get-Variable -name "$nas`_label" -ValueOnly).location = New-Object System.Drawing.Point (((Get-Variable -name $beginningNas -ValueOnly -Scope Script).right),((Get-Variable -name $beginningNas -ValueOnly -Scope Script).Height * $nextrowcount)) -Verbose

}
if (!($reset)){
Write-Host "!reset"
Write-Host "Nextrowcount:"$nextrowcount
#start of the new row with x axis at 0 and y based on height of the label multiplied by $nextrowcount
Write-Host "Variable height:"(Get-Variable -name "$nas`_label" -ValueOnly).Height
Write-Host "Variable * nextrowcount):"((Get-Variable -name "$nas`_label" -ValueOnly).Height * $nextrowcount)
(Get-Variable -name "$nas`_label" -ValueOnly).location = New-Object System.Drawing.Point (0,((Get-Variable -name "$nas`_label" -ValueOnly).Height * $nextrowcount)) -Verbose
#reset becomes true and the next label is set based on previous if statement now that reset is true
$reset = $true
#have to set $beginning nas in order to set the next label correctly.
New-Variable -name "beginningNas" -Force -Scope Script -value "$nas`_label" -Verbose
#To account for the height of the first row need to get the height from the very first label
$h += [int]((Get-Variable $beginningNas -ValueOnly -Scope Script -Verbose).height)
if ($nextrowcount -eq 1){
$h +=(Get-Variable -name "$($nases[0])`_label" -ValueOnly -Verbose).Height
}
Set-Variable -Name "heighttotal" -Value $h -Scope Global -Force -Verbose

#(Get-Variable -Name "heighttotal" -ValueOnly -Scope Global) += (Get-Variable $beginningNas -ValueOnly -Scope Script).height
Write-Host "Heighttotal:"(get-variable -name "heighttotal" -ValueOnly -Scope Global)
Write-Host "FormHeight:"$form.ClientRectangle.Height
#need to reset widthtotal as well for each reset. Reset to the width of the first label of the row
$widthtotal = (Get-Variable -name "$nas`_label" -ValueOnly).width
}


}#>
#Write-Host "CurrentNasLabelName:$CurrentNasLabelName`n"
#Write-Host "2Height:"$heighttotal
#Write-Host "2FormHeight:"$Form.Height

#Write-Host "WidthTotal:$widthtotal"
#Write-Host "Difference:"($Form.Width - $widthtotal)

#Write-Host "$nas - $count - $((Get-Variable -name $labelname -ValueOnly).location)"
Write-Host "Count:"$count
Write-Host "tilestoshow:"(Get-Variable -Name "tilesToShow" -valueonly -Scope Global)
<#if ($count%(Get-Variable -Name "tilesToShow" -valueonly -Scope Global) -eq 0 -or ($widthtotal -gt $form.ClientRectangle.Width)){
    #reset for next row based on if $count remainder $tilestoshow is 0
    
    $nextrow = $true
    $nextrowcount++
    $nextrowcountchange = $true
    $reset = $false
    Write-Host "count%(Get-Variable -Name tilesToShow -valueonly -Scope Global)-eq 0:"($count%(Get-Variable -Name "tilesToShow" -valueonly -Scope Global) -eq 0)
    Write-Host "nextrowcount:"$nextrowcount

    }#>
    #($widthtotal -ge $form.ClientRectangle.Width)
    # ($count%(Get-Variable -Name "tilesToShow" -valueonly -Scope Global) -eq 0) -or 
    Write-Host "Widthtotal before if:"$widthtotal
    Write-Host ($Form.ClientRectangle.Width - $widthtotal)
    Write-Host (Get-Variable -name "$nas`_label" -ValueOnly).Width
    Write-Host "RESET IF STATEMENT:"((!($Form.ClientRectangle.Width - $widthtotal) -ge (Get-Variable -name "$nas`_label" -ValueOnly).Width))
    if (!(($Form.ClientRectangle.Width - $widthtotal) -ge (Get-Variable -name "$nas`_label" -ValueOnly).Width)){
    #reset for next row based on if $count remainder $tilestoshow is 0
    Write-host "Attempting to set next row settings"
    $nextrow = $true
    $nextrowcount++
    $nextrowcountchange = $true
    $reset = $false
    Write-Host "count%(Get-Variable -Name tilesToShow -valueonly -Scope Global)-eq 0:"($count%(Get-Variable -Name "tilesToShow" -valueonly -Scope Global) -eq 0)
    Write-Host "nextrowcount:"$nextrowcount

    }
        $count++
    Write-Host (Get-Variable -name "$nas`_label" -ValueOnly).location
    }#end Foreach NAS
    
}#end function DRAW




#$form.ShowDialog()


#$Form.Controls.Clear()

<#foreach ($nas in $nases){
(Remove-Variable -name "$nas`_label" -Force)
}#>

<#do{


    foreach ($nas in $nases){
    #[System.Windows.Forms.Application]::DoEvents()
    if (!($term)){
            if (!(Test-Connection $nas -Quiet -count 1)){
            (Get-Variable -name "$nas`_label" -ValueOnly).BackColor = "Red"
            write-host "Bad Connection"
            (Get-Variable -name "$nas`_label" -ValueOnly).Update()
            }else{
            (Get-Variable -name "$nas`_label" -ValueOnly).BackColor = "LightGreen"
            
            (Get-Variable -name "$nas`_label" -ValueOnly).Update()
            }
        }else{
        break
        write-host "Break"
        }#end if
    }
#$appContext = New-Object System.Windows.Forms.ApplicationContext
#[void][System.Windows.Forms.Application]::Run($form)
    start-sleep 2
}while((get-date).Hour -lt 18 -or ($term -eq $false))#>
####NAS PINGS are at the top in the timer. think it loads it into the gui

#[System.Windows.Forms.Application]::DoEvents()

Draw -nas $nases -tilesToShow (Get-Variable -Name "tilesToShow" -ValueOnly -Scope Global -Verbose)
do{
Write-Host "HeightCount:"$heightcount
Write-Host "HeighttoTotal:"(get-variable -name "heighttotal" -ValueOnly -Scope Global)
Write-Host "FormClientRecHeight:"$form.ClientRectangle.Height
Write-Host "HeightGTformWidthBefore"((get-variable -name "heighttotal" -ValueOnly -Scope Global) -gt $form.ClientRectangle.Height)
if ((get-variable -name "heighttotal" -ValueOnly -Scope Global) -ge $form.ClientRectangle.Height){
    Write-Host "Increasing height count:$heightcount"
    $heightcount += .2
    #Write-Host "Increasing height count:$heightcount"
    $newTileval = $heightcount
    Set-Variable -Name "tilesToShow" -Value $newTileval -Scope Global -Force
    
    Write-Host "Removing Label Objects"
    Write-Host "Tilestoshow:"$tilesToShow
    Write-Host "HeightCount:"$heightcount
        Foreach ($nas in $nases){
        
        Remove-Variable -Name "$nas`_label" -Force -Scope Script
        }
        Write-Host "Calling Draw function"
        
       Draw -tilesToShow (Get-Variable -Name "tilesToShow" -ValueOnly -Scope Global) -nas $nases
    }


Write-Host "HeightCount:"$heightcount
Write-Host "HeightTotal:"(get-variable -name "heighttotal" -ValueOnly -Scope Global)
Write-Host "FormClientRecHeight:"$form.ClientRectangle.Height
Write-Host "HeightGTformWidthAfter Draw Call"((get-variable -name "heighttotal" -ValueOnly -Scope Global) -gt $form.ClientRectangle.Height)
}while((get-variable -name "heighttotal" -ValueOnly -Scope Global) -ge $form.ClientRectangle.Height)
Foreach ($nas in $nases){
        $Form.Controls.Add((Get-Variable "$nas`_label" -ValueOnly))
        #$Form.Controls.Remove((Get-Variable "$nas`_label" -ValueOnly))
        }

$timer.Start()
$appContext = New-Object System.Windows.Forms.ApplicationContext
[void][System.Windows.Forms.Application]::Run($form)

#Start-Sleep 100
$Form.Close()
$Form.Dispose()
Stop-Transcript
