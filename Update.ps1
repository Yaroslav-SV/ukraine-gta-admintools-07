# UKRAINE GTA Admin Tools — автооновлення
# Нічого небезпечного тут немає: файл лише звіряє номер версії на GitHub і, якщо є новіша,
# підмінює AdminTool.ps1 / Atools_07.ico / logo07.png. Якщо інтернету немає — просто завершується.
$ErrorActionPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ==== НАЛАШТУЙТЕ ПІД СВІЙ РЕПОЗИТОРІЙ ====
$RepoOwner = 'YOUR_GITHUB_USERNAME'   # <- ваш логін на GitHub
$RepoName  = 'YOUR_REPO_NAME'         # <- назва репозиторію
$Branch    = 'main'                   # <- зазвичай "main", міняти не потрібно
# ==========================================

$root = $PSScriptRoot
$logFile = Join-Path (Join-Path $env:APPDATA 'UkraineGtaAdminTool') 'update.log'
function Log($t) {
    try {
        New-Item -ItemType Directory -Force -Path (Split-Path $logFile) | Out-Null
        Add-Content -Path $logFile -Value ((Get-Date).ToString('u') + '  ' + $t)
    } catch {}
}

if ($RepoOwner -eq 'YOUR_GITHUB_USERNAME') { Log 'Репозиторій ще не налаштовано — пропускаю перевірку.'; return }

$base = "https://raw.githubusercontent.com/$RepoOwner/$RepoName/$Branch"
$localVerFile = Join-Path $root 'version.txt'
$localVer = 0
if (Test-Path -LiteralPath $localVerFile) { [void][int]::TryParse((Get-Content -LiteralPath $localVerFile -Raw).Trim(), [ref]$localVer) }

try {
    $resp = Invoke-WebRequest -Uri "$base/version.txt" -UseBasicParsing -TimeoutSec 6
    $remoteVer = 0
    if ([int]::TryParse($resp.Content.Trim(), [ref]$remoteVer) -and $remoteVer -gt $localVer) {
        Log "Знайдено новішу версію $remoteVer (поточна $localVer). Качаю оновлення…"
        $files = 'AdminTool.ps1', 'Atools_07.ico', 'logo07.png'
        $tmp = Join-Path $env:TEMP ('UATupd_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp | Out-Null
        $ok = $true
        foreach ($f in $files) {
            try { Invoke-WebRequest -Uri "$base/$f" -OutFile (Join-Path $tmp $f) -UseBasicParsing -TimeoutSec 20 }
            catch { $ok = $false; Log ("Не вдалося завантажити " + $f + ': ' + $_.Exception.Message) }
        }
        if ($ok) {
            foreach ($f in $files) { Copy-Item -LiteralPath (Join-Path $tmp $f) -Destination (Join-Path $root $f) -Force }
            Set-Content -LiteralPath $localVerFile -Value $remoteVer -Encoding ASCII
            Log "Оновлено до версії $remoteVer."
        } else {
            Log 'Оновлення перервано через помилку завантаження — лишаю стару версію.'
        }
        Remove-Item -LiteralPath $tmp -Recurse -Force
    } else {
        Log "Версія актуальна ($localVer)."
    }
} catch {
    Log ('Перевірку оновлень пропущено (немає інтернету чи GitHub недоступний): ' + $_.Exception.Message)
}
