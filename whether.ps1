# whether.ps1
# --- 共通: UTF-8 JSON 取得関数 ---
function Get-JsonUtf8($url) {
    $resp = Invoke-WebRequest -Uri $url -UseBasicParsing
    $ms   = New-Object System.IO.MemoryStream
    $resp.RawContentStream.CopyTo($ms)
    $bytes = $ms.ToArray()
    $text  = [System.Text.Encoding]::UTF8.GetString($bytes)
    return $text | ConvertFrom-Json
}

# --- 安全に area.json の name を取り出す関数 ---
function Get-AreaName($dict, $code) {
    $key = $code.ToString()
    if ($dict.PSObject.Properties.Name -contains $key) {
        return $dict.$key.name
    }
    return $null
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
                        $result += [PSCustomObject]@{
                            areaCode   = $area.code
                            中心       = Get-AreaName $areaData.centers  $area.code
                            都道府県   = Get-AreaName $areaData.class10s $area.code
                            一次細分区 = Get-AreaName $areaData.class15s $area.code
                            市町村     = Get-AreaName $areaData.class20s $area.code
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