function Compare-Content {
    [CmdletBinding()]
    param (
        [String]$FilePath1,
        [String]$FilePath2
    )

    $Content1 = Get-Content $FilePath1 | Where-Object {$_.trim() -ne "" }
    $Content2 = Get-Content $FilePath2 | Where-Object {$_.trim() -ne "" }
    
    $Comparison = Compare-Object -ReferenceObject $Content1 -DifferenceObject $Content2


    if (($Comparison.Count) -gt 0){
        [String]$Count = ($Comparison.InputObject).Count
        [String]$Output = $Count + " Diffs were found:"
        Write-Output $Output
        $Comparison
    }

    else {
        Write-Host "Everything fine!!" -ForegroundColor Green
    }


}

# Compare-Content -FilePath1 "C:\Code\postprozessor\Testing\Druecken auf M200\01_vorher\1_SeiteL_Lichtgr_6.535_T01_1.xcs" -FilePath2 "C:\Code\postprozessor\Testing\Druecken auf M200\02_nachher\1_SeiteL_Lichtgr_6.535_T01_1.xcs"