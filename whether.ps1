# --- 共通: UTF-8 JSON 取得関数 ---
function Get-JsonUtf8($url) {
    $resp = Invoke-WebRequest -Uri $url -UseBasicParsing
    $ms   = New-Object System.IO.MemoryStream
    $resp.RawContentStream.CopyTo($ms)
    $bytes = $ms.ToArray()
    $text  = [System.Text.Encoding]::UTF8.GetString($bytes)
    return $text | ConvertFrom-Json
}
# --- dict内のキーを柔軟に見つける（既存のまま）---
function Find-DictKey($dict, $code) {
    if (-not $dict) { return $null }
    $s = [string]$code
    if ($dict.PSObject.Properties.Name -contains $s) { return $s }
    try {
        $n = [int64]$code
        foreach ($name in $dict.PSObject.Properties.Name) {
            try { if ([int64]$name -eq $n) { return $name } } catch {}
        }
    } catch {}
    return $null
}

# --- コードから親を辿って「市町村→郡→地方→都道府県」を返す ---
function Get-AreaHierarchy($areaData, $code) {
    $levels = @{
        市町村     = $null; 市町村かな = $null
        郡         = $null; 郡かな     = $null
        地方       = $null            # class10s
        都道府県   = $null            # offices
        広域地方   = $null            # centers（必要なら）
    }

    $cur = [string]$code
    for ($i=0; $i -lt 10; $i++) {
        $found = $null; $level = $null; $key = $null
        foreach ($kv in @("class20s","class15s","class10s","offices","centers")) {
            $dict = $areaData.$kv
            $key  = Find-DictKey $dict $cur
            if ($key) { $found = $dict.$key; $level = $kv; break }
        }
        if (-not $found) { break }

        switch ($level) {
            "class20s" { 
                $levels.市町村     = $found.name
                $levels.市町村かな = $found.kana
            }
            "class15s" { 
                $levels.郡     = $found.name
                $levels.郡かな = $found.enName
            }
            "class10s" { 
                # ← 地方は必ずここで確定させる
                if (-not $levels.地方) { $levels.地方 = $found.name }
            }
            "offices"  { 
                if (-not $levels.都道府県) { $levels.都道府県 = $found.name }
            }
            "centers"  { 
                if (-not $levels.広域地方) { $levels.広域地方 = $found.name }
            }
        }

        if ($found.parent) {
            $cur = [string]$found.parent
        } else {
            break
        }
    }
    return $levels
}



# --- 1. JSON 取得 ---
$warningUrl  = "https://www.jma.go.jp/bosai/warning/data/warning/map.json"
$areaUrl     = "https://www.jma.go.jp/bosai/common/const/area.json"

$warningData = Get-JsonUtf8 $warningUrl
$areaData    = Get-JsonUtf8 $areaUrl

# --- 2. warning.json から code == "03" を抽出 ---
$result = @()
foreach ($k in $warningData) {
    foreach ($type in $k.areaTypes) {
        foreach ($area in $type.areas) {
            foreach ($w in $area.warnings) {
                if ($w.code -eq "03") {
                    $atts = if ($w.attentions) { $w.attentions } else { @($null) }
                    foreach ($a in $atts) {
                        $hier = Get-AreaHierarchy $areaData $area.code
                        $result += [PSCustomObject]@{
                            areaCode   = $area.code
                            市町村     = $hier.市町村
                            市町村かな = $hier.市町村かな
                            郡         = $hier.郡
                            郡かな     = $hier.郡かな
                            地方       = $hier.地方
                            都道府県   = $hier.都道府県
                            種類       = $w.code
                            状態       = $w.status
                            条件       = $w.condition
                            注意事項   = $a
                        }
                    }
                }
            }
        }
    }
}

# --- 3. 出力 ---
$result | Format-Table -AutoSize
# === 状態ファイル ===
$stateFile = Join-Path $PSScriptRoot "warning_state.json"
$prevState = @{}
if (Test-Path $stateFile) {
    try {
        $json = Get-Content $stateFile -Raw | ConvertFrom-Json
        foreach ($prop in $json.PSObject.Properties) {
            $prevState[$prop.Name] = $prop.Value
        }
    } catch { $prevState = @{} }
}

# === 都道府県単位でまとめる ===
# === 状態ファイル ===
$stateFile = Join-Path $PSScriptRoot "warning_state.json"
$prevState = @{}
if (Test-Path $stateFile) {
    try {
        $json = Get-Content $stateFile -Raw | ConvertFrom-Json
        foreach ($prop in $json.PSObject.Properties) {
            $prevState[$prop.Name] = $prop.Value
        }
    } catch { $prevState = @{} }
}

# === 現在の状況を都道府県＋注意事項ごとにまとめる ===
$current = @{}

$groupedPref = $result | Group-Object 都道府県
foreach ($g in $groupedPref) {
    $pref = $g.Name
    $rows = $g.Group

    $typeGroups = $rows | Group-Object 注意事項
    $text = "<$pref>`n"
    foreach ($tg in $typeGroups) {
        $type = $tg.Name
        $places = ($tg.Group | Select-Object -ExpandProperty 市町村 | Sort-Object -Unique) -join "、"
        $text += "  $type :`n    $places`n"
    }

    $current[$pref] = $text.TrimEnd()
}

# === 差分検出 ===
$notifyNew = @()
$notifyRecover = @()

foreach ($pref in $current.Keys) {
    if (-not $prevState.ContainsKey($pref) -or $prevState[$pref] -ne $current[$pref]) {
        $notifyNew += $current[$pref]
    }
}
foreach ($pref in $prevState.Keys) {
    if (-not $current.ContainsKey($pref)) {
        $notifyRecover += "<$pref> の警報が解除されました。"
    }
}


# === 通知本文生成 ===
if ($notifyNew.Count -gt 0) {
    $msg = "【警戒情報】`n" + ($notifyNew -join "`n`n")
    & "$PSScriptRoot/notify.ps1" -Title "警戒情報" -Message $msg
    Write-Output $msg
}
if ($notifyRecover.Count -gt 0) {
    $msg = "【警戒解除】`n" + ($notifyRecover -join "`n")
    & "$PSScriptRoot/notify.ps1" -Title "警戒解除" -Message $msg
    Write-Output $msg
}

# === 状態を保存 ===
$prevState = $current.Clone()
$prevState | ConvertTo-Json | Set-Content -Path $stateFile -Encoding UTF8
