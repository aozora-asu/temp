<#
.SYNOPSIS
  運行情報チェッカー メインスクリプト
.DESCRIPTION
  - デスクトップ右下に状態小窓を表示
  - 10秒ごとに train.ps1 を実行
  - 0:00〜04:00はデフォルト停止
  - ボタンで停止/再開/終了が可能
  - 状態に応じて小窓の色と文字を変える
  - UIは即時反映、train.ps1は非同期実行
#>

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms   # 確認ダイアログ用

# 夜間判定関数
function IsNight([datetime]$dt) {
    return ($dt.Hour -ge 0 -and $dt.Hour -lt 4 -and $dt.Minute -eq 45)
}

# Mode列挙体
enum Mode {
    Stopped
    Running
    NightStopped
    NightRunning
}

# WPFウィンドウ定義
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="運行チェッカー"
        Height="100" Width="220"
        WindowStartupLocation="Manual"
        Topmost="True" ResizeMode="NoResize"
        WindowStyle="None"
        AllowsTransparency="True" Background="LightGreen" Opacity="0.85">
    <Border CornerRadius="10" BorderBrush="Gray" BorderThickness="1">
        <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
            <TextBlock Name="StatusText" Text="初期化中" FontSize="16" FontWeight="Bold"
                       Foreground="Black" HorizontalAlignment="Center" Margin="0,0,0,5"/>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                <Button Name="ControlButton" Content="停止" Width="60" Height="25" Margin="5"/>
                <Button Name="ExitButton" Content="終了" Width="60" Height="25" Margin="5"/>
            </StackPanel>
        </StackPanel>
    </Border>
</Window>
"@

# WPFロード
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# 右下配置
$screenWidth  = [System.Windows.SystemParameters]::PrimaryScreenWidth
$screenHeight = [System.Windows.SystemParameters]::PrimaryScreenHeight
$window.Left  = $screenWidth - $window.Width - 20
$window.Top   = $screenHeight - $window.Height - 120

# UI要素
$statusLabel = $window.FindName("StatusText")
$btnControl  = $window.FindName("ControlButton")
$btnExit     = $window.FindName("ExitButton")

# 初期モード
$now = Get-Date
if (IsNight $now) { $script:mode = [Mode]::NightStopped }
else              { $script:mode = [Mode]::Running }

# === 共通関数 ===

# UI更新関数（即時描画）
function Update-UI {
    param([Mode]$m, [datetime]$now)

    switch ($m) {
        "Stopped" {
            $statusLabel.Text = "停止中"
            $window.Background = "Tomato"
            $btnControl.Content = "再開"
        }
        "Running" {
            $statusLabel.Text = "稼働中 ($($now.ToString('HH:mm:ss')))"
            $window.Background = "LightGreen"
            $btnControl.Content = "停止"
        }
        "NightStopped" {
            $statusLabel.Text = "停止時間帯 (0-4時)"
            $window.Background = "Khaki"
            $btnControl.Content = "再開"
        }
        "NightRunning" {
            $statusLabel.Text = "稼働中 (夜間)"
            $window.Background = "LightBlue"
            $btnControl.Content = "停止"
        }
    }

    # UIを即時描画
    $window.Dispatcher.Invoke([Action]{}, "Render")
}

# train.ps1 実行（非同期ジョブ）
function Run-Train {
    $trainScript = Join-Path $PSScriptRoot "train.ps1"
    if (Test-Path $trainScript) {
        Start-Job -ScriptBlock {
            & powershell -ExecutionPolicy Bypass -File $using:trainScript
        } | Out-Null
    }
}

# === ボタン処理 ===

# 停止／再開
$btnControl.Add_Click({
    switch ($script:mode) {
        "Running"      { $script:mode = [Mode]::Stopped }
        "Stopped"      { $script:mode = [Mode]::Running }
        "NightStopped" { $script:mode = [Mode]::NightRunning }
        "NightRunning" { $script:mode = [Mode]::NightStopped }
    }
    Update-UI $script:mode (Get-Date)
    if ($script:mode -in @([Mode]::Running, [Mode]::NightRunning)) {
        Run-Train
    }
})

# 終了
$btnExit.Add_Click({
    $result = [System.Windows.Forms.MessageBox]::Show(
        "本当に終了しますか？", "確認",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        $window.Close()
        [System.Windows.Application]::Current.Shutdown()
        exit
    }
})

# === タイマー ===
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(10)
$timer.Add_Tick({
    $now = Get-Date
    $isNight = IsNight $now

    # 昼夜自動切替
    if ($isNight -and $script:mode -eq [Mode]::Running)      { $script:mode = [Mode]::NightStopped }
    if (-not $isNight -and $script:mode -eq [Mode]::NightStopped) { $script:mode = [Mode]::Running }
    if (-not $isNight -and $script:mode -eq [Mode]::NightRunning) { $script:mode = [Mode]::Running }

    Update-UI $script:mode $now
    if ($script:mode -in @([Mode]::Running, [Mode]::NightRunning)) {
        Run-Train
    }
})
$timer.Start()

# 初回更新
Update-UI $script:mode (Get-Date)
if ($script:mode -in @([Mode]::Running, [Mode]::NightRunning)) {
    Run-Train
}

# 表示
$window.ShowDialog()