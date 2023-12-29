
#This uses the Marlin CNC Profile in Lightburn - with an absolute coordinate output

Add-Type -AssemblyName System.Windows.Forms
$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
    InitialDirectory = "c:\temp\" 
    Filter = 'Lightburn GCode (*.gc)|*.gc|Gcode (*.gc)|*.gc'
}
$null = $FileBrowser.ShowDialog()

$OutputDir=Split-Path -parent $FileBrowser.FileName
$OutputFileName=(Get-Item $FileBrowser.FileName).Basename  +".hpgl"

#Device Scale factor is how many units it uses internally to represent a MM. 
#On my redsail device if I tell it to Move 1000 Units that is 25mm so the scale is 40
$DeviceScaleFactor = 40

$Prefix = "IN;PA;"
$Suffix = "!PG;"

$GCode=Get-content $FileBrowser.FileName

$AbsoluteCoordinatesInUse=$False
$PenDown = $false 
$BodyLines = ""
$GCodeCount=0
$CurrentX=0
$CurrentY=0

$AllLines = $GCode.Split("`n")
$TotalLines = $AllLines.Count

foreach ($Line in $AllLines)
{
   
    ++$GcodeCount
    $Command=$Line.Split(" ")[0].Trim()
    If ($Command -eq "G0") {$Command="G1"} 
    Write-Host "$GCodeCount - Looking at Line $Line, Command $Command"

    if ($command -eq ";")
    {
        Write-Host "  Ignoring Comment: $Line"
    }
    elseif ($command -eq "G20")
    {
        Write-Host "  Set to inches"
        $units="IN"
        $ScaleFactor = $DeviceScaleFactor * 25.4

    }
    elseif ($command -eq "G21")
    {
        Write-Host "  Set to MM"
        $units="MM"
        $ScaleFactor = $DeviceScaleFactor
    }
    elseif ($command -eq "G90")
    {
        Write-Host "  Setting to absolute coordinates"
        $AbsoluteCoordinatesInUse = $true
    }
    elseif ($command -eq "G91")
    {
        Write-Host "  Setting to relative coordinates"
         $AbsoluteCoordinatesInUse = $false
    }
    elseif ($command -eq "M8")
    {
        Write-Host "  Turn on Air assist"
    }
    elseif ($command -eq "M9")
    {
        Write-Host "  Turn off Air assist"
    }
    elseif ($command -eq "M106")
    {
        Write-Debug "****M106 Detected - Laser On/Off"

        $Supplemental  = $Line.Replace("$Command ","").Trim()
        
        Write-Debug "****M106 Supplemental value $supplemental"

        If ($Supplemental -eq "S0")
        {
           
            #THis is laser off in lightburn, so translate to Pen UP (if currently down)
            If ($PenDown) 
            {
                Write-Debug "****Pen is currently down so issue up command on next movement"
                #$BodyLines+=("PU;")
                $PenDown=$false
            }
            else
            {
                 Write-Debug "****Pen is already up/off so do nothing"
            }
        }
        else #If S has a non zero value laser is on/pen down
        {

            Write-Debug "****Pen/Laser On Cmd Detected"
            If ($PenDown -eq $false) 
            {
                Write-Debug "****Putting PenDown on future movements"
                $PenDown=$true
            }
            else
            {
                Write-Debug "****Pen/laser is already up/off so do nothing"
            }

        }
    }
    elseif ($command -eq "G1")
    {
        $YChangeLU=0;$XChangeLU=0
        Write-Host "  Traversal Move: $Line"
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
                Write-Host "  New X", $Amount, $XChangeLU
                $CurrentX=$XChangeLU
            }
            if ($Section[0] -eq "Y")
            {
                $YFound=$true
                $Amount=$Section.Replace("Y","")
                $YChangeLU=[int]([float]$Amount * $ScaleFactor)
                Write-Host "  New Y", $Amount, $YChangeLU
                $CurrentY=$YChangeLU
            }
            if ($Section[0] -eq "F")
            {
                Write-Host " New F $Amount - Ignored"
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


        #My plotter uses Y,X in the commands, so change to Y first
        if ($Pendown -eq $false)
        { 
            Write-Host ("*****Issue: PU" + $YchangeLU + "," + $XChangeLU + ";") -ForegroundColor Green
            $BodyLines+=("PU" + $YchangeLU + "," + $XChangeLU + ";")
            
        }
        else
        {
            Write-Host ("*****Issue: PD" + $YchangeLU + "," + $XChangeLU + ";") -ForegroundColor Green
            $BodyLines+=("PD" + $YchangeLU + "," + $XChangeLU + ";")
            $PenDown=$true
        }

    }
    else
    {
        Write-Host "Unhandled: $Line" -foregroundColor Red
        Start-Sleep -seconds 5 
    }
    Write-Host " "

    if (($GcodeCount % 10) -eq 0)
    {
        Write-Progress -Activity "Converting File" -Status "Working on line $GCodeCount of $TotalLines" -PercentComplete ($GcodeCount*100/$TotalLines)
    }

}
Write-Host "Full Body:"
$BodyLines


$Final = $Prefix + $BodyLines + $Suffix
Write-Host "Final:"
$Final 
$Final |out-file ($OutputDir +"\" + $OutputFileName) -Encoding ascii
#You can send this to the device with a copy /p FileName \\.\COM13
