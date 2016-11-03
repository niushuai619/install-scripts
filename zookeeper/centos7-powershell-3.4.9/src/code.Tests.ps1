﻿$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'

$codefile = Join-Path -Path $here -ChildPath $sut

$testTgzFolder = Join-Path -Path $here -ChildPath "../../../tgzFolder" -Resolve

$commonPath = Join-Path -Path $here -ChildPath "\..\..\..\src\main\resources\com\jianglibo\easyinstaller\scriptsnippets\powershell\PsCommon.Ps1" -Resolve
. $commonPath

. (Join-Path -Path $here -ChildPath "\..\..\..\src\main\resources\com\jianglibo\easyinstaller\scriptsnippets\powershell\CentOs7Util.Ps1" -Resolve)

$envfile = Join-Path -Path (Split-Path -Path $here -Parent) -ChildPath fixtures/envforcodeexec.json -Resolve

$resutl = . $codefile -envfile $envfile -codefile $codefile

<#
ZOOBINDIR=/opt/zookeeper/zookeeper-3.4.9/bin
ZOOBINDIR,ZOOCFGDIR, insert to /opt/zookeeper/zookeeper-3.4.9/bin/zkEnv.sh before line ZOOBINDIR="${ZOOBINDIR:-/usr/bin}"
others can put into : "${ZOOCFGDIR}/zookeeper-env.sh": ZOOCFG,ZOO_LOG_DIR,ZOO_LOG4J_PROP, even JAVA_HOME
#>


Describe "code" {

    It "should deco env" {
        $decorated = (New-EnvForExec $envfile | Decorate-Env)
        $decorated.DataDir | Should Be "/var/lib/zookeeper/"
        ($decorated.configFolder -replace '\\','/') | Should Be "/var/zookeeper"
        $decorated.configFile | Should Be "/var/zookeeper/zoo.cfg"
        $decorated.installTo | Should Be "/opt/zookeeper"
        $decorated.serviceLines -join "," | Should Be "server.110=192.168.33.110:2888:3888,server.111=a1.host.name:2888:3888,server.112=a2.host.name:2888:3888"
        $decorated.zkconfigLines -join "," | Should Be "clientPort=2181,dataDir=/var/lib/zookeeper/,dataLogDir=/var/lib/zookeeper/,initLimit=5,syncLimit=2,tickTime=1999"

        $decorated.software.runas | Should Be "zookeeper"



        $decorated.allFolders.Count |  Should Be 4

        $decorated.allFolders[0] | Should Be "/opt/zookeeper"
        $decorated.allFolders[1] | Should Be "/opt/zookeeper/logs"
        $decorated.allFolders[2] | Should Be "/var/lib/zookeeper/"
        $decorated.allFolders[3] | Should Be "/var/zookeeper"
    }
    It "should be installed" {
        if (!$IsLinux) {
            return
        }
        $decorated = (New-EnvForExec $envfile | Decorate-Env)
        $fixtureFile = Join-Path $testTgzFolder -ChildPath $decorated.getUploadedFile("", $True)
        $tgzFile = $decorated.getUploadedFile()

        if (-not (Test-Path $tgzFile)) {
            if (Test-Path $fixtureFile -PathType Leaf) {
                Copy-Item $fixtureFile $tgzFile
            }
        }

        Install-Zk $decorated
        Test-Path $decorated.installTo | Should Be $True
        Test-Path $decorated.DataDir | Should Be $True
        Test-Path $decorated.configFolder | Should Be $True
        Test-Path $decorated.configFile | Should Be $True

        Centos7-GetRunuserCmd -myenv $decorated | Should Be 'runuser -s /bin/bash -c "/opt/zookeeper/zookeeper-3.4.9/bin/zkServer.sh" zookeeper'

        $decorated.resultFile -replace "\\", "/" | Should Be "/opt/easyinstaller/results/zookeeper-CentOs7-powershell-3.4.9/easyinstaller-result.json"
        (Get-Content $decorated.resultFile | ConvertFrom-Json).executable | Should be "/opt/zookeeper/zookeeper-3.4.9/bin/zkServer.sh"

        $r = Change-Status -myenv $decorated -action start | Out-String

        if ($r -match "already running as") {
            Change-Status -myenv $decorated -action stop
        }
        $r = Change-Status -myenv $decorated -action start | Out-String
        $r -match "already running as" | Should Be $False
        
        Change-Status -myenv $decorated -action status

    }
}
