# UKRAINE GTA Admin Tools 07 | Made by Yaroslav Sviridov
# Основна логіка нижче захищена (зашифрована). Блок автооновлення вище — звичайний текст.
$global:ToolRoot = $PSScriptRoot

# ---- Автооновлення (цей блок НЕ зашифрований — сюди можна вписати свій GitHub) ----
$RepoOwner = 'Yaroslav-SV'                  # <- ваш логін на GitHub
$RepoName  = 'ukraine-gta-admintools-07'     # <- назва репозиторію
$Branch    = 'main'
$GhToken   = ''                              # <- (необов'язково) токен для приватного репозиторію; порожньо = публічний

$global:UpdLogFile = Join-Path (Join-Path $env:APPDATA 'UkraineGtaAdminTool') 'update.log'
function Write-UpdLog($t) {
    try {
        New-Item -ItemType Directory -Force -Path (Split-Path $global:UpdLogFile) | Out-Null
        Add-Content -Path $global:UpdLogFile -Value ((Get-Date).ToString('u') + '  ' + $t)
    } catch {}
}
function Parse-UATVersion([string]$text) {
    if ($null -eq $text) { return $null }
    $t = $text.Trim()
    if (-not $t) { return $null }
    if ($t -notmatch '\.') { $t = $t + '.0' }   # "7" -> "7.0", щоб System.Version це прийняв
    try { return [version]$t } catch { return $null }
}
function ConvertTo-UATText($content) {
    # Invoke-WebRequest іноді повертає .Content як byte[] замість рядка (залежно від Content-Type відповіді) - приводимо явно.
    if ($null -eq $content) { return '' }
    if ($content -is [byte[]]) { return [System.Text.Encoding]::UTF8.GetString($content) }
    return [string]$content
}

function Test-ForUpdate([bool]$Verbose) {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $apiBase = "https://api.github.com/repos/$RepoOwner/$RepoName/contents"
        $ghHeaders = @{ 'User-Agent' = 'UkraineGtaAdminTools' }
        if ($GhToken) { $ghHeaders['Authorization'] = "token $GhToken" }
        $rawHeaders = $ghHeaders + @{ 'Accept' = 'application/vnd.github.v3.raw' }
        $localVerFile = Join-Path $global:ToolRoot 'version.txt'
        $skipFile = Join-Path $global:ToolRoot 'skip_version.txt'
        $localVerText = $null
        if (Test-Path -LiteralPath $localVerFile) { $localVerText = Get-Content -LiteralPath $localVerFile -Raw }
        $localVer = Parse-UATVersion $localVerText
        if (-not $localVer) { $localVer = [version]'0.0' }
        $skipVerText = $null
        if (Test-Path -LiteralPath $skipFile) { $skipVerText = Get-Content -LiteralPath $skipFile -Raw }
        $skipVer = Parse-UATVersion $skipVerText
        Write-UpdLog ("Перевірка. Локальна версія: $localVer. URL: $apiBase/version.txt")

        $resp = Invoke-WebRequest -Uri "$apiBase/version.txt`?ref=$Branch" -Headers $rawHeaders -UseBasicParsing -TimeoutSec 8
        $remoteVerText = ConvertTo-UATText $resp.Content
        $remoteVer = Parse-UATVersion $remoteVerText
        Write-UpdLog ("Відповідь GitHub: '" + $remoteVerText.Trim() + "' (розпізнано як: $remoteVer)")

        if (-not $remoteVer) {
            Write-UpdLog 'version.txt на GitHub не вдалося розпізнати як номер версії.'
            if ($Verbose) {
                Add-Type -AssemblyName PresentationFramework
                [void][System.Windows.MessageBox]::Show("Не вдалося перевірити оновлення: файл version.txt на GitHub не містить коректного номера версії (приклади правильного формату: 1.1, 2.0).`n`nВміст відповіді: " + $remoteVerText, 'Перевірка оновлень')
            }
            return
        }
        if ($remoteVer -le $localVer) {
            Write-UpdLog "Версія актуальна ($localVer), оновлення не потрібне."
            if ($Verbose) {
                Add-Type -AssemblyName PresentationFramework
                [void][System.Windows.MessageBox]::Show("У вас встановлена остання версія ($localVer).`n`nНа GitHub: $remoteVer.", 'Перевірка оновлень')
            }
            return
        }
        if ($skipVer -and $remoteVer -eq $skipVer -and -not $Verbose) {
            Write-UpdLog "Версію $remoteVer вже відхилено раніше — не питаю повторно автоматично."
            return
        }

        Add-Type -AssemblyName PresentationFramework
        $msg = "Доступне оновлення Admin Tools до версії $remoteVer (зараз встановлено $localVer).`n`nОновити зараз?"
        $ans = [System.Windows.MessageBox]::Show($msg, 'UKRAINE GTA Admin Tools — оновлення', 'YesNo', 'Question')
        Write-UpdLog "Користувач відповів: $ans"
        if ($ans -eq 'Yes') {
            $ufiles = 'AdminTool.ps1', 'Atools_07.ico', 'logo07.png', 'bgpattern.png'
            $tmp = Join-Path $env:TEMP ('UATupd_' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $tmp | Out-Null
            $ok = $true
            foreach ($f in $ufiles) {
                try { Invoke-WebRequest -Uri "$apiBase/$f`?ref=$Branch" -Headers $rawHeaders -OutFile (Join-Path $tmp $f) -UseBasicParsing -TimeoutSec 20 }
                catch { $ok = $false; Write-UpdLog ("Помилка завантаження " + $f + ': ' + $_.Exception.Message) }
            }
            if ($ok) {
                foreach ($f in $ufiles) { Copy-Item -LiteralPath (Join-Path $tmp $f) -Destination (Join-Path $global:ToolRoot $f) -Force }
                Set-Content -LiteralPath $localVerFile -Value $remoteVer.ToString() -Encoding ASCII
                Remove-Item -LiteralPath $skipFile -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
                Write-UpdLog "Оновлено до версії $remoteVer. Перезапуск."
                $me = Join-Path $global:ToolRoot 'AdminTool.ps1'
                Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-WindowStyle', 'Hidden', '-File', "`"$me`"")
                [System.Environment]::Exit(0)
            } else {
                Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
                [void][System.Windows.MessageBox]::Show('Не вдалося завантажити оновлення (перевірте інтернет). Запускаю поточну версію.', 'UKRAINE GTA Admin Tools')
            }
        } else {
            Set-Content -LiteralPath $skipFile -Value $remoteVer.ToString() -Encoding ASCII
        }
    } catch {
        Write-UpdLog ('Помилка перевірки: ' + $_.Exception.Message)
        if ($Verbose) {
            try {
                Add-Type -AssemblyName PresentationFramework
                [void][System.Windows.MessageBox]::Show('Не вдалося перевірити оновлення: ' + $_.Exception.Message, 'Перевірка оновлень')
            } catch {}
        }
    }
}
Test-ForUpdate $false
# ---- Кінець блоку автооновлення ----

try {
    $d = @(
'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',
'tooCf7o0'
    ) -join ''
    $h = [System.Security.Cryptography.SHA256]::Create()
    $k = $h.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(('dfcc4a3813f1bcf3' + 'af4c0171ec73f415')))
    $b = [Convert]::FromBase64String($d)
    $iv = New-Object byte[] 16
    [Array]::Copy($b, 0, $iv, 0, 16)
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Mode = 'CBC'; $aes.Padding = 'PKCS7'; $aes.Key = $k; $aes.IV = $iv
    $p = $aes.CreateDecryptor().TransformFinalBlock($b, 16, $b.Length - 16)
    $ms = New-Object System.IO.MemoryStream(, $p)
    $ds = New-Object System.IO.Compression.DeflateStream($ms, [System.IO.Compression.CompressionMode]::Decompress)
    $sr = New-Object System.IO.StreamReader($ds, [System.Text.Encoding]::UTF8)
    $c = $sr.ReadToEnd()
    Invoke-Expression $c
}
catch {
    try { Add-Type -AssemblyName PresentationFramework; [void][System.Windows.MessageBox]::Show(($_ | Out-String), 'Admin Tools') } catch {}
}
