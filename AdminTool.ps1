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
'WV6HHLSoEwje9mBT2vNwyxnwMwKVTqtBdLhNj35w2wn7wPsq6UL7C+TZAWwpx55So71OITUjN626PeULMjWlEffHsLAIaBJ0v61QJ6BPVwKXVG',
'pwcdzabR1lPQer/5F0rNXZ47EDQ+sEEZLoOY/NQBsyADHxjHr61mGhnnrmmf1q7BKOdWEvlx6rSSpAVT4+u8Vu2G2IKo3EySf2LQBY85GGuoOb',
'inK8mDXBKiiob0O/KaQ+Wtple6EYK1hqGTeP4pDKEiwga5zlUPK683ikHdtMHhPJ31qvskKnI8tFKP+cD/4hF92lDvlC7D+L6hxqIo5hVNX41x',
'ulnmz3KaG7JFoZqpvUz5rHprSLMRCTBP2uhH56eIeo/wMuMyrc5RfJ4DMBbL2DMcw+TM3ICey/Ks5dIR0c9AtE7+Djk0z4VXv6IB6JDEFBNdk3',
'4msBnIiAjT7uQ2jiphtB+1Fmp8BQAU0DYYyV4Wl33jMTYam7F6J46DQUWkxPUj2SF/aEsxFGhLUwt6MVt9SK74np6EXay7ERQeROIT07JZ1a0m',
'Tw54jn+9JRPstfqhcH+wcrR/6/v07oTyft1u/3INiyD036Vqzn5KOQe0kc7gZrLPgBuDbWb1TbXfnrcrhkYv7ScgBiz5r/XmmO/Xz6f1cFONDO',
'turvO7+tW0lxKR8citx4aHYxIFmaiPbEZ0lhXDZ+eQ9cJdYz2gUdmR/SlMMwV9Jy2hooGn+eZzO13vDstGA4+QxYzx3uIJy5FfYAr41s/Tt+vO',
'7l8+psadx0YKK/F6o4va9zA1D5vlYFpCSm3tzMUMI69TAH1uq0l1G3wcBE9mtyBMp/qK4L7whL28JZQ6aEVH14uPq0RLmaQTLx7ixEusWkFIlX',
'Z8qHi4CmEVonSwBSN1IrwCsofytfunI9cLfejfCtfETe6m0GQ67hBcwB/X8xEHUAy9Fuo28xlDqpdUoKKfoxXnwCljJGqMDZcg52lX6gON/0uZ',
'a7XyCyOMb6yyTX2ejwIISVqzSEoDjonTPfnpmhQ6qF+K8xplhQzlS10ToTByKniwUioEz/8oZbmxJ03jRb6iGEtnUkhcjrZMKR0TFPPlbaJm8G',
'rHWjZFXMpsPxRqy2aX8vQdCt5YIKFoLf3yAEGyIq9FdVrSy0Zgo2B0e8SlgANxiHIAgLgLCGcUxX3/LFZfmmc8gDWYXjDlYdgcXi2HkKdcY0X6',
'KE+mCyiuCiJIBoppKsH/f29q4aF5NcutAVbWdN40PIEYd7Q+sEpQGZn+HWxQM0Iqpg9O5506uP7yLM8dQg6Skf7RA29vuexEyvs77L8i9CO4Hk',
'AJL4QfGRA3wwpzHPnrznyOITqiZBLMEVcD8O9VDhJIAt34CUOzSFHLS6qDTQHfPra5Vx/3hQMYLhVeSGVNk3p8oOCF6zCZkIPHN9UlHKk73HZv',
'grS+YXXT4Eh76As50ntAFkt5lS2Iq+ZkjjEmms4COYGUVN03G1r8qCB0WArSGBCUB15gSci8UjHz+YNkHWYZS3LYu7mIklLcD6hCZ3kX8AyBPT',
'9rRN7ToRfdvdLhkjg/Y73bzTVib6g+WahULmYGGGw27U9Jk7+LFwowX9WSvZYS7KlyDTXV+GZHdw9PAWVWVZq8e7PCVohMw1s+uua4Jb6K9k9t',
'9u5XXqpFPUfkeLpHj/NCoqvcbv6RG4QgSk//UlIqAqnbRQdhfGJNJhR+zRotokyo1loXXM5v0XeeRWFhd2B7hkrXxMHkkFXhxbcYS8eQehCKi8',
'J9oL2+XOtXCv2CvBzbcp3n07BtPO/Ge64JT3797dIGhKdW7QFtT9PxXlKp/CJjxRWIKPWF3lVNLka1YqF1pv5tSKNB+ZPuBX1nK4/GenN7C8uV',
'3TCytSd6DmKIeQgd4Hd8Svk2BfwNaErcmkOYaHfg/C96qcG9f0XGoajjmSNIS1XUAK9jMXSlEeIqmVwkdj0rsIjgFdBNZQK8vew9bTqLdS3d1Y',
'IPwvq2EeoYOzJisBhBxaq2ais6ZneOWAnWAoV262KXaEa675lXZ9O54ysfYnE4BLo/pXIsTRYW3I/s+UPkTR3Ifxjt+YsCzidfh57G8ucm/4pb',
'uAORgrJYATglAzjrLRAws9Uji2chVLQUCNjrExUr2juNhAJXcJvZxlxEd1ZPAbU+Hs4NFjl5YElslZbs3elMpkjFx5a2Ch8KJVGaAJRtNtlQNN',
'dvIYyuy/zG9b5kr+0UdW+9mvkaiJw4LuM8G7QnACh/tFLJPtmeStLGCFhWchwvMZ+oTLWRbgf8JU2D5RT70InLyl3IcAGVlcr9YVAe/s/kJzGV',
'kyFFoYU2S9THrpb2NzBZAyPN/5hHCFdObNRvb5wNaXOJb2vsjF7Q7IVx/uRhz/qIbVkeAHmKpW04lRVDXBjniDtseWCVWfxMhhkyO1LGH47LCg',
'IG/PPk6OL7tF7IF3zeFxspWCrbYFThtcoWvEKtN7OfC6ZkH+cpCUZ0vizf3B7pDkJAZHzSnBuA8+CQYUgyE8pbPoCI0hR5bEkevOKUE0g6mlAN',
'LtYUhjri8g8k/Q6Rbuncwq+dAq18XN5TLgblmiO0ZmxjmRTNI4VXa4va8r1gPa2yL3LJFtWqbAq/AxwBeP0fKpKwO6lv3HM7SIPEV7OUWOJUfY',
'fAVP1dxBiYkhjoLXmRTZ38yrkp0Q/LmdzQZaWm4Snv2Fp7/cBDxZAzXKfFoMiiVOMmVgmqccievJdgYoIHQuA2WbHLStyBZFJle3TKwgnYNiiV',
'+XsXQNILi+SuAJ7KMFoEuc1M1HN1grN1yGeciJj3kbvjCgpqBhDcnZr75vDFx6F7jHX79H8ue7b8ViOo27gYTn8UVnbQBQ0RMlvPx5pROqhP9Y',
'/PDLeobvwlz7cMkt9AJSnErE95YQPsXy0ThqWeu+cNJ4xjE8MPK7+tkXOds3wWwi4gmGr98cdyly04H38c9gi1qVeywHKoew6tHPRRQ7/wzmNW',
'wOlPX9Tsn1AIGxUTPLaUQQPOh61HZIxKFe9hpJR6epduQm3OKyHfXI/fBSXF6upX0y397drezsL6y8td+8EsyR8ThzlHfYu7WnGJePRtD+oqbm',
'XTf7qz0ozX3C5C3K4ZlYacvPDGefe/vRbSmxf9nBt705QM8ZN+X270XD7obzfDibk4WOTr/YjcuZfThwCd5wh0YK8/ERKrkjKIG0o0rGW8q40d',
'eHjTOqiadE+eE6OutO+gMPKQwlBfaNuwbtDNVbGlQXrUI7IWCJeTE97MPnr0B2lcf2jp1gI1V6/RPs5EHJDrw3gMV71yOfQFkyh/JfH6zDwxTL',
'X1hudc68+hRI4YtuXX/y5z+5fsMBes+PLSgi2/m5ZuXmGukUkWETAiM4VUhN3i6ymFK6DDRL8r2Gtjj5zGmCGrOqsbBe2tEx2/EfSSHdZ+hE0p',
'dfVUBL8hvQrCKGgtSRTgkYBlerpwOAqYrfCirVHwlA9wVnlhyutlJEI2mWEF6JZJohD61rd01jentMFgBwb5cCQVqB89lpW9jW69MZNR6XdZZw',
'IPTi9wLZ7yA+EYlIwdW4KxSqaKiXUVsj4KLTB16CsyhWoWOs/ex//t+ICihdNHEUOKXDmb4rRJU9R0cf6fRzidiDKWf3UnS97/zsPeqXbH2D6n',
'8wfAD7nMfOqX7tsXZw5mBdPfqviJCCPZHcaH+YliWu7FwUJFNDi8SN04P3P6KvNKithFV3GEd8sVhx/1UAe1Gq/EqusXT2KeQymO2mwdUrYfxj',
'7XKI0BtpRBgngsemjrf45RuFDSKk7hzjQTtTBx31gGnbdj0bSL1dpyehp7odwPC2pvBJ+AyEeYcWud3mlBk+rV3/vraEPj/GKqYhsxDkdOV4Cw',
'0lP3GwZzOn1Zxva+sK85LSaFVs7ap7G1Ms+6NIjcMr/qFMVqeEqouWTWfpq/CyDB97sLDdAziYekivlrGavee4GzXTj1hLPj/9aJboMfGd5tNb',
'79xAjtAlgTeDkZwwzkY4SVk2H7n8v6iyAkYR9LKQGNz9mBLKAzB6FTVtdJOzx0VovIqtk/nUQvPPs3gajHlLHaJZtyXiVRxRtgGGSLv2kRXp73',
'0td/392b9KE6dBaysGESrxdvK90MDB6ppZt6uc2rRr6+fdV8LgSxEeRtGDpnZLx51iEZGgMHX/KEChP+taQ0BWiNmViIaLnkc/D6rKIAqitvdn',
'62nMoeWZDqXMXRijJNjhWK7fo0fZdBxI9qghipp/BqphcRG6SPJMJJ+BSD7XIXhKX39bSujVowgM7DQ2Rn8cv90RGf1OitRtpTzuFC8CvRLkKr',
'ND/j9QrLYEiAJJjx5EOcJnscjLSO6uH8fy69Fsd6zvbw38JSoJuKe5/dwVjBpXL7/SC14Csuwpfrroi/5Zw0Gcp3IRVuTLqxj+suA9oNJbD7BF',
'iB6SD+TyXP31uTh5xlb6kkHa0DnvRgB6DDvctCWnep27T2mi2yJJIvq1f/aIKONOEZ2D5dSY/9PLDbT8gqedLoMYT1Mmnjncnxq/6qBcXskc/O',
'Q+f1w8XvZnvTOqKfiS04iZqrqdp4Z7Ge1qfV+/e/CJtTAKwCFDEwyPm0tPpPS/Ui986zUr9yUjbcFtfxBpro5KdqA+IiXIIcj29iePrpHw7zAX',
'CG7yCK+3Sz48whTSQeqBkBs4RGc9hkR0Os7oxeAVAPZRky3flx31nG5D5O9F2120ktCt4vlrT5ZrhgV1CB3OyPHWmi9RmtE3poRjeSeXLhEymI',
'PIG/i0GtjzWyHucWWXaFTPgLhWWngfoTpnd6ULKGzxb3ybahe5p9K2zoIOYbwGipMTc8/wBkWdJ2kGBhTCafrjGey4fM/KBum0qaECYaz+H0H7',
'1ZyTbA4r0AqC6QkUDC2BW+Lv/rKqT+Jtds6eV14Vp4UNdmzDJ/uf67/zO9N8VeYl1gF7KV9BrPb0YWAmNPfqaII3tz20ehxVD3XC1d3bQlBQkd',
'to2rfs4JvtT518hb93qLXHIvqD1UDvkZ8L4DG0w/EDADvEEwacrxwHrTpsN6e5CH48hm9ZS2RGYm0RfZ1BF6IQcpmi0DBRONRoZptqB6jeydM7',
'mhv3D91sDsKgKu3KFACXqVYjqoUi9FSU38Pc5uO31KTrQF5NOzCMsTh4TfYsY5Pu+eS692g1j3eImdhWLG0YHBlwPsdF6UKngvM+5cqqyLlXaF',
'msqN9Iq57q/Xs32EBPHwSTM8MNbgNAxRAfZpjQY7ztJZoDBprsdok76uJjKw7k78ecf3aR7Q6jJdHR9waNyWgMrgK6dfnLY+9RLXB/6Q2cW1ao',
'g8hkIZKvWIMP7LwYB5YPlPEz1/scmGGTQxMJYA+wYexRyC7GKnYpqieKIE8xqN+R0qs9jLwbd/3HUIetxCQjiAIaF+hBd3BIsaG77GQHvA7tog',
'zHJJRD2CVweQ1NW7M4DDAF8eAPGy433BxetkAGq1pPLxxH+JcCYjkW1w76UeQ2b4Npnwvrb0ymGKmk/s/eAhgu0FYvUd5vFs4k47Se3ZiSxXUu',
'XrYkqfn/9HW6RL+Y/9dLgPtwywVCi61cPviLtKtS+KTs/C4sQDKFlAhFH3N4ZL45ii4HVcnX6O4VA+/5nteSY11K5dp6Of0Be8QLC0ZNbXOR1C',
'OYOw7S44i9JvJf+bQBmjLcCoPoP7LX9k4wipottIkQ9qd00VN/X3cqT9c/vAOBzSPhHlBjsEYxE4ZR/37TZJXMv+6mmROl5St3CBAAmvBgC7sX',
'qv+xJnteAqdHJ/9eIv2uDofZRY59BhEelOZEza82NjXHPJAqq9qb+qDW4vXV+4DGe7jKzQ1Y+3bp/a3pqf0vUdJUm7h649lGC4UusqF+DxBZCy',
'8DyHVHQq7gI0UPPnH1s432jkSFiFR6O8PxUHCzqd/n83cvIae7WpofV5pNnTy6eNX3Yl17/XShiObWh31eFWsnYYwaj17wJ5bQyWGkunz6iRkl',
'5QF3RleVqBgVNomvtwdu2Fc9wdO6JckX6OzlAEj0qhs2KmZrD1QOFPMhZ3g05YEmQJnwBfoQq2uDmIrW1XhzNNcRTDMRwY/1rV9DAcfaTq1JNk',
'bdnyKObdV4MzGGP/702M55rC1UMG8n8zn8yHU/Hno8CjVi27M2F9EbgzMs2Ya/IZhYi4EFgkm/Ii79r0260PHQSviilDhQCWba7nelPZudT/nO',
'y5J/7MAYi48kTxexVcYJa8xhYaA2BJn5DC7F+SPflokg7KTq1RQputHzxBXlpW4qUIw81uyiH8wZBkW4C4wjthUbM6X61/D4Wi6s++SVzWUkWP',
'ru36aWMHojnDMcIg0Zo7VVCCSz7E+tQjF0cExXsHfT/TpAyPodwMXQQ5FAZlsMx4JR3PqGVyKC7BG33MF8LhP1y7z4xNs4a3nC79SY2w9yeYMm',
'ePSyGqrtXHHd2vYdWme39FGmqMsWqWysBft/ZlPwwCyyJVUco4MXr92aUb8eTt/yLwZmrlL3dVEe4ir6uaKVOHR/4uiie4jt9wnyPMtAgkTnL3',
'hOZggW3sLeYLkoIdEf0HPX0Jc1m/ywkivIrSl7nuLHCMsH+2LKXK1F13c5u5TUpv8InNjSUGxymZ2RsdCE0kaBQ7xd/btnh9bJK37rdH0HHVV1',
'Cn7VkQITUC9AeGh5bI3l+CQTKeXK5xhocbD0aHdoFlQQ/9k3BlQ40h4A4mPJN+cwTO7NSpvTpfoTCkL7NCXbBlG/5mZi5NdRSboIBrhKOgCULM',
'ooXy0fJGydk8n/fd3tin5V11BHPoa4IojDN+wPmsfFRmXicxOF+MOXfldgjGJTfN7yVBjOJA5/xumzqHFTuXWw7Fb2iC0CYuwfiKF8dDFz9ssx',
'tlQUFckNlA/pgp1BkDQ47L8nDKh8zDL9jp49NJWyqkhhV/0zaRwtl93aujnIL13okXNUm13g2kBLulvbbK0xazuwGccamrXA8NvZC7WBQ5wZDU',
'zoR4VuKYlTAHDJCIu+4WrVlQ7dcIrTl/XHTpRZj4oHRJ6+W45AZYyee1yEf2CihC6zrrADaR5djky/HoYv5u18uVvARS9uAPpcJH1Yn3Wkhu2B',
'X0V9Vj25jJTxzA1/Fpit+tQo+joU09+2/eioDbhEa6UsmMhAV6VfMx5fPRh7Y5J4ryEZWkfSrlkkwRoUHoppK8ZyQyv3r5SpzM8eGhsKNxqfx9',
'Oatqt69Ij19QZisGhrQZX+OzqsuuELzIbsnOjkDAAWPNK2+3W78KM2nfOcQ8ehH45KhlxA4rnT74jT8G/jtttScpBHv3tuChhUU6GlCRi1p0/+',
'Nju7S9TuErqE/P88ZpHChrO4AC/8Ig8GNonhA45n3xGI/dFP7XdaXCF5xVAmiZ7d1EsHR8/A15u6+BbTJYMx5zAhQPXNzInDTRuP56TRDk95F2',
'ssjQRGatLUn6GEMCeGXcjlirqVuIt4EYfSo46ekXJvt01BBY1yvxt10mmPpi3J1SYrV6tweBXRqBTdQhPghybRG9moNwouW14vIvj0GTgPyzLy',
'dv6j3ImW7m9bxeMa9t8wpvYlO9fdakETHR5YozKmakbHKLsfw88Sl90gpKMtnm3N7WB3bhAlFJuS+R/VxIbxr7a2/PnbelHcG0oEnY4/AcPt4v',
'dowUS+V0y7Gskqk1R1mLmzNCAl8Pq5/AAYrJoWJyMJ2qpmfWgRTGmjZqUBzcjGH07TjtlS2KKXwr4LUeLNQtiTXGpmYtrCYVDp6iXGlHsE9zhm',
'ejF/iz2S/WxC/8SNr0HMSZW0I2RFA6TCSJYBVsNQUyeApaw9VNt1yiyqPdFvvrz4ZILZRoI1iLVkTGUOVCz9GIlZ5elsmq1D3nOi4Hq7+gjyKK',
'7VJwpOdRpvw7EDyIZ86coR4KFgeJGbQotbLQ5tMUqRnEgY3YT6LNlRyakhJG9LZy5uAoXj03J/P0PKtIluvm9DCYBhG7a9DxTSraXZmYIUKsbv',
'dOxZgOxTYgXYYm5Tc+Vg7l3jQceDR2fLzWFufw6E9Dl/DEqGwfPtba8NbbXoeKovPNNz21Nfxke2rlBnd5t1zbc90CoeyMdB+5PWHcinBJX/YS',
'2P+JgNSTn/Um2ZXw4fIsUVqvIpqKusteZh+FVz7JnfYFWK2zVTfvBaC9Ki2j+AnwXgOLWoGwi9tbA4mWlb72q5f6oExTtZZhMFjAZSoHqcTxZ+',
'+xCpRwfJ4dn/sDF/sHJPPipu6CobQoVh7CJaeyY3eCR8ZwLu1KUnyqk4P7+pwLoqF5k03fUpyc02UAo+RKORXzu2amtJ+itFc0Xm3FBo8e/nL2',
'7OyfAvZ/9ad4xIMDwz2N0+jgAqQpBxwfF4y4ZYwGFt/ebZE9BPYxgIKZDSEqZevL8T5lQNS7BaIQKc8lI69ku5R1uAKW0jQnZkhxVHjm5bnNRz',
'/C+ypaktpDvMlJ11g5UoC6g60Ll8eCR78OD0MFKB0hT3KP50j+Nu+i8+GPB6GbIIqW03HiOdepH8DcYSeCw80a/ya0Jp4OvkMIcsPgNrZX2wN5',
'0Ut8vcVAynPA7rzZH8tCJ85a94D3O2h3NqxBAo5Y3mtI/NzvH3FDtnKrlqMKeQqw+KdQchvAXFJJUkdF+9hAgKpaY9jl51Ocd3CKWcOLImclOi',
'M59WL5qPgTAL+4h6oZIh044jntKNA/ZnvWacDphrIuRVoHoHwvKXavyoUsBZVgdpHXApiRzu+yIjDqJS5P5SsTz3jQixiWDCBc2D671hKw31xb',
'wJJuVlWAUZO4u8qrTErAZNWHA6ZTnQ9saWVKEmeWe1Ozdsh0KyO12BWvelGT8KseHtjfLoJrkXHMeAjh4x3SGK3pYi/CXi1OQGOLu3Zh751TM8',
'yiDxlyeUttFpFq1Y3CaWIt4xLJJ8zSgNQPF2oQ4byMzPed5NlFXpLhy6BbmvX0LUkT7zLXdyorNeu+RoEmtSf0R4cGklB/m2n49N+At1ISRC7l',
'2HVu7/dEtT12sXpqG1NJBIeJiLEOTNcNoWLKzU6b7j6BG5Rn+8tuQxPq2H7UiuKedVRZW54Q8mvzcF5YuE8ZJV0rmzgAapnQ2pNZTUEK4gi9em',
'aCOV3JDuiowH41af5m+o+8liWHFecOkgYVP21WClIHQzR9G7g1MgMFhSfOUyBMhuWVFfqY8QIMKFmb5Q2SQ8F9PDMKeIlzwRWxwkTHQKF6AKRf',
'YQYB20Q8bmTbeCfhmuAUQ/VuXS25FfRJtTZFa00kHSk7Ts+CbksVasmafPyfmPWVd4yOMPYbb3rVIAWsC+oK9jrHk6TwyPt5hwVgd7nMZiEXWO',
'KM0AjropPm0Z0hsRGsYt7Mdw14UoSosCqAqKcZzLPM3pts1srdrydGyFc3aRn7QOr1m4e28NfYJ45BhoxyuTS1xzEEb4IQjPcff3yj0cFyple7',
'jD6aSYA44uQWj9sZ7BA38Qt4F8iTe5YClaVTSR+xAD7MZAXa8hGGelvm1agJ/6MX1KRARmYj0RFlxOGy9Al2WrUdRly0a+BL4klICqdBHCd6sT',
'Cntw37LcFlebOIthv+Af81JAH70zB9PViwaxWgLj1firMc+fEHwnSobP1HyqtDkjcU9freOyYAO6ZODBsEhQJfdM63NXV1zLgyqxwsuX0Nqvud',
'N8qlFbVcRCJQpidDCHKD/u5wTU5inbxZjUN/0jx4q3w4saPJgsN60HtdswUkoxnWOqSN/kfeYlY9QMHZedA/1NLuLUOFEr7pjsXKsM4J43SELq',
'vU8TraeNBsHH72jQVT1NA4tdn1QWndwpQS1LxunR8ZUd3vARbYv9CByt5vOix0yIMZH0H6haHRhZxViCGINQivtM9sML1PCkYGsdA3WmnlE5SH',
'WB56ZPfwZ9CLxlWGqLpsxre+ktZBv5QcFKP/v8o1MMzcQbB5IcI/pJu/w3FP0CGWsjJuELYOxS0N1GMSJLCrFHOPUT4eFNK9duQA9hoxOXPw7W',
'7mIuMmYqKCMhZFEVIH14yu1A48RMUAqXo5Lczl5X/aL0mnR7GxfiuWR8hbjwANOtelXavwB/oGCOhvlX/W2laWh9x2XTTLAD56I1nxwcdERxsN',
'rGTMFyt2lxSpyAAdzaf4SlYMYO9RA403z/c56g0ZUpGMTlkcPeqkD0QHKUWCEwzYrcVkDIUQZIiuOt3WJoNH0pkFQkouFOO6LAYSn7pxpuTJPe',
'5034yj8rNvbrRmZF/XPs4Y2e67UQ+RH4UuMCZmIGQlq1HXhilzdIvQJOI73bPu7WICcK4ghpbtnUivXmLX+qbuwoi7k1eGyXXhYeLvvE8pefu/',
'eVznm85cckJmuiLK2nOpWpCCEc8H1nm6b5TquwA0jIhZuAevFoUn+YkwHOb0mCrjbvcP1/v1eZ3Wn3Gbn3E9QPCxNQafUBHkkXSgleaNBYRwDR',
'wta5pZlBBe847QTOSATj0qEGRvMFZ5kLPaHz6+0oH/KUOYSNP0hitdtZscCc5Gpy17b6l54MbnOLwdRz8C1gzNch/lO40RvpRlyKKN3foqREyP',
'ujok6n0d6X5uNkrn6uZfrs8fmjKJCWI+eB0vmWHOeoxEJeBA7mYlCpw35nyEl1FqjR4RTL2wQUEL6uunlryUwOR/stCMqrb3F75nYh8cYEVMfG',
'uKxKhck0UzsERBzHenoACz4c340ztDGdTgvv/bhyxBPwqP0Wf6pO06Z9/1mEj+8yCXHjB2Iy9n2Kan+3XfDA/OUJzbl35VvJdCax+l7dmYmmqp',
'1C+Pu5snc2O/7ja6ofEGWLSalXpho8vR7RIBG7SHp0zOeppJGhIrs1XlrnfDISTfn6YP/PYYAYh3iQDKvZfGHEXkvSquLZ6mld1KIzgJojvpZs',
'gDSYdA995ojyjIltmv2ALreqAEgb2flbabLPf5/oDpPSAzbsMiGq+9Jl+UhwUcUDZdpkehQcof+0TGn+2kiuphdu1vyo9BwqfAcoqyjFAs1NDw',
'eUkjJYv6k3dQZi5VxZv3wiDvuYaf/4iTorNVZLDX7huNTWoIsTzwLL7UZVJ3sy/ohRz+k42yEjecwr//sQOa8UIjdCzJMwWh03f45mY29ze/2A',
'e5mf90G24IKwRoKo0YvgpA1L+d0H/jGJuvN9vqlT5U9qAj56OHzQ2dQ5ABpaTSRdjZ5sE9YFVicpM55KCdIACGmCYcAiPQ1DyNdcVOTjx6QCUn',
'ytE8KSerAqoiarUGfwN8520kmxCvII4diKirmHliI7SUw9icq0gG4XgfS8GAeuJGZy/nakvedRH3xWZf86nyWCcHzz7qXxIPW2lqkeQ2RTqOdP',
'UU9KuuB5MyDZB1J3C1SzXQNY302bceg7d1wTvT/pSmuynkcNTb+qhuVzXx2wbEq69lqhqtfo1zoUiIE4nnb0xQqe/wBwPMmc2RK2EJZQZ167BO',
'totR3o9YuAI5yrjMwSk+Wp2HlYjuZTKOf/e8NmxhCYiMp7Wy+7jLpynNTjRxPmuRWeQRRivUgdmdyMLuBxwcb041bF8/1vaQ+t3IzeTzajYUge',
'ynVvOJ5K/4vE6CY+VZoPAnWHBo6PyWwUGZz4rwMC8GoUOYGH9FTtleQJ9ld76FRPScxjnf9ThB0gNySXKOLTvvfuMflJNIy+aQDeBpeQHqh3Zk',
'f9ER1+LbvTbKY/6EM/NswsIxqzXZ9Pf3ISvwc6Tw5mq9+ZHd4ynERDnONwqzGo80Mg+1N3BRdUZJfUEVyRUrngGKupWLcripIBcQzBProTBRbJ',
'efbZjzATwhT3MWL268o++BSmMin1/287D2jbB83MM3eTK3/6/P4hKRv7XGO9mNfFgwuyujkG1yTh2ecMWBxepI4pD+bTL2Z7B2xne5Nb62ZsFi',
'pbyJQcC1X1u5JELheZndinVXBtY1VTIbvpHGb8YHw1mdUcw7TsCLhunwNn4RxScg408Ngrf9KtxsqgzBBN3LEJ4WhOC/LiBz9cCIPVJru6fh5X',
'8piQqo+YxEpFLJsgJFgYeC8at2L8Zu6phdVeap/4+bxN/IJ6WJ/kEe1Sqwo/eNWjHFVCvIldBfMaLApo6Up8ViUfXb6P3z/scAc8OV8JZU7/Nj',
'O3UO2Jk6Pj6YbfOwySCtvsUtDlqk0uFdfgkNnN3LrfvbQILBo9BOvk/gd6RTEr3to5BjkU93n1dL2RLKrSmpx/qHksOe0Cb6/eKtrk4YjkuJ6A',
'pjkNt1k0ykIToe+jdDkAcG5PejBYjYJv9dQugl410flJXGkRfuVqI6hG84JjOSzCFNrEMUSFohSWxNgt/n4A8xL9zGtJAMfHemT5SPAheJru7B',
'7apcJ1gNE/9/viA25gev9juIDyITCHoLS1XaKS2a6CwLOKlHNFxCfz0je3Ka96XNPDEFvNv4c+MKhXDP8zDmUfSTBi1CdlQGhrQYQ/FnNdVvM1',
'HTfWjoc0qK4Ac+XSG6wagb5lr5AaeySunygYtyBE3GADeBZ/Xy3q4H2WtVfvnAv4GdNNaOfQNzoTTJgdXyWjx2+iHHoVNvbHDdO/39Iq5HTJYz',
'gUy2YBArVMC3N4fMf6abwyBqil3UPr5VKFqx4dKNvJptn/4LXgtytFcFbJazw7QPqd/gljY4cQofkAlNhpG2vNGkL54aQhskY7z3MjutRtEyoC',
'IRyNTWcB1RFsUwLPHYCHYfuucK4asOBDeTbQGP3ji5WJBiLsxIbRYHMQiUdeMGZpanKlnN2uhkxgoipAnfY2zelzCxiUK7lawUgGKMmATGmN+h',
'tGYzYuSpmNHuTquk9L93CYO5TfwhLQyFQPQAPYitXS1eeLoa9NTvev/eMX/sEg1Jdc7BsPxdZ8oL1Q4FyH6AFvph7fDG8nZaWpxtbxwiaDiVjz',
'8JGqJeihAU+1rljBkooSuePEzeKR9plMcBhcIt4VXeYXNQ/pAzk/jckCy896JMTRD4oF+FbyJjxvvvh01fIyLQCDNGCkQ6JNkCpFVBT9iCVR7Z',
'dL6ROnM5DyWaauZ4WTs6yKhxXmiku9cJvmR3tYszYCHWHEG8Ys3wZO65IiCBKbkWh7UK32/iyovHODgCihj8DIiT8li9sF3pkSRJyw6R8YE65v',
'2paNIB9JzGVhLf2v5WCxJez0SUUqlVBF6wD7678WPdnpyrvxYRKmkErgFIQzkzLkqyOhNa8h97pAMw71KsqMfXavHWIR3fW7nWaLbmse4ZHFQZ',
'yqKDduAJ/sxtgQWOMR+ECBtpr5jvcL23qlvPKHWiUZ5TNjWfGhj2SSLvyBidcbTVy5A2iTJJoDHPH0t/JV1SPqjwvqxoHCaEpi/9nwlg3xR3cB',
'BEE7rXAQ83zNHX96OrGlR18gXQKTCyeceYI/RVrIJe2yssAwBm+HE61w1haRV9VZCzJuIqHY0c0gG4brY57oHO65TGc+KIf1ce42k1l14YXxT9',
'etEviSU9i4RDIob5SHRWTwIgc1bDtSFxVtm1lJIuLSCVD4FPlqK5Cf6J5bq/HJtVpl84vLKR/SA+j8sKt73fD5XAQ1P02wEGU05Pb/GWDOB7GW',
'BjWBAmTvag05eRSNZ1T8z7ihtbE0McAZs+U9D1K0nQB1Va/DnM5xuA7AfQZy/8P/qBLf5qmoPYxqnuxuTyJgSdZ9NUQdWEzU4BGOnQclnJsy6x',
'V5jcwFMhP6jfyxGujaPzqBTkDVx6/etuSdHX+bU2YB5sGH9K3cl/3V40T8N2cB7JWJSDBQ5vvh1j3ebp08VBL2XerpUo5zjEZOyHuMbceXWIzS',
'0ZrOFvYwrQZhnpjefw5nMQKV1mgRfrNkTzUi8QTk+F5D3SPJyOryubKzWWyz4nRAqSwxz1o+xRD7gSwzX3oLVkOuHP84teZlQtRA9a+FUrqvV4',
'gW5lT4JkBJjcC+7JlBQ8v01mSiO8EDjKLgN/2YFCJo9NrGL9mqoVKQoa6NMqJ+KUVGIXzjAEDFeoHoCaBMSgNjEQ/ALLlLhyQxPXyhvAa8EKdZ',
'24e4ZxKJZP5GXnRMcnvvWW3o7qVKTgUZIUsr3yyZEq+EqJMpQEHO//nlpATdhSR+51cxgAwprca+hc9FMoy8VqU4F0rZkXCa9ea/wbnN++XOTC',
'H/qRLx99cxtMdH5kRyF3oVuHBUXpt9egFGCtYdIBzqUcjXAaaMl2Te5RHkL8f8eq6Zff8zXNjPyDtXbVG3PJ+x99fbTxWfMMT9g0VDKU/df49X',
'i2FUSJQ9o8ab4Vg++ugVZYM8WjmnkQeRh9ujg/VYWxb1gspSb8RyAGZlyLbBr3ZyMQPuWUZ37DI8wV5VV/uzfpe02uikrQHXGv39pLlwhjSCL0',
'MMHaRoqVZ9lIUGsNwD4Mo2Np6turJmd/k9jETPuuf6SZK09mkZKF3w6y5BTd9DxfEJk5qY+JQwWBCXKGGZwsrzj4KQvOoajCFdaRj0YjQb9K2j',
'CIWoNI5D1XgLB+smKFJWI77EPIJZpduO1S8nOicLjdZ/GQepIyroyoRl8x7icCZ/EC43j+ZMB+p2+sqZoVeUDaDMZ1RQC0Ok77wokaxwxcHh0p',
'TWCI+h9alED7f+2qYj/RxoFScnNnuky+3s95+2shBUieAHI8h/B0z6HWFWN/1rY/LF23hQmEhea4+Zed/Xfnl2K2gFCA0uOqjIUj86cRMC5Zf8',
'kMLKZTydvEqdDa+SlF085KMC6hx8fceXJDhw/oD1Mp/F/DuUy/dnQ+N3OjXMt9RHVYY8epHGUcTL+blOQDdM7NuLR39maYZFL2B43ou2kp4AEN',
'gFzpQ6UR4HUDV+mnBxq3U/qj1r4zqb8KC6odr/PwoN0boR8uJr1CtbOGCYeIYHbDWKQcAEd5vOSqsN/BCvRvGMeK/jmrOLkMqNUHJHxJ2lH0Q+',
'IkL+Ebswcpqm6smoF/35DDT2UrsCQT0CdvQoGNlci86o1OluCCkNG0glebZGew4+zS3+Pt0Bgw/MgmZmUd7pzHSaS+3mfLVp2hjldvMIn6IgBl',
'MVjklB2FS3h6s2HRa6T6dGCSYHAxa12bz8GUFbT6QNffoc9aiagEEhDy0NGV5yv07Ja7cwwiPaa6t8Lx4DtmUDi2lXf2CxP6tsPwibnAdaG7Is',
'5agBkFu/xoSCwxFedzQyf5t9FyZT94JNPM8oH+lOeUESQ4z/9POJT8shtmvSsKPSnosRuhZLEHRP063QvmnhjU69bGwD/dZsNrgxvjhfbg51Lr',
'4XnlT/6OBAAoAE1NN9PteMBx6+KEQBYKGqIebhCQrC9uApb/is/+HV2RjcQ0HpFGyVVcgRqw048/d6PftdfMrcR/EphjSGujHGjulOphYBnFvO',
'p4+JA1sBYYOlals4SRuuj11xWi6sQUUFSKqD0/SLVTbbu6V/4n79K/ElSPs/1Urx3rYODf5LbjheLphCdR3L3Y3CeBgD56A4HGVAoUglpHPWQ8',
'HgVsQ7sa32Bjl+dxoqYRo2tZEd7q29EFnG6lVQ/vW/41gXz0P9PhPkp/oN/T+CjH9+ImssRIh93014gzS/z0OrrgAA8SdPcZvwFeCJUHEQMqhW',
'BoLk7R5sI7bJi5gv48Ta205MdgHGpWIfSbDJf32oWlL5OQDaSqDNFNRmKZuwReBMwtVUQnQtWzZxwhNSBivpBbHWK8hDCpveCjvOWhLLJ9/7Nc',
'sThaQmgfCC7uKgtultXeNqxhNXin3Tx9bJPPjhE4MyMO14P7MwZ3vuVWajwKiqKP1Vdb0AqqAdnrd+jEfJFsjsqKh1gcFnOXbXeFUeGgqayPEQ',
'B6hjY4BADKJPZSyzDYObtYRO4OtuuRNIOTqI/NW9wUDoUmVyT1whCN2jpE6tEjlf/o2bXODmTTNL0+HBd0x4C859kdDO1KqxVkLnPnDb5MxO7t',
'bXgD4eqE730HotDgBnzkdupSMhd/QAXXqeHdfPOJJv3yPrzL2LEEkv1s/ZcIquz0fNyyd8sBWPr1/W1YZma09OHAv/dPy7dbFArvpcmfrv9G7o',
'JKdNy54pdKunJsY4CS+jYMkJrc1woWAb/oyrKtNr0e08yhE3PNbjax3EkPSzAzPJDC5eV0ad41i3b8IwylLzZNyhTdbkpr0fJ2SWH2QVx3dnvl',
'pfK5KbZQZg3t58+Ft9o5PuGi+2TiVqsI4FXbv0xr4/Iq0gXOSA7UibSveX3+Hi4GwWqZwynCGT35kzyuOw8YcP66w63OAFCjZHfqfijz9ndF4L',
'fjWWSWZwxv/1TomiC3OWo659i7NpnKfleabmpnG1AcEcujRZjqGZ7HA8dZOQkVEJCsJiUxV4BHBzMLI5HWo5Bxv5Nk7htYY0WtpfOrV8Fkcs6s',
'IOZ9TJGU4Xs8jii17bPRdfhgwLGH2rU5SSEbibH10NsPXcsTH9uWq1wAeXMfm+QyNBHeJhTAit5W95SYtW6csLKY/yUqReqn9i0wvnkKvqt8s2',
'hF+l9ZBl1m7nS0OPR8WGc0tLgECqp3DGFYxXPZhkPtgeObaDk3B1DRtsVf8pquqNh43GoOiIT2sZGpDAn/fedsK+anCgw8CLVrJDQAb6FbjtjJ',
'R8f/0GUsU6d1YQyuWc77ZE6Fzya/m0j+86wBHrwas1y3J47FIvxkeOCkNA16miSOEHrcm7J41dyVGm8vQajreim5z9Q2lI1Ds7G7sQLhiZT91l',
'NKA+r8GKI9hNAgXoWG/Hq5odlDa1XB1+ng3KSlJLqVJrVBvSD5rY3SsqIJjXHTDWpKKop5gEQiMbHLGiDL57itKem61AG4AWaW+rvAKD/y3y4l',
'7WeZRd7wFooGweTdImOul+R982VD3YbR4WtRs7gEg38ORyPLHx2agr7wOQVe2eV8rK9bY9Lom4qQPIcA4AgvnZkNtLbNdlQcTTzkn+tG879tal',
'G0Oi5NJhZsl0xNFpxYoj+JV/0gI2+qbe6GRLkBRlJ9cDhFirhUAXOuG223CGfzoIy5ESu78xBu0eIgjiLtBUNGkOTKeqYjdHni929E2kJWPfLL',
'5OHvQEWE2JWzu67se1leTQmUZ/D0vCJ/k1sD4htbuTsTd2cWtwXa6dui3wv/7R4p0UwjOUsjVEWy0nNWG3x8Wq71l1LvXiClxgpeCBcd1qRHys',
'0CAHNgfGp7FO11i7/wLhHzShf5eHYkYJzFVSD10BvdKB/vSVq5/dyxsuu6t40mcyNzcLBr9yEgDTKQvmEupogvKI6AUcdz0hDmMhA0xatgqWbe',
'2wK7G5zdYIc48GkyK/v4jmSDM6/4ipijqG3546aJqdmXIT+cBd0TIT/EZammIdn7clVNtFhneDJ9+z7c63AZtJPz2WkfiTN0hZXfoN+STfDqq9',
'sqymyhxtGQsUQIzs3iprVEoWwhigIOxl+K7yixxsoP6EhG6kGAefFhQbtan055VVEBCGEj/xbKs/cHHLmSFr64HSjBvBlC+gnEDqMa7BCHZNFQ',
'+vQl9pCtH2Ox+xl2F43vQ/bvoMNyudCgim1sy1SIq0xzd8/LAtWwV5hsfCO5ZW86peV+TZxj+aSXX/PDZU2ogak9gMCPvRWAGGYAq6eISjdZlW',
'sL83ejZz7l56JJ+3Mo2VWjPkbd6nQNNqLLRljVqqEX/hPRl6sq4inPQgIiQ1NfFMsPH+6D/+3e7xvdahWOreGr9bFG7NFl0FnHXoXxmKp9dd/6',
'h7SR0vNmZPxsVFEgYWZi/qjHqKrxZTu7QCZxnCKHUqFAN38Wekw0JP7bJxcdQ0o8zq/czuace15exGScVlR/zpNg++/cVe7nPT7YKTRyMB9fDH',
'4lJR+Hs3DZo9wDdJds09qjvoJFXjzz4AtZSpfIA/laeoEQUkI0ieCjMJaBj4Yz+Q67fUknbdtYLyDqQ5klb6NrP8hJBaAUmgdKkynmGxxTBrCu',
'+wpO2qBX9CMOQmgIwToLbs5UVe6idEcywYEL9JVBn6F86cgoOGqCAdchnM2MeQtaJako/hCws5v6SOsRMb2nJs6UuwDErhub8prEtWtNGzJiVt',
't5Qy8oy4AtMwsM7LQDvUPKI4mYaoeWFz6bYZ3imAwvQzaajDkIiCaT+ATjIopKcNZGLuMfp24gq/ZdvlE3idRO/4WaVaLyhjGA2LWJWugXPbs2',
'yCul+DNrWpa68GbAeWEG2h8WateS/MlNzNF80Q05389QaQhpmPqAnwNBFNi8gwYco7v6KhckUapGPScE9rCuApUNbWj5rJ3c8lSEmNwm8pxdkk',
'syAJxMXkz7U3z4/B5N8sRQvsy99j95jWoWYndqOzQC3dzlvXoCSaacdhMtRhNK+oMFvccGZPWTgCTt4Uz39xWlamKg6pBfIUSx9daknr0g3wk/',
'rydT90xItsgE6NkCjTAM1fmWlrTaACs0Mt1rdrDtIJZMdKhi1/EbbZtBhRlD+0dHg4UHEELyzfQa7Wew+yrjRnr5Dk/z+w8jkQcL+FJWgLpupk',
'u4gx6nwqYuixvl1l1gWDrYfaeW2WT0uAL3FbvX4oHqm12kjdXQDqG5dSlmy1+L3U8SN3+N7cirpMuLsjjZ2W+DN1W2rWrd2nb3c6KzUaD4Wq1w',
'RjQiTWldmLgTI0kmJyGPi87gRta69sFgdJFLyG+5qNR84vBy+FRu0hiMbU9mDAE4sgyj4DatjMIZ+f3O/xugu6HVcPrjbLeoc5d9l2pOWlkgT8',
'WCpJ75Quviox4x3IVPyue6sdd/p+HKcVh4BxkZjFwqfvpbm8P8Vzw42HT1YyGliBAYjdh1oUxp6xELLVZzHAkgCqqqM9oWyUVB2g3sZnf+U5rI',
'69WG9gNkhv/uFYTBMOeZ8MTkneNOCz5K1zM0IfME0JhfZrbQ5sQNnxPJcjUbfkLVZhZod47Qjld4NWJyp/N7X0Agn92x6vX+r/ZJjNvREPCa55',
'DAKWj35SIf7zHxGV9wRvHBwILuXI5M95bHVQtgQo9/IWzAzOBHkdMPyKUVgU11JaLZ1CeQEQKn32Ti2izzhr/97+zLmvIVWdipD73+OUnQst9W',
'S16QSYBJwJxXiWB89+Sj/b4t8XC3NI/Cd0EDt0MB73R7IKa1pCqmdf/jC46F/7VUBA0PkbV7eSj6TtaQh5x5Iy9aDDZnB+fzLTviOhyryoJJKs',
'Y8egJQXrcT++gP3iXtCff/rfE2DhnGsFzsr9SmoAW2V0GEwhDh0+TtbUQx8CCCmKkthaw28kr/ucDUdj6lb1XP7fLnUjPKhjlrxY98X+jqtrI6',
'+6i4uB5giIHUEUFKgnzboVb0X38/T6/i2S3OqwJQW8wIRugsir0P72fU5cLgAZlqRKOv1j+2x5youT5xWuAP0GWunneURcQwkPFogJrBx0Y6rc',
'iqH8ZAInHaP06Vu3rEhpU6pmZqx330k9w8X5x5SJl9r5dAKoXGBw1WqxQwp9MvQEg9gnPH9UKWEIEHx2mKH6p44LEaVt4ZKPvsfERdbVU7mIz0',
'Di/tJeVxgrncRG3JPd9BHMRSqGVNZTDqXN8cikJA0u4AY3lnQbw3jOpGdr0vxlHl+RxVnDTUHvt26/Jw0QmifHOk6xkR2Lr6NPvpHpeIC8HHCf',
'+uiUmP9NQWMjGBVzccCg5YabuIAMu/CaR3tnrx9u2fITweYmf/ZA0vAGsoNJ7AzRJR2dfu1I3EnxPJMXvPuSbqyIaNqT7uLHD1QUWmSJQO50qK',
'zRG6nBQ4OcVHouFU/DhK9y4tXH6fRKthKdeWzlspQolCQullYeyNoRbzqNi/fbvXIaAAntfQtb/i4Hd+hJfp/U5cZjVPdoUlJ90jfAniciz6Lf',
'Q3wzX+puzO7hAS5QJMlGukxp694IeXu0JW6ayhPLwD6MYfYI0h1YfBry7vKmyR0/0C2YtDAsGohJMN0wCIA8ySG6NGGX/axJorUKVDM9vWKQW1',
'kJlDb/4BkwcZZe3S40DSZ58b9vm3E/bi2uBW7/7g4XkZxpOecooAEuc3nkCXSgubZoD2MJz/LI3zaG3LLP9eWa1Em21qoaPBA9U21sADXtRiHP',
'15aSwuyANl4vqCiBOh/lLhvp2iS6eQqYc8xSr0qKJ8VA0zgPznlT3SIJQS0ZngRZU4P71yAnEYVcXz7FeOeRSfSRHszVHJ+KIrIf9FgtEi6xeF',
'PiaETtra+0ov+VRMU5gCHmkaJ6nGfSwOw3kxq7CfEwvgHAM9Co991E5aRO5XJeYJ3+tMy3dhP8zBI/aPpW7t/nKK7aARhAHWMehHd79/jS/TgP',
'JXztRgee7/svfdvhpw3eIZbQhMFahTOvz4SNIt68/soK0v12SlBhWuou3J2LsaZn8dhH9s2sZ1mSDsUSK8fn/rH1ZC1W9JcxkmHyDthpjJFBOJ',
'nZduAqRUOCpb0rsrIdExc350bVN7xMEJaObVOSvWoLIS6YffnUFroa1KFQT4r5zST6d+qcGsrUxMIRfichvcPDqMrhU5jINr9ylaLjiWJyva3U',
'4NxiEU0QyE3tFx8Ui5zw71b9UtOMgO4GwfZmi3jnK2iZt6Tsf5YhG/z0JcUBk0AwUl8GzMEL0USM0ZR+kXo0ZwQhdwIObHhMTK+fG0Vpjs+rRN',
'C2o+H87bsZ+DeET2JUBuWsEqE0+zlLNlMHdXprB7caJA/M3f8+EHmSzB3TEMKQq0q8lCTrG+ioOJveqgL7d3Zf0kWLxO8sK4fVuruBky/uGI0h',
'/MNL5zENhCfl5L9g0U5KDBN4Q8E4Y8snJB3L8cy5JAvnd/Yeq6bmxPtoXVeM1lMT4WhQ+KbGFliIrYjAP0Ux7Xwoa0y7dwB496L8PUsCTam/5m',
'fh4pP2lNK524zJigAqI4Cy5UiUSXKdixU3OMIVQDgGrFRKvtU5aoZ/cED6/fBoDABqN/VhGjIV11oxJzD8Q6q5cVK0b0xyz/6cX13MpO1Ffvvk',
'JP63W12a+ZlF5UtnizmHk2ZYg5Y6PWEmaDHqSwjDbX3OvDR1r4/bGB6M7+P5bBVUyQ++c9/OKV1wgNAdFmgpX5bKLsqsAZXhoWxm+fiOMuXPxV',
'8dwn1zsNpBe1uxLgytTGob1eTBUBsYMS+rVI2PLWFmdLJ13AQJmLNH3SUFT2uZYpheM+h3fMoTUhhpuVgF+GGQ5gb7Ksbnf+WuZSDttnG/h2Jy',
'oD0JQsO85/NPzwdPQrigSIanT8Ad2nr+6mW0utczF/65uSvMokFowQrG4Xn2u7OyEUMupoOTVfHj7Me4Hs8tGICpnmZb4XZAPDnABNtQdiQB7+',
'9nPurfnafz0m+GUBuDcITJApe5k8Wyz6A8l+ArCsKiqn6xk4yfqF1bKkJw0niiDNSjdWXkB5DG6UQh9cbHPxe+U54q+x/n6VzCd3ZSdAnTuNfy',
'3xyeX+uuxRkfmSv0zfGNorkIhbRSXiFTh4ABT2cRT0lCB6QH4plyeo87vh/s6io/gBzxX9YZWcDSQ+jgzhgmq+tYssHl9aT1hNeD7sIl9jZEY1',
'uMli0qJcxl/FDFDk/JnhLhgYCMIqTZZ2OTF6HpAFrSboGiFVCOxfP/tbmGcewhcgS+pjZNIELzDnkiP8mGInlZDgg6Ae63c+sA117zYqHUfc9I',
'j8yZdaCip9wB1HkNlz/Q32bvKG/EVDt2CXNWsGd2s7jWRwDdcBXZK0ChB0gGRduNOWk+r/fV3bnO52V5IFIPLx0fbI136Aa7BY8ikctilah9gV',
'VzCk+zsMgosPZ1rYP9DidZHA48HUUDccCaLu+7tTHmWXRTvqLr4UXvd6RwPCVv9yd0CdQSlI3vSUL2BXw/pHdwvewQ53io3yDhyVH1ycwIHALP',
'+4nuHQjHNP/IEgAZfq2Vc+kD7catDUpBLbmvAjUVdzTc31uuYwXgEtKKS29qPdGitX4Fc9ITaC4+CZ1BfeghK5ayEHfyiAMSoBnG8V2CwSd3Ho',
'WTxBQg+SgezPqL0jF8OJQWBLv8733022/Vch2bP5U9vrDcLMeDQHfc6Y6wW1wLGe8AcKHUgRf4Ntz9ZVcWkn7mMC7DAaQOF8fmUnojZRffdS47',
'yjHJiE+FuUvqojZpDA8dvQTVKLt17+Mur1W1sRnOkZgWfWWPWzgpYPCqbKQnlS1OaFyJyzWETFp7GR3pnIvXWLn2AEoSfdjVkJ8otNocKE9c5Z',
'gS629W5r84MISXZ050hNv2kC7z77tkCmqo5IkKdZBjAJk5RDMtxpHr8wD+chEaW7bKm5TBK4iuj+eZItDJEM2dlgjDzo8eYrhw4FntlZgw1i9a',
'xA2y6ts9DQ1/PvPbbIvCyScwSr+IYG1a1MQ5cCfjFevgxahXfBxcLYLamVCGIGiFUIIm0FgVnucm0UiHKHZf0xvrldTFLRWG8anCDX73mTvqsi',
'ol8f+mw9qYx/GCWCvFlz0sNGuO/SYSeoBEuUa/5mm/o+cqg2rX5m9Cai/hdPvr4aynAPgYqjcmoOqG0hVHAX7aZkJmxsr1ZZi9tYZCCI4AKcSx',
'QJJxta4UFqMSFsQjLrXlSMGEEMwWXKjWv+eHbNoMGUpUlOchux+NMy57+nqLOJLX0fF/j33WtPdzfQWFdCVAt/ygfj8SCZmHBl3EXpa18Yhj91',
'K2GAxn7qgij12WcY89zrdE95StCLXXVDBwtCYecWGbCPSNndifAO1eewoxYec0qFyIGlyST6KhUNQ7uLiceMTrBLr8HVSOLr/Es+e7cONnmv3o',
'9yBuoMpedU915+l51SwR1xU4f/GugUSCot3HfJMkWA8JytKSrgjASIPPACdURd123GcDZfdNRh/dwGrvjiZ5luhpEaWMz655UFMx6lclzxKH+z',
'EoeVwttHWpF0sZ/EFhaIqsBlgU6o4R3Sn6lWILVYNIbTQIQ1Mm6Jt0B+XcVGcAekqepNxPrDFi27HRl19cOEUsRZCgFSMhN7TkWJVunYGCGuU7',
'5+ZfZFiqmBqFV5uTPRQzAH2pnGCPGj4FGykAv6KWNsfnNT5T0rbwqrT5JJQfZpIG5pQROOBBT6fmv6bZh43Vwi1V1GKA+cJgHQcpZCHNuJeejZ',
'eO3Zkg3eUysOiO6JL5Kpi5wU8+eCckK5XQFrUOc4t0Y3ALbl91ycVKTvEwh6Nk/OG3YCYQuoU2E+sKiRNuwaneUZWRB0raIcapN+EImg7gpcyB',
'fWn/s6HKuIvHCflREpqCmcD41TVWxQYdtmGf4jr2myFQQZ6XV67rQeuxMOx6US5BrwMYUX91C1MkW9H0U7TPeA6GBA2rLaGv2AbZRwbun8A0Xe',
'9EdV6HbKFJFXW8fD3gk8IyjV2DhYHk6GkmBIX1TkKZZ1N6pQEv7T22I/KUXrNf8WWkwDdL9XXGkHXSafJ/N3pb3mlmk7yABcPqRviDAulW3sHL',
'8yUP6/13RtxWwzcIFypmhYwvJhTclyCU2Nxt9p2pewU5HKGiAHHQLXF9WgGX8cuc/iNQ7+EVqG0Jnop3Vblfy0ebfvNquJENSEbkiAiOF+DpkH',
'hkJ9sc7RYrkOui4N4dDzyZOPiZU0++GeoWH9LOoy7MIHsQn8yvcDJz9eybfa5BbCH6BHYehIfFtKezEXmdxGr7HwQPVH4DVD2vLDgTreO+DV7r',
'fnU3E80l2O76/FfqMVsvojJnJE7bbsTcb44mDetCkP7JSAPi3nVrWgvdc69ajpoETzT7gHGLIVAxUFmMmIcEFnYFkgcyMUboPSrQKII7dA3yfI',
'IIRV8uLQc5CuK/PeHLKbnGMuBqo46u5D03SMYjarmWGg9AyomJeXNgDZfaILE3fnsQech/M+ew0i4qVcN3XR+BdofINFfOMhMLEXwPoqrimT7b',
'U96pCSp9Ide1+d5zD06DmHxzQ2VLTHXsZedAfnErATawLPnJGGX2wIS4bE+A1qnJB7tld04dgrz2CMXLFuszf7077Q5jV516AUPhd0UAWEUiBp',
'j5EvlHCB0b/mRdZysEVfHFu8087JFom04aZZb6ZObgG8lshtREGJyRPQLso5/iP/HRHnV8m0dsu/mDLAwLvThcpo3bborQcALy9b4YauNzwMNO',
'bpie3fGKRnRuNTdO8JYcn9NXPuVJmr/VmnnZCK7P18XEtClj1aGgVIwT9gKgZHs4f/hgqjbJNEh1nn5EhvpgdILn2AkSGHw4uGJaRBVe9/Xq2y',
'Chwf30R8Jq3TJurYDI8Fc3qLbVmorVzLFVvvlYJ8NXCdbZ9Iw+G5j9AaJ1W+nUNc0GFCzieUbwHEJo3r2QO15hsq1E46soKL4skWt9nFQHPOrX',
'Ou9Gcf2Glb+x78Ea4cqg3zUKn9XgxLRaMCjM9/VhEABRg2BDWzuNBhexXaRmMDDx+5NMactPGtye1qIS57W4Ka0CW7wM/gQh3gDAIOku1T5HaO',
'SVfYcSfL1f//uWlwKPf6lTRC+OH22lNMBhbhWmr+A3N/yJkziOpPVhowapuvs1MqD36Yq961QRDSFwgs3ajh06mLjkUF/OtcleGyAvVsNsxmil',
'hUAGA5h8Y2vkBFl7kcPWw4VHfBbKrrejTby2BZfpiQqwxDn7FOn45S5dZV2eU1A6gUwFVcyxANVLO/yMW3ZPTFv6BoylUgvoLBETKoTJHiwo/l',
'hFjqVUj9LxlD266RAChRdPGPggslONh47Om3Bz6px1CdWdc4iCAuq5+TTakVlURa69NpOCfU0SNP5TLyIy4M9BPFxsL5bNhBM97igLkyu8kkdd',
'WMkatFWnpIQWzQjY3rSl0Wq1dpRdmVdM5iYf/F9kFGN4n+a7NubcJsi+XDQ5Pb+y0+wyUZCTNQgCK+iDybsJ9BYGXLuLkmhG9bRz2kjccK+LJw',
'FgLFcHenWJoHc9s0E/GEUGrTsveN3dMw+70R4uwXV/KDdw9bfCzxG+l6SoXM48MQ72uWhvVFEOzybxPM+NqWpcgHxTb+2uz726k4FIrHL4zUd9',
'4kz9auS0pU8U3EeCFt5p7iFl3jrqnvzbWuW2SQ4uA6lmJnZH//Jz02W8aOx6DTS7QSlQDD94KPOoJY9m1sMiWH/tDfFBM/QHAIUEjMabmkNo8M',
'qw9nstcbSX4F0jGH7cyulvL5sGepZbuYx+AkRgswcpbWgNRaawxdicwk4/sLHz2etkKHzHCPQ6oC+RBJ21zDHDgadYX95jJ+6gKviRsN2d29IV',
'/kvoNdlpbuYWsqlpH7nHVMi3/12JD3njWDOzeMfG4Jub982MSdu9tjGQEkkkFiLG7AWWkO7ftswLBIZ/2e+iLOCxP1FYNnD6SGPwE/hFRF1suH',
'EuYNxlF7Ldqmi9gvplnCjmq11//xZFZUVnVXFhSgX800Us72L7jvfM/uzI3Vmnag40Wik5SbIm3UqPkxK8mknAVQAjLG/QGB7PUHc7bWvgGkFx',
'6hSzFBrc0cw/n7ZgdrXkW0neeQY5l7dwRYoLhLrDUXTxJaf7/ZRrcMK/0nGN/d605BoCBwoZ4hoUfRE9oKc0opUT82dHl7qOET07170BKDaQwt',
'pcVr+5PPDH4w3aqVQzzRq10qK9Lj3jmrC9XUs2LpvbG2P3DGmAy1Le66Afx7y1m4o+ZsmOl0jAP2onWVQwvcv39S4/ItLy0K1V97vR6fhBWQDn',
'0/7cPbYbsnpy1z6HnO5wxTS1K3+vRKDLotG4UoTSx3kctsW+AuyIDhsDUmQAvQD1XmLS2Xf1ksyQkIRnO2+icDk704KEeWkBbs17qN5wFI0ph5',
'xtINpw0FXTqE0sCmZYdQSJG61Ta7z9nGmtt9z9e9RxnNb3HerhWW7G0G5P64mDN8t+Px1NS+3pveXytynK7G9ZqVFf1L0WisLO2pBGmdv+GvME',
'rgtqO1S9a4b+blJmS3dYYWjpDVHA1XVJBRN0+Fdm4ElwBzY8Rx8Q5R4tJGtDdLYSnTmABLXEV7hVWCMQ1nMBfVPokED0jnm5IZtR/Y9gn6MuLg',
'+trSD0iSs9RYxA4uuTO2bcIlCAQvjbm+r1jMlEo1HoT1heDlmguk/LDBEeO6PZ9kXzTbTZgpWrOIuEF7oLIrURW6wFGW69gy+xBaH5R8bxKc5X',
'KdAubHOZNwTPngppI17pvz40gM8tW3P233lJsFKgtCrJy5NJxc1UBqy8IMnAn1Gmkh04I2Pxv/aOuNMmYWW71j+GyTU4PzsdVQQf9/G005Fivv',
'7jogbbBTkEXMvDdMSzdUSlIK2qGSFLmNvCJcey03aNya4HbDEIi2W0+GorxpFdEO0tzldEc48ez8iOtLKkfBaanabaGjOvkY5fA+K9yFI495Ie',
'lp844gKbqvDusxO8w2JG1v6FPiBVAxZkmg3EomoeCBkvZYgEaPt4iMze9bsTo36hIJ+hmnWE5Rk9aZmSaIlKkU86zjzgfhEePNTLB7iYwCqFhj',
'zrTfmKrLpEeSp9eD3BL2FUJ8uOsTTVivURGLCGjS8LZRbYmxMMBBd3UHiV3jg/bafcRuI5Q88VuU3XuNjHNxYK9rhVcVvz6Cq03XBr5buEPW+a',
'WoP7kwZS5Pn1JWMDY0++xYAgG3ZnHCREgdjWY3r/YU9/ipasKn5XVTV9xfmMMjXwuddEyFO0SoG8OPfjnn+1MxaVVjTaSIcJg6Tth+cvqXhpWv',
'TmxDbrFRsNsksV3mf/htJeIE6Y1K8+RgtO7DI4dDLlwGf5+zugL20Dq05cw044ia1dQwSsdNmuyXBXr5Mwv05E0s0NPjZfeyO3zg7wvAzafKwe',
'/wpmdrOwlCeyqd8JfymdB0Sq3/wv0B7eS5wiGTaNRF2q5kiGJEEuuT61xYVbdqXHuVfs0YLeZygxIqNx9pCuCaNoGKbfvBWWCqPI6tTv83Y+/w',
'X8/cY2GpChR46MVTXK47cbup/DIqyA7PrQDg0SXHd1qhzn2perz/qe4KBXw5viAsZgLU6432+V6dwjDv+LNkRHHpnn6KUdIW/RMn3pUBmzZD0+',
'NJuKg4TsiF30G5slJSHvSsji+0pbcm+DI+kMidHWGRhQQtyOLH+80O1soN//HNZtROdZMdxTYUh32CyrtoGyYbWzBu7z9FMv4H8PaAjpBmHTHQ',
'804TL0xmgrcSPpcJT+r1nKyhI67ZITzUwM5sxzKF3vnM26ionajbF6hxDn9o+6mvFDwfn5M+KEwfO7g3Xal3mDOsDHiuupGnZph55aFO2V7Sj1',
'1aR1yFNwSWBhyIBDLZIjYyxyQ+48OU63EPJP/RlgrMwj4rCvM7KKmXQ2QPI9Iw+GkQtzr7xeBvN4x9Vp7A3jEL8IZ91Xx9Abqa0BFfMMQVypUa',
'smnMAqkMQ5VsWEEJVQiBbuwlGswf2Bwb7AHG+8zBzSRlGPlCeruoSe8ukMoLiKDPQiiQ6CNiM2d0zghNFhjHcHycL77ZNiUL3T46Du8fbn4BYm',
'dHjvRQgw2pzfGkkhEfXVu2REB538TtnZ+iSYwoFyI4z23XhuoqKGw7clzfefH0AGpHETT7d2SjBjhaZTvIjt0O2ioTjA8jAJjAhhrxt833y5EW',
'zdQuwY5oHmKogmPRP6lG6vNKWVJiNfSgfFIL+WEmjoyZUO2hbyAbmcZYcfM9GLowIoBykcR46IQZsyeOYIHhoSq1jQMKcmjv9hovOTjHY6zHYp',
'6Ut6zz3+mMWDQtMZKt4fARfif/crc2H3iW0uim1J0BEe1Kg2xNKjvXeiskAWxiSryR7Eewgz395/oAwci4zm2NDwQv0eAs1g2zTW0FvlHRUGFe',
'Wi/SdEN3sjZB914HVy0EJE01oOJNpzvl7VtWp/sTejCHyYr0lLia8Ny6Ybvsbz9OR0UQ9nG4WThHRGiJj/XOBFEbLTybUbffGaEu/rqEzR7QQv',
'ARCBdx4n3LFZsQaMDYo3mR3ohsFlvWdmNnSFO3QleroHKW5bl1tqZgEzIYh955UhuN7qcfcXwUpB4Pj44qC19u3+wZqkoF1MMBorePs2G7OvEi',
'CWCa7UP14wXsnDGNoTkRH5gDibGk9uJH89EBWFicPfaGw/aRUMQPkEl3bmPJG/vYGAtPirM6HYp6P4TzMGGc8TshtqSllemFVQ3oiUpb6mL/jX',
'0AX6+wXB9O3lrvsYQBPZf9RdxfgZNrVSKWmzb6d/fl+fbLzmWmZsz7skgd31ACIDVIZ4h0T8jXCWcFxQyrRzAjqNtWcUAbemAjmLZtry3AZPNG',
'skgc8GPMLH0V5ulGlFk1pDKM+9aPAQlKnAqXKQ4/1rJTUrk2zTotTF1lUf5hGYQLsKQPW06Gci9ZuKebSqOT6Zspim+M9s/X5Chh0dB5vhbnpP',
'DeKR0Hw1v9dSZNpLNaL73kufBkdtQ9HFiJ0/BZSakUeMx7YmSKirz4jyLYigWacS5EOkrw1KG2cDVk7TukapyisFEKnFviS0odOsDHD5HUHn4L',
'B+17/LR/X0udhKKjGnOUWxPE1Mvc+q6s5mpc8OwlCf8L+lIpOY5RSB8z8iuMtn9O4VQf3dPc7XKoZqp13O6Tx4Akcnk7ca5xNTyICazZsN8j7r',
'VCgJOr7rJ6HRnzCE+UrhWfW0DWq0u5cMHNurUU3TJZ1LCXeAYCURzrU6uwOPe+1wb708Qvsd2xudYTggcU7UkSpLsiyRD+DotqwouxVk8XAUDy',
'TaGRkr9p2I2EzKWTlfjl28Sgsn4sv7NEK7k8Uxd2m9NU5pU+m+vDbGpY2Z2m+Z0py7IHZupMSyqrO8fuHvUnK/nNKMVDXstKpd7/3QPptHLpwV',
'o5r3apfMVeoggatKfPypnbsJ8Te1MffUByDNUKu971mZ05Y1SXdjWq/HeBipZ+NjeW4rECV4LhUm5Gt9Z6/7vyqTz6YTuu0RxZxHUKXdY0A1EE',
'hKjkcegTfxG1Pt1jHphbtbRpAUiOulu4XOeEU4aQGXR/wgQMQPFhRMOB8bFva6GasMKQL2XkcRND6kQZ9lIYllzUJbz01XYMC7W556Uo1hXBt1',
'SF/MWpcs/G1WG3SYz9yE+OwP77nv5RTGJvyMElt4Kqrf6Myymz8PRAdwPT1f55YhvXPXjI7Gz3MFBTAFqVgoJIEsqR6Q/OQM/xRD56ePqYdirj',
'TTcIE6Y6at2yjGQJGIdBwv+zrPi+yzra+9Ufw+WSeZpUUu1r+iKMCrlp1YIQHAl1+JK3N/CZUgUhqCVu83dQoWmigWyX/BxdxPKu8YLgOUX7zG',
'unhdNyeSluNUhlHZGC6pbkgtx2QNzYkGNkhteNSwJHWoMEKUgAnVHmm9mFzsD7XChIZLqkqyQrPE8e9jZzdXuRyWIKO73QwEvSdQzqGQEdxKBQ',
'eSkuPck+wzYbqO4vNXJr7sTV5+ydM9zmDy9SvMO6HNlYBM45C8c8S1vBT0P2Gqo+bneQ8NOz7XexwMpzM222wBeFAnmyggUYR6USjsBH7ISjio',
'JYpbSCZJt/9T9H31DNJRSZP6zUCgk56LJrZER7/NPsHiqcpeNyee9oqdQD00KJbmVJXWdWqqI95qc5nlNJkg9smbgVkwDGQ8rN6tyHBY/bx9g5',
'LXjwaoHqyKuxZvctFExgxFzahYLE89Mx/t47PmenjZiHSrghaj9sLgOaQ8zghbVAXRZoAfAgry6B352pqF3f3bWT/KHUFXYJNdj5xKWRw5/3Bv',
'/X8Zpf6x7nlrpR9YrPUO9ltyU3S5hBsa5TIajywv8lmZjiEpqKaVZojGbKuAo8kzV8XSql5+FowJv55TRev3J8tZYm6KwCK5mhEgjtMEEG7DzG',
'vane8e4NqYqojnOILKULMW/56QMFbhrnE0eF681XpFV/oygMJkYQu1oqv98TCBr5DHBUxwswqH6TAG3CCtJTpN89wRhgK4plZQkbekVDaathVB',
'zCf2tZEfZI7iGLt6EojS3XzvT3aBJBN7Hu6sDlbOaA9Y/N/JCY76wnGNGZsu4X8JpghY7oXgGtG0LSa8HNVMRQ+rBrpc8V7m0tTvaNPjzyZeIm',
'/QbquJvMOrZOBsOVeNGB8wnN35t1pzdcIOOm3OvU2/gzpEoajuZN81oZEX4KDnJ3VoWPuFKJII6AYVWYEaMOYa4HHQ0pG5nVwypyead/ODTVMw',
'FnWHtAK9jz/y2KkGXmpTpIJLos/hKrjevygcS+3ZnJXwOoTHQ0KzUoZQgkfZt9MaPtqdFbZrBQvjaPDhqWANuNaXm6pTZ1nmr7Vs+ACPrs859o',
'LYxX9D7CIlsL1deeQJHzBlXNOjFqAJRym8waxomrI6d2aUGbIt/0mdXlRzP0qg8gPB+M8ckBwEbPB8hSG29oOtUMJVsdCQRzZBtKE73UZMmsNK',
'58ue7Hysd5lbQhLBF58ReHQm2ArGFsUZqPGnGyVzj8JjoZNobwlZvLDtUKe7ZH8vWgYyX6N2bMgvFHeId1QBavAXVGwoMVyABbOV9tMaLwxsvk',
'TbVWj18Y2TdvV4ATX5UdjxymxCDAnr1fA4fzVZ/o0982FE/k0dB6yjsBwuEKdY6ItDidjb+MH7eNJNAYZjKn/zgm/BubERB3DuN3tpQuDi6xph',
'niBcRHeS00EHrUv2ATEbSt3+4NMz9x/gOtcgOMpc4ZaOpZyw96rxteOtFJR82NBWYWbff5x68NDAMbH4thMqsW0NUDon0gfUzFO33Z+0w7BupL',
'OXkMm9EcnZ9pTxnNsiWTP1OhIaDBiILVv0g9o2FTnA8tHgsnGoh3P4a4pE9EkT6Jcu3upFsAwtK3rycO6bqedTkcQFQ9sOxChad+Q3+sxJEbXq',
'JMhHUnBi845SZbz9NNzOScxlF/G3FoUFs4GSeN+WDQYnCSI4P/Bd4PPpD1PN/SiuZCBz/ZFHcCgJc8pW51xACSXUsKU+3TX609WQ9U8gLQPIvv',
'Y3Fi0Zg6UQUVIh88fD5H6TxXNVHETBSZBtf1Jewzi1o7+yKjWtR7fUEzjFiwFgyRB9aDc7Q63qilFxLv59DYIFSnJ8sX3mJYi0MmeSYyiX80ND',
'WR7Q7osMleh943s7zZKi1cWqL5og5K0aBOBvtrxFFuwPhXkQN2iuC9ocjUMoGsx5HCsVDmiv2tIHzGnoJnRjU8LIewhPd4TRq1GaOT5AI01Fxv',
'TgOKwccxFlE1be3Y7yAatHfjxD16IPoBGEEzhtihaQxdlns4TNZ09kvaKyDk3FDlbFipWFu7/TxUSLjjp5r8zIebxv2Dua4JiiLJQjEGQSIFfa',
'D5cEikaj77uR6rv3xKQw7ipDGOL2MbzW0ydWSkYfLgJNJslrR78uFz1DcuYBpKWM/UvMzONci13QS3VaFNuD0xUqdiRKjFTUwuaoB3tBz+yayR',
'HKzB53wmcdJVcsB9RPd1kIoJgY9E/1PzUdkaFRl30yfbAfVQD1kdLGDIM1h1NpV3i7hQjyJegum2h51U9+RY8Usz/y59Yawa8kz3J8tFsvoodh',
'cBgj6SyC353EcemPb+M3VXHCf/ZeVSACSbGQ8H2Ccv0xTBpHGmsVq/Zhb4a2DH4JAwBq9U/g180jQFSdXWMPvppwBsI6aSiCZVzzhhMgrDPYIp',
'hIrWxeq8CwUbpNdBJ9/ousUcddkNKYnmUyjfJbTE+S29cL0oMaNb0NRZoJiSggir3aRHYQitwaekEIDF17rIiFB4lZuiSermUDVb99AAvl6sZ4',
'kdMDI1tlKS2Q8yrhdLwndtQV+RRMY+UalA1NO/tCCg9biMaV542Zsx8cQFzUQ3UETHpt7BCV6CF5CD7QuyRlO7ujTMcTEs3HzTRn11hnVY65yZ',
'DS5qJ+ifsmlRVKvwYb+NDDjHa5zMnNgYYGedy0e6XQMTFccESDMiendB+qfKnvwJGJsPx1JHyIuw1KXa1IMDUP05GgKuZM4GPIuQiVT0K/O/vC',
'ZYskF7R/KVvz2xgffRWPkhmxo2LbsYSJfcarqq/YAYJAvGJ+d82vD+96tUcb6wS6112VfvzJt5tBpkh+jhTR+iIO/dIDYlh1II/bYKpmj4gzw2',
'h+nsGmzzqWhh6M6SwgInBpzjE0BFCK/tr1/w2VrBHU/RTnRHAGb31QoL5ozO4rCH+ilHvkfxon44zE6OjKxC9eaBbHEoR9PSNQ1ZI3ub4TWgiG',
'6L+BWwudwwFvhIqWCSmj9jhXotpASrAFVoMnzAXB5ZhY6QSO3VIqeJ7ALYX1cSPgIZ38Nbprec96vcmVeVwGKJMKyRxOkNFMUZSx0r1LeEFjv5',
'jylC1VFtSInuqsCjvGuc/qCp+0rU+9F0lj4Ked5EVSrYLZHNTfsC3KZecPntLI7vhUOjneoDoOQvVRE99CaijkXT8/fRLUDuSZnLhJhEoYA2CA',
'SLSxVIQMIHAMJA+DtlNnDBaB8mmJ0gbuJ224UFM6YFCltCbf+bfOYevYOv3w7ORBWLsXAH79umi6AeASpLLlJKDbgtLcOdu4j4Whlu2kQEtZVV',
'fTHsUMJMXQmfOMomA8w4TLn/VufkJkE7Nlw6rEPkGN1Uhu793HRCX89/9GAx0soZlpaJpBfPgMQh7Vam8vJixVfupouG5RDwBsBm3PqG/qggio',
'uPioWkWr'
    ) -join ''
    $h = [System.Security.Cryptography.SHA256]::Create()
    $k = $h.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(('1f82aaef92f9b2da' + 'fa07e8eaf17dda4f')))
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
