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
'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',
'gQvx/zKhP2dLBhuLu/c0mNTkL4X+dIJw=='
    ) -join ''
    $h = [System.Security.Cryptography.SHA256]::Create()
    $k = $h.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(('105cdf561214321f' + '664bd2b1291be5a8')))
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
