# UKRAINE GTA Admin Tools 07 | Made by Yaroslav Sviridov
# Основна логіка нижче захищена (зашифрована). Блок автооновлення вище — звичайний текст.
$global:ToolRoot = $PSScriptRoot

# ---- Автооновлення (цей блок НЕ зашифрований — сюди можна вписати свій GitHub) ----
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $RepoOwner = 'Yaroslav-SV'                  # <- ваш логін на GitHub
    $RepoName  = 'ukraine-gta-admintools-07'     # <- назва репозиторію
    $Branch    = 'main'
    if ($RepoOwner -ne 'YOUR_GITHUB_USERNAME_PLACEHOLDER') {
        $base = "https://raw.githubusercontent.com/$RepoOwner/$RepoName/$Branch"
        $localVerFile = Join-Path $global:ToolRoot 'version.txt'
        $skipFile = Join-Path $global:ToolRoot 'skip_version.txt'
        $localVer = 0
        if (Test-Path -LiteralPath $localVerFile) { [void][int]::TryParse((Get-Content -LiteralPath $localVerFile -Raw).Trim(), [ref]$localVer) }
        $skipVer = -1
        if (Test-Path -LiteralPath $skipFile) { [void][int]::TryParse((Get-Content -LiteralPath $skipFile -Raw).Trim(), [ref]$skipVer) }
        $resp = Invoke-WebRequest -Uri "$base/version.txt" -UseBasicParsing -TimeoutSec 6
        $remoteVer = 0
        if ([int]::TryParse($resp.Content.Trim(), [ref]$remoteVer) -and $remoteVer -gt $localVer -and $remoteVer -ne $skipVer) {
            Add-Type -AssemblyName PresentationFramework
            $msg = "Доступне оновлення Admin Tools до версії $remoteVer (зараз встановлено $localVer).`n`nОновити зараз?"
            $ans = [System.Windows.MessageBox]::Show($msg, 'UKRAINE GTA Admin Tools — оновлення', 'YesNo', 'Question')
            if ($ans -eq 'Yes') {
                $ufiles = 'AdminTool.ps1', 'Atools_07.ico', 'logo07.png', 'bgpattern.png'
                $tmp = Join-Path $env:TEMP ('UATupd_' + [guid]::NewGuid().ToString('N'))
                New-Item -ItemType Directory -Path $tmp | Out-Null
                $ok = $true
                foreach ($f in $ufiles) {
                    try { Invoke-WebRequest -Uri "$base/$f" -OutFile (Join-Path $tmp $f) -UseBasicParsing -TimeoutSec 20 } catch { $ok = $false }
                }
                if ($ok) {
                    foreach ($f in $ufiles) { Copy-Item -LiteralPath (Join-Path $tmp $f) -Destination (Join-Path $global:ToolRoot $f) -Force }
                    Set-Content -LiteralPath $localVerFile -Value $remoteVer -Encoding ASCII
                    Remove-Item -LiteralPath $skipFile -Force -ErrorAction SilentlyContinue
                    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
                    $me = $MyInvocation.MyCommand.Path
                    Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-WindowStyle', 'Hidden', '-File', "`"$me`"")
                    return
                } else {
                    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
                    [void][System.Windows.MessageBox]::Show('Не вдалося завантажити оновлення (перевірте інтернет). Запускаю поточну версію.', 'UKRAINE GTA Admin Tools')
                }
            } else {
                Set-Content -LiteralPath $skipFile -Value $remoteVer -Encoding ASCII
            }
        }
    }
} catch {}
# ---- Кінець блоку автооновлення ----

try {
    $d = @(
'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'
    ) -join ''
    $h = [System.Security.Cryptography.SHA256]::Create()
    $k = $h.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(('d1cf857433066efe' + 'bd7316875bf17c99')))
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
