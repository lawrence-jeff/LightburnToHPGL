
#This uses the Marlin CNC Profile in Lightburn - with an absolute coordinate output
#machine specific Variables

#Device Scale factor is how many units it uses internally to represent a MM. 
#On my redsail device if I tell it to Move 1000 Units that is 25mm so the scale is 40
$DeviceScaleFactor = 40

#Note: This is based on HPGL that is in format Y, X, if your output is swapped adjust this to false (Mine is y,x so didn't test the other)
$YFirst=$true 

#What COM port the device is attached to (can be USB or Serial)
$ComPort="COM9"

#Device specific init and close commands
$Prefix = "IN;PA;"
$Suffix = "!PG;"

#Can't get this to work if declared in function, leaving it global for now
$global:port1 = new-Object System.IO.Ports.SerialPort $ComPort,9600,None,8,one


function Comms($Action, $Data)
{

    if ($Send)
    {
        if ($Action -eq "Open")
        {           
            $global:port1.RtsEnable = $true
            $global:port1.HandShake = 3
            $global:port1.ReadTimeout = 250
            $global:port1.open()
        }
        elseif ($Action -eq "Send")
        {
            $global:port1.Write($Data)
        }
        elseif ($Action -eq "Close")
        {
            $global:port1.Close()    
        }
        elseif ($Action -eq "Test")
        {
            if ($global:port1.IsOpen)
            {
               if ($YFirst)
               {$global:port1.Write($Prefix + "PU0," + $DeviceScaleFactor * 50 +";PU0,0;")}
               else
               {$global:port1.Write($Prefix + "PU" + $DeviceScaleFactor * 50 +",0;PU0,0;")}
            }
            else
            {
                Write-host "Error Communicating to port"
            }
        }
    }
}



#MAIN SCRIPT

#Confirm if you want to send to cutter or not
$wshell = New-Object -ComObject Wscript.Shell
$Canswer = $wshell.Popup("Do you want to send to your cutter on $ComPort ? `n(Select No to just generate HPGL file for use later)",0,"Cut",36)
if ($Canswer -eq 6) {$Send = $true}else{$Send = $false}

if ($Send -eq $true)
{

    #Open and validate serial
    Comms "Open" $Null 
    Comms "Test" $Null 
    $WAnswer=$wshell.Popup("Did your printer just move ~50mm Left to Right?",0,"Successful Send?",36)
    if ($Wanswer -ne 6)
    {
        $Send = $False 
        Write-Host "Check to see if your device uses X,Y vs Y,X and if so adjust the code, if the X was correct but not 50mm check your scale factor"
    }
}


#Prompt For File to Read - this could be changed to monitor a directory
Add-Type -AssemblyName System.Windows.Forms
$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
    Title = "Select Lightburn Generated Gcode File"
    InitialDirectory = "c:\temp\" 
    Filter = 'Lightburn GCode (*.gc)|*.gc|Gcode (*.gc)|*.gc'
}
$null = $FileBrowser.ShowDialog()
if ($FileBrowser.FileName -eq "")
{
    exit 
}

#Determine Output File name and location
$OutputDir=Split-Path -parent $FileBrowser.FileName
$OutputFileName=(Get-Item $FileBrowser.FileName).Basename  +".hpgl"

#Setup Variables
$AbsoluteCoordinatesInUse=$False
$PenDown = $false 
$BodyLines = ""
$GCodeCount=0
$CurrentX=0
$CurrentY=0

$DebugINfo = New-Object -TypeName 'System.Collections.ArrayList'

#Read Lightburn File
$GCode=Get-content $FileBrowser.FileName
$AllLines = $GCode.Split("`n")
$TotalLines = $AllLines.Count

#Start Sending at the same time as translating commands
Comms "Send" $Prefix


$GCodeIgnoreList = "M9","G90"

#Convert Lines
$StartTime=(Get-Date)
foreach ($Line in $AllLines)
{
    $NewLine = $Null 
    $Note=$Null 

    ++$GcodeCount
    $Command=$Line.Split(" ")[0].Trim()
    Write-Debug "$GCodeCount - Looking at Line $Line, Command $Command"

    if ($command -eq ";")
    {
        $Note= "Ignoring Comment: $Line"
    }
    elseif ($Command -in $GCodeIgnoreList)
    {
       $Note= "Ignoring Command"
    }
    elseif ($command -eq "G91")
    {
        $Note= "Incremental is not handled in this code, set Lightburn to absolute coordinates or check your profile to make sure its Marlin"
        Write-Error "Can't use incremental positioning in this code, it is not currently handled"
        exit 
    }
    elseif ($command -eq "G20")
    {
        $Note="Set to inches"
        $units="IN"
        $ScaleFactor = $DeviceScaleFactor * 25.4

    }
    elseif ($command -eq "G21")
    {
        $Note= "Set to MM"
        $units="MM"
        $ScaleFactor = $DeviceScaleFactor
    }
    elseif ($command -eq "M106")
    {
        Write-Debug "****M106 Detected - Laser On/Off"
        $Supplemental  = $Line.Replace("$Command ","").Trim()
        If ($Supplemental -eq "S0")
        {  
            #THis is laser off in lightburn, so translate to Pen UP (if currently down)
            If ($PenDown) 
            {
                $Note+="****Pen is currently down so issue up command on next movement"
                $PenDown=$false
            }
            else
            {
                 $Note+="****Pen is already up/off so do nothing"
            }
        }
        else #If S has a non zero value laser is on/pen down
        {
            Write-Debug "****Pen/Laser On Cmd Detected"
            If ($PenDown -eq $false) 
            {
                $Note+="****Putting PenDown on future movements"
                $PenDown=$true
            }
            else
            {
                $Note+="****Pen/laser is already up/off so do nothing"
            }
        }
    }
    elseif (($command -eq "G1") -or ($Command -eq "G0"))
    {
        $YChangeLU=0;$XChangeLU=0
        Write-Debug "  Traversal Move: $Line"
        $Supplemental  = $Line.Replace("$Command ","")
        $Supplemental=$Supplemental.Replace("X"," X")
        $Supplemental=$Supplemental.Replace("Y"," Y")
        $Supplemental=$Supplemental.Replace("F"," F")
        
        $XFound=$false
        $YFound=$False
        For ($i=1; $i -le $Supplemental.Split(" ").Count-1; $i++) 
        {
            $Section= $Supplemental.Split(" ")[$i]
            if ($Section[0] -eq "X")
            {
                $XFound=$true
                $Amount=$Section.Replace("X","")
                $XChangeLU=[int]([float]$Amount * $ScaleFactor)
                #Write-Debug "  New X", $Amount, $XChangeLU
                $CurrentX=$XChangeLU
            }
            if ($Section[0] -eq "Y")
            {
                $YFound=$true
                $Amount=$Section.Replace("Y","")
                $YChangeLU=[int]([float]$Amount * $ScaleFactor)
                #Write-Debug "  New Y", $Amount, $YChangeLU
                $CurrentY=$YChangeLU
            }
        }
        
        #Check to see if any values were missing (no change and put them back in for absolute mode)
        if ($XFound -eq $false)
        {
            $XChangeLU=$CurrentX
            Write-Debug "No X in this command, so using last value: $CurrentX"
        }
        If ($YFound -eq $False)
        {
            $YChangeLU=$CurrentY
            Write-Debug "No Y in this command, so using last value: $CurrentY"
        }

        #My plotter uses swapped axis and expects  Y,X in the commands, so change to Y first
        #Change if your machine acts differently
        if ($Pendown -eq $false)
        { 
            if ($YFirst)
            {
                $NewLine=("PU" + $YchangeLU + "," + $XChangeLU + ";")
                Write-Debug ("*****Issue: PU" + $YchangeLU + "," + $XChangeLU + ";") 
            }
            else
            {
               $NewLine=("PU" + $XchangeLU + "," + $YChangeLU + ";")
               Write-Debug ("*****Issue: PU" + $XchangeLU + "," + $YChangeLU + ";") 
            }
        }
        else
        {
            
            $PenDown=$true
            if ($YFirst)
            {
                $NewLine=("PD" + $YchangeLU + "," + $XChangeLU + ";")
                Write-Debug ("*****Issue: PD" + $YchangeLU + "," + $XChangeLU + ";") 
            }
            else
            {
                $NewLine=("PD" + $XchangeLU + "," + $YChangeLU + ";")
                Write-Debug ("*****Issue: PD" + $XchangeLU + "," + $YChangeLU + ";") 
            }
       }
    }
    else
    {
        Write-Host "Unhandled: $Line" -foregroundColor Red
        $Note="ERROR: Unhandled Gcode"
        Start-Sleep -seconds 5 
    }

    #Now Act on translated line
    #Save to full list for later save
    $BodyLines+=$NewLine
    #Send to Cutter
    Comms "Send" $NewLine

    #This slows it down so only do it in debug mode
    if ($DebugPreference -eq "Continue")
    {
        #Debug Collection- you can output this to a spreadsheet or $DebugInfo |Out-gridview to go through it 
        $myObject = [PSCustomObject]@{
         LineNumber = $GCodeCount
         Original     = $Line
         New = $NewLine
         Notes    = $Note
         CurrentX = $CurrentX
         CurrentY = $CurrentY
        }
        $DebugINfo.Add($myObject)
    }

    #Provide Status Update
    if (($GcodeCount % 50) -eq 0)
    {
        Write-Progress -Activity "Converting File" -Status "Working on line $GCodeCount of $TotalLines" -PercentComplete ($GcodeCount*100/$TotalLines)
    }

}
$EndTime=Get-Date
Comms "Send" $Suffix
$Final = $Prefix + $BodyLines + $Suffix
if ($DebugPreference -eq "Continue"){
Write-Host "Final:"
    $Final 
}
$Final |out-file ($OutputDir +"\" + $OutputFileName) -Encoding ascii
Write-Host ("HPGL File saved to $OutputDir" +"\" + $OutputFileName)
$TotalTime = ($EndTime -$starttime).Totalseconds 
Write-Host "Total Time in Seconds: $TotalTime"
Comms "Close" $null


