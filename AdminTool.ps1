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

function Test-ForUpdate([bool]$Verbose) {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $base = "https://raw.githubusercontent.com/$RepoOwner/$RepoName/$Branch"
        $localVerFile = Join-Path $global:ToolRoot 'version.txt'
        $skipFile = Join-Path $global:ToolRoot 'skip_version.txt'
        $localVer = 0
        if (Test-Path -LiteralPath $localVerFile) { [void][int]::TryParse((Get-Content -LiteralPath $localVerFile -Raw).Trim(), [ref]$localVer) }
        $skipVer = -1
        if (Test-Path -LiteralPath $skipFile) { [void][int]::TryParse((Get-Content -LiteralPath $skipFile -Raw).Trim(), [ref]$skipVer) }
        Write-UpdLog ("Перевірка. Локальна версія: $localVer. URL: $base/version.txt")

        $resp = Invoke-WebRequest -Uri "$base/version.txt" -UseBasicParsing -TimeoutSec 8
        $remoteVer = 0
        $parsed = [int]::TryParse($resp.Content.Trim(), [ref]$remoteVer)
        Write-UpdLog ("Відповідь GitHub: '" + $resp.Content.Trim() + "' (число: $parsed / $remoteVer)")

        if (-not $parsed) {
            Write-UpdLog 'version.txt на GitHub не вдалося розпізнати як число.'
            if ($Verbose) {
                Add-Type -AssemblyName PresentationFramework
                [void][System.Windows.MessageBox]::Show("Не вдалося перевірити оновлення: файл version.txt на GitHub не містить числа.`n`nВміст відповіді: " + $resp.Content, 'Перевірка оновлень')
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
        if ($remoteVer -eq $skipVer -and -not $Verbose) {
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
                Set-Content -LiteralPath $localVerFile -Value $remoteVer -Encoding ASCII
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
            Set-Content -LiteralPath $skipFile -Value $remoteVer -Encoding ASCII
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
    $k = $h.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(('1a7a490071cea03f' + 'c2a3d831c630bbfb')))
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
