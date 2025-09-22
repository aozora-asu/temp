Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# タスクトレイアイコン
$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = [System.Drawing.SystemIcons]::Information
$notify.Text = "運行情報チェッカー: 起動中"
$notify.Visible = $true

# 状態管理
$global:Running = $true

# コンテキストメニュー
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$menu.Items.Add("一時停止") | ForEach-Object { $_.add_Click({ $global:Running = $false; $notify.Text = "運行情報チェッカー: 停止中" }) }
$menu.Items.Add("再開")     | ForEach-Object { $_.add_Click({ $global:Running = $true;  $notify.Text = "運行情報チェッカー: 稼働中" }) }
$menu.Items.Add("終了")     | ForEach-Object { $_.add_Click({ 
    $notify.Visible = $false
    [System.Windows.Forms.Application]::Exit()
    exit
}) }

$notify.ContextMenuStrip = $menu

# 実行ループ
while ($true) {
    $hour = (Get-Date).Hour

    if ($hour -ge 0 -and $hour -lt 4) {
        # 停止時間帯
        $notify.Icon = [System.Drawing.SystemIcons]::Warning
        $notify.Text = "運行情報チェッカー: 停止時間帯 (0:00-04:00)"
    }
    elseif ($global:Running) {
        # 稼働中
        $notify.Icon = [System.Drawing.SystemIcons]::Information
        $notify.Text = "運行情報チェッカー: 稼働中 (最終実行: $(Get-Date -Format 'HH:mm:ss'))"

        # train.ps1 実行
        $trainScript = Join-Path $PSScriptRoot "train.ps1"
        if (Test-Path $trainScript) {
            & powershell -ExecutionPolicy Bypass -File $trainScript
        }
    }
    else {
        # ユーザーが停止中
        $notify.Icon = [System.Drawing.SystemIcons]::Error
        $notify.Text = "運行情報チェッカー: ユーザー停止中"
    }

    Start-Sleep -Seconds 10
}