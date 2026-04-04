# Parity with GEDR JobSuiteHealth: writable data dirs + optional YARA presence.
$AgentsAvBin = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Bin'))
. (Join-Path $AgentsAvBin '_JobLog.ps1')

function Test-DirWritable {
    param([string]$Label, [string]$Path)
    try {
        if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
        $probe = Join-Path $Path '.av_write_probe'
        [System.IO.File]::WriteAllText($probe, (Get-Date).ToString('o'))
        Remove-Item -LiteralPath $probe -Force -ErrorAction Stop
        return 0
    } catch {
        Write-JobLog "[SuiteHealth] $Label not writable ($Path): $_" "WARNING" "suite_health.log"
        return 1
    }
}

function Invoke-SuiteHealthRun {
    try {
        $issues = 0
        $base = "$env:ProgramData\Antivirus"
        $issues += Test-DirWritable 'Logs' (Join-Path $base 'Logs')
        $issues += Test-DirWritable 'Quarantine' (Join-Path $base 'Quarantine')
        $issues += Test-DirWritable 'Data' (Join-Path $base 'Data')
        $issues += Test-DirWritable 'Reports' (Join-Path $base 'Reports')

        $yara = $null
        foreach ($c in @($AgentsAvBin, (Split-Path $AgentsAvBin -Parent))) {
            $p = Join-Path $c 'yara.exe'
            if (Test-Path -LiteralPath $p) { $yara = $p; break }
        }
        if (-not $yara) {
            $issues++
            Write-JobLog '[SuiteHealth] yara.exe not found next to Bin or repo root.' 'WARNING' 'suite_health.log'
        }
        $rules = @(
            (Join-Path $env:ProgramData 'Antivirus\Yara\rules.yar'),
            (Join-Path $env:ProgramData 'Antivirus\Rules\rules.yar'),
            (Join-Path $AgentsAvBin 'YaraRules\rules.yar')
        ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
        if (-not $rules) {
            $issues++
            Write-JobLog '[SuiteHealth] rules.yar not found under ProgramData or Bin\YaraRules.' 'WARNING' 'suite_health.log'
        }
        if ($issues -eq 0) {
            Write-JobLog '[SuiteHealth] OK - paths writable, YARA/rules present.' 'INFO' 'suite_health.log'
        }
    } catch {
        Write-JobLog "[SuiteHealth] $_" 'ERROR' 'suite_health.log'
    }
}

if ($MyInvocation.InvocationName -ne '.') { Invoke-SuiteHealthRun }
