# UKRAINE GTA Admin Tools 07 | Made by Yaroslav Sviridov
# Основна логіка нижче захищена (зашифрована). Блок автооновлення вище — звичайний текст.
$global:ToolRoot = $PSScriptRoot

# ---- Автооновлення (цей блок НЕ зашифрований — сюди можна вписати свій GitHub) ----
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $RepoOwner = 'Yaroslav-SV'            # <- ваш логін на GitHub
    $RepoName  = 'ukraine-gta-admintools-07'  # <- назва репозиторію
    $Branch    = 'main'
    if ($RepoOwner -ne 'YOUR_GITHUB_USERNAME_PLACEHOLDER') {
        $base = "https://raw.githubusercontent.com/$RepoOwner/$RepoName/$Branch"
        $localVerFile = Join-Path $global:ToolRoot 'version.txt'
        $localVer = 0
        if (Test-Path -LiteralPath $localVerFile) { [void][int]::TryParse((Get-Content -LiteralPath $localVerFile -Raw).Trim(), [ref]$localVer) }
        $resp = Invoke-WebRequest -Uri "$base/version.txt" -UseBasicParsing -TimeoutSec 6
        $remoteVer = 0
        if ([int]::TryParse($resp.Content.Trim(), [ref]$remoteVer) -and $remoteVer -gt $localVer) {
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
                Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
                $me = $MyInvocation.MyCommand.Path
                Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-WindowStyle', 'Hidden', '-File', "`"$me`"")
                return
            }
            Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
} catch {}
# ---- Кінець блоку автооновлення ----

try {
    $d = @(
'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'
    ) -join ''
    $h = [System.Security.Cryptography.SHA256]::Create()
    $k = $h.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(('3e2c881729d2000b' + '0a9fa49141221102')))
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
