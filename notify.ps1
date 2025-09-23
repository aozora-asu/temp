param(
    [Parameter(Mandatory = $true)]
    [string]$Title,

    [Parameter(Mandatory = $true)]
    [string]$Message
)

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# WPF Window を直接コードで構築
$window = New-Object System.Windows.Window
$window.Title = $Title
$window.Width = 350
$window.Height = 150
$window.WindowStartupLocation = 'Manual'
$window.Topmost = $true
$window.ResizeMode = 'NoResize'
$window.WindowStyle = 'ToolWindow'
$window.Background = 'LightYellow'
$window.Opacity = 0.95

# スタックパネル
$stack = New-Object System.Windows.Controls.StackPanel
$stack.Margin = '10'

# タイトル
$titleBlock = New-Object System.Windows.Controls.TextBlock
$titleBlock.Text = $Title
$titleBlock.FontSize = 18
$titleBlock.FontWeight = 'Bold'
$titleBlock.Margin = '0,0,0,10'

# メッセージ
$msgBlock = New-Object System.Windows.Controls.TextBlock
$msgBlock.Text = $Message
$msgBlock.FontSize = 14
$msgBlock.TextWrapping = 'Wrap'

$stack.Children.Add($titleBlock) | Out-Null
$stack.Children.Add($msgBlock)   | Out-Null

$window.Content = $stack

# 右下に配置
$screenWidth  = [System.Windows.SystemParameters]::PrimaryScreenWidth
$screenHeight = [System.Windows.SystemParameters]::PrimaryScreenHeight
$window.Left  = $screenWidth - $window.Width - 20
$window.Top   = $screenHeight - $window.Height - 150

# タイマーで自動クローズ（10秒後）
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(10)
$timer.Add_Tick({
    $timer.Stop()
    $window.Close()
})
$timer.Start()

# 表示
$window.ShowDialog() | Out-Null