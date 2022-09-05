[CmdletBinding()]
param(
  $SystemPath,# the value can be set in PYTHA Interface Setup
  $SystemCommand,# the value can be set in PYTHA Interface Setup
  $SystemProfile,# the value can be set in PYTHA Interface Setup
  [Parameter(Mandatory = $true,ValueFromPipeline = $true)] $Program
)
#-------------------------------------------------------------#
#----Initial Declarations-------------------------------------#
#-------------------------------------------------------------#

$DesktopPath = [Environment]::GetFolderPath("Desktop")
cd $DesktopPath
New-Item -ItemType Directory -Name "JSON_Settings"
cd "JSON_Settings"

$SystemPath | ConvertTo-Json | Out-File -FilePath "./SystemPath.txt"
$SystemCommand | ConvertTo-Json | Out-File -FilePath "./SystemCommand.txt"
$SystemProfile | ConvertTo-Json | Out-File -FilePath "./SystemProfile.txt"
$input | ConvertTo-Json | Out-File -FilePath "./input.txt"




function Add-StringBefore {
  param(
    [array]$insert,
    [string]$keyword,
    # in $textfile muss eigentlich immer $Prog.CamPath übergeben werden
    [string]$textfile,
    [boolean]$bc
  )
  Write-Host "Das ist der insert: $insert"
  Write-Host "Das ist das keyword: $keyword"
  Write-Host "Das ist der PFad: $textfile"

  $content = Get-Content $textfile

  Write-Host "Das ist der aktuelle inhalt: $content"
  $counter = 0
  $keywordcomplete = ""
  foreach ($string in $content) {

    if ($string -like "*$keyword*") {
      if ($bc) {
        #$Global:exclamtionmarks += $textfile
      }

      $keywordcomplete = $string

      $content[$counter] = ""
      for ($i = 0; $i -lt $insert.Count; $i++) {
        $content[$counter] = $content[$counter] + $insert[$i] + "`n"
      }
      if ($bc) {
        $keywordcomplete = $keywordcomplete.Substring(0,$keywordcomplete.Length - 1)
        $keywordcomplete = $keywordcomplete.Substring(0,$keywordcomplete.Length - 1)
        $keywordcomplete = $keywordcomplete + ", -1, -1, -1, 0, true, true, 0, 5);"
        $content[$counter] = $content[$counter] + $keywordcomplete
      }
      else {
        $content[$counter] = $content[$counter] + $keywordcomplete + "`n"
      }

    }
    $counter++
  }


  $content | Out-File $textfile



}
function Set-Exlamationmarks {
  param(
    [array]$files
  )
  $files = $files | Select-Object -Unique
  foreach ($textfile in $files) {
    $textfile = $textfile.Replace("xcs","pgmx")
    $dir = (Get-Item $textfile).Directory.FullName
    $filename = "!!!" + ((Get-Item $textfile).Name)
    $newsave = $dir + "\" + $filename
    $content | Out-File $newsave
    Remove-Item $textfile
  }
}
function Correct-M200Updated {
  foreach ($file2 in ((Get-ChildItem $State.WorkingDir | Where-Object { $_.FullName -like "*_2.xcs" } | Select-Object FullName).FullName)) {
    Write-Host "diese Datei wird nun von Correct-Function gecheckt: $file2" -ForegroundColor Green
    $count = 0
    Write-Host "HIER STEHT FILE2: $file2" -ForegroundColor Red
    $content = Get-Content $file2
    foreach ($line in $content) {
      if ($line -like "*CreateRawWorkpiece*") {
        $newstring = ($content[$count]) -replace ".{43}$"
        $newstring = $newstring + "0.0000,0.0000,0.0000,0.0000,0.0000,0.0000);"
        $content[$count] = $newstring
      }
      if ($line -like "*SetWorkpieceSetupPosition*") {
        $newstring = ($content[$count]) -replace ".{26}$"
        $newstring = $newstring + "0.0000, 0.0000, 0.0, 0.0);"
        $content[$count] = $newstring
      }
      $count++
    }

    $content | Out-File $file2

  }

}

function Open-Dir {
  Invoke-Item $State.WorkingDir
}

function First-Replace {
  foreach ($Prog in $State.input) {

    (Get-Content $Prog.CamPath) | ForEach-Object {

      # Hier können Textersetzungen angegeben werden, welche dann in der xcs- bzw. pgmx-Datei wirksam werden
      $_.Replace("SlantedBladeCut","Saegeschnitt_").
      Replace("Routing_","Fraesen_").
      Replace("VerticalDrilling","Vertikale Bohrung").
      Replace("HorizontalDrilling","Horizontale Bohrung").
      Replace("PYTHA_INIT_","Blindes Makro_").
      Replace("PYTHA_PARK_","Wegfahrschritt_")

    } | Set-Content $Prog.CamPath


    

    # Approach- und RetractStrategie ersetzen
    (Get-Content $Prog.CamPath) | ForEach-Object {

      # Im Bogen an- und abfahren mit 5 mm Überlappung für Bauteilumfräsung
      $_.Replace("SetApproachStrategy(true, false, -1)","SetApproachStrategy(false, true, 2)").
         Replace("SetRetractStrategy(true, false, -1, 0)","SetRetractStrategy(false, true, 2, 5)")

    } | Set-Content $Prog.CamPath



    # An- und Abfahrbewegung fliegend bohrend für Nut
    $insertnut = @()
    $insertnut += 'SetApproachStrategy(true, false, 1.5);'
    $insertnut += 'SetRetractStrategy(true, false, 1.5, 0);'
    $keywordnut = "CreateSlot"
    $textfile = $Prog.CamPath
    Add-StringBefore -insert $insertnut -keyword $keywordnut -textfile $textfile -bc $false

    # Anfahrbewegung fliegend bohrend und Strategie für Tasche (wenn nur 2 inserttaschen aktiv sind geht es nicht richtig)
    $inserttasche = @()
    $inserttasche += 'SetApproachStrategy(true, false, 5);'
    $inserttasche += 'SetRetractStrategy(true, false, 5, 5);'
    $inserttasche += 'CreateContourParallelStrategy(true, 0, true, 8, 0, 0);'
    $keywordtasche = "CreateContourPocket"
    $textfile = $Prog.CamPath
    Add-StringBefore -insert $inserttasche -keyword $keywordtasche -textfile $textfile -bc $false


    # Vorritzen, an- und abfahren mit dem Sägeblatt
    $insertblatt = @()
    $insertblatt += 'SetApproachStrategy(true, true, 0.25);'
    $insertblatt += 'SetRetractStrategy(true, true, 0.25, 0);'
    $insertblatt += 'CreateSectioningMillingStrategy(5, 80, 0);'
    $keywordblatt = "CreateBladeCut"
    $textfile = $Prog.CamPath
    Add-StringBefore -insert $insertblatt -keyword $keywordblatt -textfile $textfile -bc $true

  }

}
function convert-xcs-to-pgmx_x200 {

  #XConverter Maestro 64 Bit
  $State.XConverter = 'C:\Program Files\SCM Group\Maestro\XConverter.exe'
  #Maschineneinstellung X200
  $X200 = "C:\Users\Public\Documents\SCM Group\Maestro\Environments\X200"


  Write-Host "!!!!! TMPFiles2: $State.tmpFiles2" -ForegroundColor Green
  Write-Output 'GS Ravensburg CAM-Export' $State.Infiles 'Umwandlung von .xcs- in .pgmx-Dateien inklusive Saugerpositionierung und Optimierung' $State.outFiles
  # Konvertieren in tmp pgmx
  Write-Host "JETZT WERDEN INFILES IN TEMP KONVERTIERT!!!!" -ForegroundColor Green
  Write-Host $State.Infiles -ForegroundColor RED
  Write-Host "INFILES: $State.Infiles" -ForegroundColor Green
  & $State.XConverter -ow -s -report -m 0 -i $State.Infiles -env $X200 -o $State.tmpFiles | Out-Default
  $g = (Get-ChildItem -Path $State.WorkingDir).Name
  Write-Host "Das ist der Ordnerinhalt nach der Konvertierung: $g"
  # Bearbeitungen optimieren
  Write-Host "JETZT WERDEN FILES OPTIMIERT!!!!" -ForegroundColor Green
  & $State.XConverter -ow -s -m 2 -i $State.tmpFiles -env $X200 -o $State.tmpFiles2 | Out-Default
  $g = (Get-ChildItem -Path $State.WorkingDir).Name
  Write-Host "Das ist der Ordnerinhalt nach der Optimierung: $g"

  # Sauger positionieren
  & $State.XConverter -ow -s -m 13 -i $State.tmpFiles2 -env $X200 -o $State.outFiles | Out-Default

  # Loesche die temporaeren Dateien
  Remove-Item $State.tmpFiles

  # Loesche die temporaeren Dateien
  Remove-Item $State.tmpFiles2
}

function convert-xcs-to-pgmx_m200 {

  #XConverter Maestro 64 Bit
  $State.XConverter = 'C:\Program Files\SCM Group\Maestro\XConverter.exe'
  #Maschineneinstellung M200
  $M200 = "C:\Users\Public\Documents\SCM Group\Maestro\Environments\M200"

  Write-Host "!!!!! TMPFiles2: $State.tmpFiles2" -ForegroundColor Green
  Write-Output 'GS Ravensburg CAM-Export' $State.Infiles 'Umwandlung von .xcs- in .pgmx-Dateien inklusive Saugerpositionierung und Optimierung' $State.outFiles
  # Konvertieren in tmp pgmx
  Write-Host "JETZT WERDEN INFILES IN TEMP KONVERTIERT!!!!" -ForegroundColor Green
  Write-Host $State.Infiles -ForegroundColor RED
  Write-Host "INFILES: $State.Infiles" -ForegroundColor Green
  & $State.XConverter -ow -s -report -m 0 -i $State.Infiles -env $M200 -o $State.tmpFiles | Out-Default
  $g = (Get-ChildItem -Path $State.WorkingDir).Name
  Write-Host "Das ist der Ordnerinhalt nach der Konvertierung: $g"
  # Bearbeitungen optimieren
  Write-Host "JETZT WERDEN FILES OPTIMIERT!!!!" -ForegroundColor Green
  & $State.XConverter -ow -s -m 2 -i $State.tmpFiles -env $M200 -o $State.tmpFiles2 | Out-Default
  $g = (Get-ChildItem -Path $State.WorkingDir).Name
  Write-Host "Das ist der Ordnerinhalt nach der Optimierung: $g"

  # Sauger positionieren
  & $State.XConverter -ow -s -m 13 -i $State.tmpFiles2 -env $M200 -o $State.outFiles | Out-Default

  # Loesche die temporaeren Dateien
  Remove-Item $State.tmpFiles

  # Loesche die temporaeren Dateien
  Remove-Item $State.tmpFiles2
}


Add-Type -AssemblyName PresentationCore,PresentationFramework

$Xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Width="800" Height="550" Topmost="True">
  <Grid>
    <TabControl Margin="2,0,-2,0" SelectedIndex="{Binding tabIndex}" Name="name">
      <TabItem Visibility="Collapsed" Header="Auswahl">
        <Grid Margin="0,-2,0,2" Name="selection" Background="#9b9b9b">
          <Button Content="5-Achs M200" HorizontalAlignment="Left" VerticalAlignment="Top" Width="210" Margin="33,259,0,0" Height="64" BorderBrush="#9b9b9b" Foreground="#000000" OpacityMask="#4a90e2" BorderThickness="5,5,5,5" FontFamily="Yu Gothic UI Bold *" FontSize="22" FontWeight="DemiBold" Background="#ffffff" Name="m200button"/>
          <Button Content="Nesting X200" HorizontalAlignment="Left" VerticalAlignment="Top" Width="210" Margin="33,80,0,0" Name="x200button" Height="64" Background="#ffffff" BorderBrush="#9b9b9b" Foreground="#000000" OpacityMask="#4a90e2" BorderThickness="5,5,5,5" FontFamily="Yu Gothic UI Bold *" FontSize="22" FontWeight="DemiBold"/>
          <Image HorizontalAlignment="Left" Height="171" VerticalAlignment="Top" Width="313" Margin="395,20,0,0" Source="C:\usr\Texturen GS Ravensburg\Geraete+Sonstiges\x200.png" Name="x200"/>
          <Image HorizontalAlignment="Left" Height="171" VerticalAlignment="Top" Width="313" Margin="395,210,0,0" Source="C:\usr\Texturen GS Ravensburg\Geraete+Sonstiges\m200.png" Name="m200"/>
          <Image HorizontalAlignment="Left" Height="40" VerticalAlignment="Top" Width="40" Margin="722,406,0,0" Name="icon1" Source="C:\usr\Texturen GS Ravensburg\Geraete+Sonstiges\icon.png"/>
          <Label HorizontalAlignment="Left" VerticalAlignment="Top" Content="Gewerbliche Schule Ravensburg" Margin="387,414,0,0" Name="IconText1" FontFamily="Yu Gothic UI Bold *" FontSize="021" FontWeight="DemiBold"/>
        </Grid>
      </TabItem>
      <TabItem Visibility="Collapsed" Header="Fortschritt">
        <Grid Background="#9b9b9b" Margin="1,1,-1,-1" Name="wait">
          <Image HorizontalAlignment="Left" Height="40" VerticalAlignment="Top" Width="40" Margin="722,406,0,0" Name="icon2" Source="C:\usr\Texturen GS Ravensburg\Geraete+Sonstiges\icon.png"/>
          <Label HorizontalAlignment="Left" VerticalAlignment="Top" Content="Gewerbliche Schule Ravensburg" Margin="387,414,0,0" Name="IconText2" FontFamily="Yu Gothic UI Bold *" FontSize="021" FontWeight="DemiBold"/>
          <Image HorizontalAlignment="Left" Height="255" VerticalAlignment="Top" Width="571" Margin="185,97,0,0" Source="C:\usr\Texturen GS Ravensburg\Geraete+Sonstiges\warten.png"/>
          <Image HorizontalAlignment="Left" Height="245" VerticalAlignment="Top" Width="123" Margin="41,102,0,0" Source="C:\usr\Texturen GS Ravensburg\Geraete+Sonstiges\sanduhr.png"/>
        </Grid>
      </TabItem>
      <TabItem Visibility="Collapsed" Header="Ende">
        <Grid Background="#FFE5E5E5">
          <Image HorizontalAlignment="Left" Height="40" VerticalAlignment="Top" Width="40" Margin="722,406,0,0" Name="icon3" Source="C:\usr\Texturen GS Ravensburg\Geraete+Sonstiges\icon.png"/>
          <Label HorizontalAlignment="Left" VerticalAlignment="Top" Content="Gewerbliche Schule Ravensburg" Margin="387,414,0,0" Name="IconText3" FontFamily="Yu Gothic UI Bold *" FontSize="021" FontWeight="DemiBold"/>
          <Image HorizontalAlignment="Left" Height="102" VerticalAlignment="Top" Width="102" Margin="12,5,0,0" Name="errorimage" Source="C:\DevStuff\Projekt\Theo\error.png"/>
          
          <TextBox HorizontalAlignment="Left" VerticalAlignment="Top" Height="102" Width="356" TextWrapping="Wrap" Margin="94,224,0,0" Text="In der Konfiguration liegt ein Fehler vor! Bitte oeffne den Exportbericht!"/>
          <TextBlock HorizontalAlignment="Left" VerticalAlignment="Top" TextWrapping="Wrap" Text="Fehler:" Margin="664,29,0,0" FontFamily="Yu Gothic UI Bold *" FontSize="021" FontWeight="DemiBold"/>
        </Grid>
      </TabItem>
    </TabControl>
  </Grid>
</Window>

"@
# <TextBox HorizontalAlignment="Left" VerticalAlignment="Top" Height="306" Width="471" Text="In der Konfiguration liegt ein Fehler vor!" TextWrapping="Wrap" Margin="292,82,0,0" Name="errorbox"/>
#-------------------------------------------------------------#
#----Control Event Handlers-----------------------------------#
#-------------------------------------------------------------#



#endregion

#-------------------------------------------------------------#
#----Script Execution-----------------------------------------#
#-------------------------------------------------------------#

$Window = [Windows.Markup.XamlReader]::Parse($Xaml)

[xml]$xml = $Xaml

$xml.SelectNodes("//*[@Name]") | ForEach-Object { Set-Variable -Name $_.Name -Value $Window.FindName($_.Name) }


$m200button.Add_Click({ Run-M200 $this $_ })
$x200button.Add_Click({ Run-X200 $this $_ })




$State = [pscustomobject]@{}


function Set-Binding {
  param($Target,$Property,$Index,$Name)

  $Binding = New-Object System.Windows.Data.Binding
  $Binding.Path = "[" + $Index + "]"
  $Binding.Mode = [System.Windows.Data.BindingMode]::TwoWay



  [void]$Target.SetBinding($Property,$Binding)
}

function FillDataContext ($props) {

  for ($i = 0; $i -lt $props.Length; $i++) {

    $prop = $props[$i]
    $DataContext.Add($DataObject. "$prop")

    $getter = [scriptblock]::Create("return `$DataContext['$i']")
    $setter = [scriptblock]::Create("param(`$val) return `$DataContext['$i']=`$val")
    $State | Add-Member -Name $prop -MemberType ScriptProperty -Value $getter -SecondValue $setter

  }
}



$DataObject = ConvertFrom-Json @"

{
    "tabIndex" : 0,
    "GlobalError" : null,
    "Systempath" : null,
    "SystemCommand" : null,
    "SystemProfile" : null,
    "Program" : null,
    "XConverter" : null,
    "Infiles" : null,
    "tmpFiles" : null,
    "tmpFiles2" : null,
    "outFiles" : null,
    "Tooling" : null,
    "WorkingDir" : null,
    "WorkingDirTemp" : null,
    "input" : null
    
}

"@

$DataContext = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
FillDataContext @("tabIndex","GlobalError","Systempath","SystemCommand","SystemProfile","Program","XConverter","Infiles","tmpFiles","tmpFiles2","outFiles","Tooling","WorkingDir","WorkingDirTemp","input")

$Window.DataContext = $DataContext
Set-Binding -Target $name -Property $([System.Windows.Controls.TabControl]::SelectedIndexProperty) -Index 0 -Name "tabIndex"





$Global:SyncHash = [hashtable]::Synchronized(@{})
$SyncHash.Window = $Window
$Jobs = [System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]::new())
$initialSessionState = [initialsessionstate]::CreateDefault()

function Start-RunspaceTask
{
  [CmdletBinding()]
  param([Parameter(Mandatory = $True,Position = 0)] [scriptblock]$ScriptBlock,
    [Parameter(Mandatory = $True,Position = 1)] [PSObject[]]$ProxyVars)

  $Runspace = [runspacefactory]::CreateRunspace($InitialSessionState)
  $Runspace.ApartmentState = 'STA'
  $Runspace.ThreadOptions = 'ReuseThread'
  $Runspace.Open()
  foreach ($Var in $ProxyVars) { $Runspace.SessionStateProxy.SetVariable($Var.Name,$Var.Variable) }
  $Thread = [powershell]::Create('NewRunspace')
  $Thread.AddScript($ScriptBlock) | Out-Null
  $Thread.Runspace = $Runspace
  [void]$Jobs.Add([psobject]@{ PowerShell = $Thread; Runspace = $Thread.BeginInvoke() })
}

$JobCleanupScript = {
  do
  {
    foreach ($Job in $Jobs)
    {
      if ($Job.Runspace.IsCompleted)
      {
        [void]$Job.PowerShell.EndInvoke($Job.Runspace)
        $Job.PowerShell.Runspace.Close()
        $Job.PowerShell.Runspace.Dispose()
        $Job.PowerShell.Dispose()

        $Jobs.Remove($Job)
      }
    }

    Start-Sleep -Seconds 1
  }
  while ($SyncHash.CleanupJobs)
}

Get-ChildItem Function: | Where-Object { $_.Name -notlike "*:*" } | Select-Object name -ExpandProperty name |
ForEach-Object {
  $Definition = Get-Content "function:$_" -ErrorAction Stop
  $SessionStateFunction = New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList "$_",$Definition
  $InitialSessionState.Commands.Add($SessionStateFunction)
}


$Window.Add_Closed({
    Write-Verbose 'Halt runspace cleanup job processing'
    $SyncHash.CleanupJobs = $False
  })

$SyncHash.CleanupJobs = $True
function Async ($scriptBlock) { Start-RunspaceTask $scriptBlock @([psobject]@{ Name = 'DataContext'; Variable = $DataContext },[psobject]@{ Name = "State"; Variable = $State },[psobject]@{ Name = "SyncHash"; Variable = $SyncHash }) }

Start-RunspaceTask $JobCleanupScript @([psobject]@{ Name = 'Jobs'; Variable = $Jobs })



#No Console
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);'
[Console.Window]::ShowWindow([Console.Window]::GetConsoleWindow(),0)

# State-Variables
$State.Systempath = $Systempath
$State.SystemCommand = $SystemCommand
$State.SystemProfile = $SystemProfile
$State.Program = $Program

#XConverter Maestro 64 Bit
$State.XConverter = 'C:\Program Files\SCM Group\Maestro\XConverter.exe'

#Werkzeugdatei Maestro 64 Bit
$State.Tooling = 'C:\Users\Public\Documents\SCM Group\Maestro\Tlgx\ST.tlgx'

$State.input = $input

$State.Infiles = @()
$State.tmpFiles = @()
$State.tmpFiles2 = @()
$State.outFiles = @()

$State.WorkingDir
$State.WorkingDirTemp


<#
if (($State.input.CamPath) -is [string]) {
  $State.WorkingDirTemp = ($State.input.CamPath)
}
else {
  $State.WorkingDirTemp = $State.input.CamPath[0]
}
$State.WorkingDir = ((Get-Item $State.WorkingDirTemp | Select-Object Directory).Directory).FullName
Write-Host "Global:workingdir" -ForegroundColor Green
#>


# WorkDir
# Get SavePath
$raw = [System.IO.DirectoryInfo]$input.CamPath
$State.WorkingDir = $raw.Parent.FullName

function Run-M200 () {
  Async {
    $path = $State.WorkingDir + "\exportbericht.txt"
    Start-Transcript -Path $path
    # Werkzeugdatei M200 Maestro 64 Bit
    $State.Tooling = 'C:\Users\Public\Documents\SCM Group\Maestro\Tlgx\defM200.tlgx'

    # Start-Transcript "C:\Users\theo_\Desktop\transcript.txt"
   
    # Global Vars
    $count = 0

    $State.tabIndex = 1
    First-Replace
    try {
      Correct-M200Updated
    }
    catch {}

    foreach ($Prog in $State.input) {
      if ($count -ge 200) {
        # Die Kommandozeile darf nicht laenger als 8000 Zeichen werden		

        convert-xcs-to-pgmx_m200

        $count = 0
        $State.Infiles = ""
        $State.tmpFiles = ""
        $State.tmpFiles2 = ""
        $State.outFiles = ""
      }


      $xcsPath = $Prog.CamPath
      $pgmxPath = $xcsPath -replace '.xcs$','.pgmx'
      $tmpPath = $xcsPath -replace '.xcs$','__tmp.pgmx'
      $tmpPath2 = $xcsPath -replace '.xcs$','__tmp2.pgmx'


      $count += 1
      [array]$State.Infiles += $xcsPath
      [array]$State.outFiles += $pgmxPath
      [array]$State.tmpFiles += $tmpPath
      [array]$State.tmpFiles2 += $tmpPath2
    }
    convert-xcs-to-pgmx_m200

    
    Start-Sleep 1
    
    
    
    
    if ($error.Count -gt 0) {
      $State.tabIndex = 2
      Stop-Transcript
      Open-Dir
    }
    else {
      Open-Dir
      Stop-Process -Name *powershell*
      Stop-Transcript
    }

  }


}

function Run-X200 () {
  Async {

    $path = $State.WorkingDir + "\exportbericht.txt"
    Start-Transcript -Path $path

    # Clear CreateRawWorkpiece 
    $temppath = $State.WorkingDir + "\temp.xcs"
    Get-Content $State.input.CamPath | Where-Object {$_ -notlike 'CreateRawWorkpiece*'} | Set-Content $temppath
    Get-Content $temppath | Set-Content $State.input.CamPath
    Remove-Item $temppath


    #Werkzeugdatei X200 Maestro 64 Bit
    $State.Tooling = 'C:\Users\Public\Documents\SCM Group\Maestro\Tlgx\ST.tlgx'

    # Global Vars
    $count = 0

    $State.tabIndex = 1

    First-Replace



    foreach ($Prog in $State.input) {
      if ($count -ge 200) {
        # Die Kommandozeile darf nicht laenger als 8000 Zeichen werden		
        "Now Convert in if" | Out-File "C:\Users\theo_\Desktop\log.log" -Append

        convert-xcs-to-pgmx_x200

        $count = 0
        $State.Infiles = ""
        $State.tmpFiles = ""
        $State.tmpFiles2 = ""
        $State.outFiles = ""
      }
      Write-Output "Prog.CamPath "
      Write-Host "Prog.CamPath "
      $Prog.CamPath | Out-String

      $xcsPath = $Prog.CamPath
      $pgmxPath = $xcsPath -replace '.xcs$','.pgmx'
      $tmpPath = $xcsPath -replace '.xcs$','__tmp.pgmx'
      $tmpPath2 = $xcsPath -replace '.xcs$','__tmp2.pgmx'



      $count += 1
      [array]$State.Infiles += $xcsPath
      [array]$State.outFiles += $pgmxPath
      [array]$State.tmpFiles += $tmpPath
      [array]$State.tmpFiles2 += $tmpPath2
    }

    convert-xcs-to-pgmx_x200
    Start-Sleep 1
    if ($error.Count -gt 0) {
      $State.tabIndex = 2
      Stop-Transcript
      Open-Dir
    }
    else {
      Open-Dir
      Stop-Process -Name *powershell*
      Stop-Transcript
    }


  }
}






$State.Systempath = $Systempath
$State.SystemCommand = SystemCommand
$State.SystemProfile = SystemProfile
$State.Program = Program

#SConverter Maestro 64 Bit
$State.XConverter = 'C:\Program Files\SCM Group\Maestro\XConverter.exe'

#Werkzeugdatei Maestro 64 Bit
$State.Tooling = 'C:\Users\Public\Documents\SCM Group\Maestro\Tlgx\ST.tlgx'

$State.input = $input
$State.Infiles
$State.tmpFiles
$State.tmpFiles2
$State.outFiles
$State.WorkingDir
$State.WorkingDirTemp



$Window.ShowDialog()
