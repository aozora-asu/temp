# 共通設定
$BaseUrl   = "https://teideninfo.tepco.co.jp/flash/xml"
$AuthToken = "sk3PT518"

function Get-Xml($areaCode) {
    $Url = "$BaseUrl/$areaCode.xml"
    curl.exe -s -A "Mozilla/5.0" `
        -H "Referer: https://teideninfo.tepco.co.jp/" `
        -H "Cookie: teideninfo-auth=$AuthToken" `
        -o temp.xml `
        $Url | Out-Null
    return [xml](Get-Content temp.xml -Encoding UTF8 -Raw)
}

function Get-Notices($xml) {
    $msgs = @()
    for ($i=1; $i -le 13; $i++) {
        $msg = $xml."東京電力停電情報"."お知らせ$i"
        if ($msg -and $msg.Trim() -ne "") {
            $msgs += $msg.Trim()
        }
    }
    return $msgs
}

function Format-Detail($detailText, $indent = "    ") {
    if (-not $detailText) { return @() }
    $lines = $detailText -split "`r?`n"
    return $lines | ForEach-Object { "$indent$_" }
}

# === 状態ファイル ===
$stateFile = Join-Path $PSScriptRoot "outage_state.json"
$prevState = @{}

if (Test-Path $stateFile) {
    try {
        $json = Get-Content $stateFile -Raw | ConvertFrom-Json
        foreach ($prop in $json.PSObject.Properties) {
            $prevState[$prop.Name] = $prop.Value
        }
    } catch { $prevState = @{} }
}

# === 最新データ取得 ===
$xmlAll = Get-Xml "00000000000"
$globalNotices = Get-Notices $xmlAll

# 停電1000件超の都道府県
$current = @{}
$prefResults = foreach ($area in $xmlAll."東京電力停電情報".エリア) {
    if ($area.停電軒数 -and [int]$area.停電軒数 -gt 1) {
        [PSCustomObject]@{
            都道府県    = $area.名前
            停電軒数    = [int]$area.停電軒数
            エリアコード = $area.コード
        }
    }
}

# === 通知文の組み立て（notifyText） ===
$notifyText = ""
foreach ($msg in $globalNotices) {
    $notifyText += "<停電情報> $msg`n"
}
foreach ($pref in $prefResults) {
    $xmlPref = Get-Xml $pref.エリアコード
    $notifyText += "  $($pref.都道府県) : $($pref.停電軒数)軒`n"

    # 都道府県レベルのお知らせ
    $prefNotices = Get-Notices $xmlPref
    foreach ($msg in $prefNotices) {
        $notifyText += "    $msg`n"
    }

    # 地域ごとの停電情報
    foreach ($subArea in $xmlPref."東京電力停電情報".エリア) {
        if ($subArea.停電軒数 -and [int]$subArea.停電軒数 -gt 0) {
            $xmlCity = Get-Xml $subArea.コード
            $detail = $xmlCity."東京電力停電情報".地域詳細情報
            $notifyText += "    $($subArea.名前) : $($subArea.停電軒数)軒`n"
            if ($detail) {
                $notifyText += (Format-Detail $detail "      ") -join "`n"
                $notifyText += "`n"
            }
        }
    }
}

# === 差分検出 ===
$changed = @()

# 現在1000件超えのエリア
foreach ($pref in $prefResults) {
    $xmlPref = Get-Xml $pref.エリアコード
    $notices = Get-Notices $xmlPref
    $noticeText = $notices -join " / "

    $value = "$($pref.停電軒数):$noticeText"
    $current[$pref.都道府県] = $value

    if (-not $prevState.ContainsKey($pref.都道府県) -or $prevState[$pref.都道府県] -ne $value) {
        $changed += [pscustomobject]@{
            Title   = "停電情報"
            Message = $notifyText   # ← ここをnotifyTextに統一
            Key     = $pref.都道府県
            Value   = $value
        }
    }
}

# 復旧検出
foreach ($k in @($prevState.Keys)) {
    if (-not $current.ContainsKey($k)) {
        $changed += [pscustomobject]@{
            Title   = "停電復旧"
            Message = "$k の停電件数が1000件以下に戻りました。"
            Key     = $k
            Value   = $null
        }
    }
}

# === 通知 ===
foreach ($c in $changed) {
    & "$PSScriptRoot/notify.ps1" -Title $c.Title -Message $c.Message

    Write-Output $c.Message

    if ($c.Value) {
        $prevState[$c.Key] = $c.Value
    }
    else {
        $prevState.Remove($c.Key) | Out-Null
    }
}

# 状態を保存
$prevState | ConvertTo-Json | Set-Content -Path $stateFile -Encoding UTF8
