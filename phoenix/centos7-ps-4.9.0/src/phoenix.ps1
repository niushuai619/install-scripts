﻿Param(
    [parameter(Mandatory=$true)]$envfile,
    [parameter(Mandatory=$true)] $action,
    [string]$remainingArguments
)

# insert-common-script-here:powershell/PsCommon.ps1
# insert-common-script-here:powershell/LinuxUtil.ps1

Get-Command java
# 

function ConvertTo-DecoratedEnv {
    Param([parameter(ValueFromPipeline=$True)]$myenv)

    if (($myenv.box.hostname -eq $myenv.box.ip) -and ("HbaseMaster" -in $myenv.myRoles)) {
        Write-Error "Hbase Master must has a hostname"
    }

    $masterBox = $myenv.boxGroup.boxes | Where-Object {($_.roles -split ",") -contains "HbaseMaster"} | Select-Object -First 1
    $regionServerBoxes = $myenv.boxGroup.boxes | Where-Object {($_.roles -split ",") -contains "RegionServer"}

    $myenv | Add-Member -MemberType NoteProperty -Name masterBox -Value $masterBox
    $myenv | Add-Member -MemberType NoteProperty -Name regionServerBoxes -Value $regionServerBoxes
    $myenv | Add-Member -MemberType NoteProperty -Name tgzFile -Value ($myenv.getUploadedFile("apache-phoenix-.*\.tar\.gz"))
    $myenv
}

function Install-Phoenix {
    Param($myenv)
    if (("HbaseMaster" -in $myenv.myRoles) -or ("RegionServer" -in $myenv.myRoles)) {
        $hdir = $myenv.boxGroup.installResults.hbase.dirInfo.hbaseDir | Join-Path -ChildPath "lib"
        if (-not (Test-Path $hdir)) {
            "cannot find hbase lib directory" | Write-Error
        }
        if (Test-Path $myenv.tgzFile -PathType Leaf) {
            Start-Untgz $myenv.tgzFile -DestFolder $myenv.InstallDir | Write-HostIfInTesting
            # found server-jar from unziped folder.
            # copy to hbase lib folder.
        } else {
            $myenv.tgzFile + " Doesn't exists." | Write-Error
        }
    } else {
        "box isn't a HbaseMaster nor RegionServer either." | Write-Error
    }
}

function Start-ExposeEnv {
    Param($myenv)
    if (Test-Path $myenv.resultFile) {
        $rh = Get-Content $myenv.resultFile | ConvertFrom-Json
        Add-AsHtScriptMethod $rh
        $envhash =  $rh.asHt("env")
        $envhash.GetEnumerator() | ForEach-Object {
            Set-Content -Path "env:$($_.Key)" -Value $_.Value
        }

        if (!$envhash.javahome) {
            Set-Content -Path "env:JAVA_HOME" -Value (Get-JavaHome)
        }
    }
}

$myenv = New-EnvForExec $envfile | ConvertTo-DecoratedEnv

switch ($action) {
    "install" {
        Install-Hbase $myenv
    }
    "t" {
        # do nothing
    }
    default {
        Write-Error -Message ("Unknown action {0}"  -f $action)
    }
}

Write-SuccessResult