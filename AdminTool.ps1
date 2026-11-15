# UKRAINE GTA Admin Tools 07 | Made by Yaroslav Sviridov
# Основна логіка нижче захищена (зашифрована). Блок автооновлення вище — звичайний текст.
$global:ToolRoot = $PSScriptRoot

# ---- Автооновлення (цей блок НЕ зашифрований — сюди можна вписати свій GitHub) ----
$RepoOwner = 'Yaroslav-SV'                  # <- ваш логін на GitHub
$RepoName  = 'ukraine-gta-admintools-07'     # <- назва репозиторію
$Branch    = 'main'

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
        $base = "https://raw.githubusercontent.com/$RepoOwner/$RepoName/$Branch"
        $localVerFile = Join-Path $global:ToolRoot 'version.txt'
        $skipFile = Join-Path $global:ToolRoot 'skip_version.txt'
        $localVerText = $null
        if (Test-Path -LiteralPath $localVerFile) { $localVerText = Get-Content -LiteralPath $localVerFile -Raw }
        $localVer = Parse-UATVersion $localVerText
        if (-not $localVer) { $localVer = [version]'0.0' }
        $skipVerText = $null
        if (Test-Path -LiteralPath $skipFile) { $skipVerText = Get-Content -LiteralPath $skipFile -Raw }
        $skipVer = Parse-UATVersion $skipVerText
        Write-UpdLog ("Перевірка. Локальна версія: $localVer. URL: $base/version.txt")

        $resp = Invoke-WebRequest -Uri "$base/version.txt" -UseBasicParsing -TimeoutSec 8
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
                try { Invoke-WebRequest -Uri "$base/$f" -OutFile (Join-Path $tmp $f) -UseBasicParsing -TimeoutSec 20 }
                catch { $ok = $false; Write-UpdLog ("Помилка завантаження " + $f + ': ' + $_.Exception.Message) }
            }
            if ($ok) {
                foreach ($f in $ufiles) { Copy-Item -LiteralPath (Join-Path $tmp $f) -Destination (Join-Path $global:ToolRoot $f) -Force }
                Set-Content -LiteralPath $localVerFile -Value $remoteVer.ToString() -Encoding ASCII
                Remove-Item -LiteralPath $skipFile -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
                Write-UpdLog "Оновлено до версії $remoteVer. Перезапуск."
                $me = $MyInvocation.MyCommand.Path
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
    $k = $h.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(('9878b72662041249' + '4a9c2cfab4116f31')))
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
