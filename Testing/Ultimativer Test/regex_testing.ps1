$content = Get-Content "/Users/philip/Code/postprozessor/testtest/settings.txt"
$hashtable = @{}
foreach ($line in $content){
    $hashtable.Add(($line.Split("_"))[0],$line)
}

$string = "T01"
$hashtable.($string)


function lineinfile($con){
    foreach ($line in $con){
        if ($line -like "*ResetRetractStrategy();*"){
            return $true
        }
    }
    return $false
}


$path = "/Users/philip/Code/postprozessor/testtest/content.txt"
$content_prog = Get-Content $path
if(lineinfile -con $content_prog){
    $newcontent = @()
    $found = $false
    foreach ($line in $content_prog){
        $newcontent += $line
        if ($line -like "*ResetRetractStrategy();*" -and !$found){
            $newcontent += 'ApplyTechnology(”' + $hashtable.($Technologie) + '”)'
            $found = $true
        }
    }
    Set-Content -Value $newcontent -Path $path
}



$Technologie = "T01"