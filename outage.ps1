# 取得先URL
$Url = "https://teideninfo.tepco.co.jp/flash/xml/00000000000.xml"
$AuthToken = "sk3PT518"

# 一旦ファイルに保存（UTF-8 で）
curl.exe -s -A "Mozilla/5.0" `
    -H "Referer: https://teideninfo.tepco.co.jp/" `
    -H "Cookie: teideninfo-auth=$AuthToken" `
    -o temp.xml `
    $Url

# UTF-8 として読み込み
$rawXml = Get-Content temp.xml -Encoding UTF8 -Raw

# XML化
$xml = [xml]$rawXml

# 表示
$xml.OuterXml
