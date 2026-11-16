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
        $remoteVer = Parse-UATVersion $resp.Content
        Write-UpdLog ("Відповідь GitHub: '" + $resp.Content.Trim() + "' (розпізнано як: $remoteVer)")

        if (-not $remoteVer) {
            Write-UpdLog 'version.txt на GitHub не вдалося розпізнати як номер версії.'
            if ($Verbose) {
                Add-Type -AssemblyName PresentationFramework
                [void][System.Windows.MessageBox]::Show("Не вдалося перевірити оновлення: файл version.txt на GitHub не містить коректного номера версії (приклади правильного формату: 1.1, 2.0).`n`nВміст відповіді: " + $resp.Content, 'Перевірка оновлень')
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
                exit
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
'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'
    ) -join ''
    $h = [System.Security.Cryptography.SHA256]::Create()
    $k = $h.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(('140498f01afc39df' + '6f824beab78e235d')))
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
