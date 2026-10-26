param([int]$Port=25497, [int]$TimeoutMinutes=8, [string]$Python='')
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$root=Join-Path $repo 'tmp/herald-probe'
$build=Join-Path $root 'build'
$runtime=Join-Path $root ('run-'+[guid]::NewGuid().ToString('N'))
$daemon=$null
if(!$Python){
    $pythonCommand=Get-Command py -ErrorAction SilentlyContinue
    if(!$pythonCommand){$pythonCommand=Get-Command python -ErrorAction Stop}
    $Python=(& $pythonCommand.Source -c 'import sys; print(sys.executable)').Trim()
}
if(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue){throw 'Probe port already occupied.'}
New-Item -ItemType Directory -Path $build,$runtime -Force | Out-Null
try {
    $source=Get-Content -LiteralPath (Join-Path $repo 'roguetown.dme') -Raw
    $dirs=@('icons','sound','html','strings','tgui','goon')
    $dirs+=@(Get-ChildItem -LiteralPath $repo -Directory -Filter 'modular*'|Select-Object -ExpandProperty Name)
    foreach($m in [regex]::Matches($source,'(?m)^\s*#include\s+"([^"]+)"')){
        $dirs+=($m.Groups[1].Value -split '[\\/]')[0]
    }
    foreach($dir in ($dirs|Sort-Object -Unique)){
        $target=Join-Path $repo $dir
        $link=Join-Path $build $dir
        if(!(Test-Path -LiteralPath $target -PathType Container)){continue}
        if(!(Test-Path -LiteralPath $link)){New-Item -ItemType Junction -Path $link -Target $target|Out-Null}
        elseif((Get-Item -LiteralPath $link).LinkType -ne 'Junction' -or (Get-Item -LiteralPath $link).Target -ne $target){throw 'Unexpected build input.'}
    }
    $prefix="#define NO_DUNGEON`r`n#define USE_CUSTOM_ERROR_HANDLER`r`n#define FORCE_MAP `"tmp/herald-probe/map.json`"`r`n"
    [IO.File]::WriteAllText((Join-Path $build 'probe.dme'), ($prefix+$source+"`r`n#include `"../../../tools/herald/game_probe.dm`"`r`n#include `"../../../tools/herald/cases_probe.dm`"`r`n"), [Text.UTF8Encoding]::new($false))
    $output=& 'C:/Program Files (x86)/BYOND/bin/dm.exe' (Join-Path $build 'probe.dme') 2>&1
    $output|Set-Content -LiteralPath (Join-Path $root 'compile.log') -Encoding utf8
    $output|Select-Object -Last 4
    if($LASTEXITCODE -ne 0 -or ($output -join "`n") -notmatch '0 errors, 0 warnings'){throw 'Probe compilation failed.'}
    Copy-Item -LiteralPath (Join-Path $build 'probe.dmb'),(Join-Path $build 'probe.rsc') -Destination $runtime
    foreach($dir in @('_maps','strings','html','modular','modular_rmh','modular_twilight_axis')){
        $target=Join-Path $repo $dir
        if(Test-Path -LiteralPath $target){Copy-Item -LiteralPath $target -Destination (Join-Path $runtime $dir) -Recurse}
    }
    $cfg=Join-Path $runtime 'config'
    $maps=Join-Path $runtime 'tmp/herald-probe'
    New-Item -ItemType Directory -Path $cfg,$maps,(Join-Path $runtime 'icons') -Force|Out-Null
    Get-ChildItem -LiteralPath (Join-Path $repo 'config/example') -File|Copy-Item -Destination $cfg
    foreach($dir in @('roguetown','title_music','title_screens','jukebox_music','arenas')){
        $target=Join-Path $repo ('config/'+$dir)
        if(Test-Path -LiteralPath $target){Copy-Item -LiteralPath $target -Destination (Join-Path $cfg $dir) -Recurse}
    }
    foreach($name in @('maps.txt','mapsrw.txt','policy.json','silicon_laws.txt','in_character_filter.txt')){
        $target=Join-Path $repo ('config/'+$name)
        if(Test-Path -LiteralPath $target){Copy-Item -LiteralPath $target -Destination $cfg}
    }
    # Prove both settings work in the normal config.txt, without extra files.
    @('$include game_options.txt','$include resources.txt',
      'HERALD_READONLY_KEY DO_NOT_LOG_HERALD_KEY',
      ('HERALD_READONLY_KEY '+('a'*64)),
      'WEBHOOK_ADMINHELP https://discord.com/api/webhooks/123/testtoken',
      'WEBHOOK_ADMINHELP https://discord.com/api/webhooks/123/testtoken',
      'WEBHOOK_CUSTOM_EMOTES https://discord.com/api/webhooks/456/emotetesttoken',
      'WEBHOOK_CUSTOM_EMOTES https://discord.com/api/webhooks/456/emotetesttoken',
      'HERALD_ADMIN_OPERATOR_IDS 2',
      'HERALD_DUTY_ENABLED 1',
      'HERALD_SDQL_ENABLED 1',
      'HERALD_CASES_ENABLED 1',
      'HERALD_DELEGATED_ADMIN_ENABLED 1',
      'HERALD_CASE_ROLE_IDS 3,4',
      'HERALD_SANCTION_ROLE_IDS 3',
      'HERALD_ADMIN_CKEY heraldadminprobe')|Set-Content -LiteralPath (Join-Path $cfg 'config.txt') -Encoding ascii
    Get-ChildItem -LiteralPath $repo -File -Filter '*.dll'|Copy-Item -Destination $runtime
    foreach($icon in @('title_static.png','rogueworld_title.dmi','tg_32.png')){
        Copy-Item -LiteralPath (Join-Path $repo ('icons/'+$icon)) -Destination (Join-Path $runtime 'icons')
    }
    $map=Get-Content -LiteralPath (Join-Path $repo '_maps/roguetest.json') -Raw|ConvertFrom-Json
    $map.other_z=@()
    $map.map_name='Herald isolated read probe'
    $map|ConvertTo-Json -Depth 20|Set-Content -LiteralPath (Join-Path $maps 'map.json') -Encoding ascii
    $daemon=Start-Process -FilePath 'C:/Program Files (x86)/BYOND/bin/dd.exe' -ArgumentList @('probe.dmb',$Port,'-invisible','-trusted','-close') -WorkingDirectory $runtime -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $runtime 'daemon.log') -RedirectStandardError (Join-Path $runtime 'daemon-error.log')
    Write-Output "Local probe started: PID=$($daemon.Id), port=$Port"
    $deadline=(Get-Date).AddMinutes($TimeoutMinutes)
    $reportPath=Join-Path $runtime 'probe-report.json'
    while(!(Test-Path -LiteralPath $reportPath)){
        Start-Sleep -Seconds 2
        $daemon.Refresh()
        if($daemon.HasExited){throw 'Probe daemon exited. Inspect tmp/herald-probe runtime logs.'}
        if((Get-Date) -gt $deadline){throw 'Local probe timed out.'}
    }
    $report=Get-Content -LiteralPath $reportPath -Raw|ConvertFrom-Json
    $report.checks|ForEach-Object{Write-Output "$(if($_.passed){'PASS'}else{'FAIL'}) $($_.name) $($_.detail)"}
    if(!$report.passed){throw 'Local game checks failed.'}
    # Standard-library client; no desktop bot, API key or external app required.
    & $Python (Join-Path $repo 'tools/herald/wire_probe.py') $Port
    if($LASTEXITCODE -ne 0){throw 'Real BYOND wire test failed.'}
    $findings=Get-ChildItem -LiteralPath $runtime -Recurse -File -Filter '*.log'|Select-String -Pattern 'runtime error:|uncaught runtime|Exception occurred'
    if($findings){throw 'Probe log has runtime errors.'}
    $secretFindings=Get-ChildItem -LiteralPath $runtime -Recurse -File -Filter '*.log'|Select-String -SimpleMatch -Pattern 'DO_NOT_LOG_HERALD_KEY',('a'*64),'https://discord.com/api/webhooks/123/testtoken','https://discord.com/api/webhooks/456/emotetesttoken'
    if($secretFindings){throw 'Hidden config credential appeared in probe logs.'}
    Write-Output 'PASS hidden_config_validation_and_duplicate_values_redacted'
    Write-Output 'HERALD_GAME_PROBE_OK: real SDQL read templates + server relay + signed Topic reads.'
} finally {
    if($daemon){$daemon.Refresh();if(!$daemon.HasExited){Stop-Process -Id $daemon.Id;$daemon.WaitForExit(10000)|Out-Null}}
    $next=Join-Path $runtime 'data/next_map.json'
    if(Test-Path -LiteralPath $next){Remove-Item -LiteralPath $next}
}
