param(
    [Parameter(Mandatory = $true)]
    [string]$Title,

    [Parameter(Mandatory = $true)]
    [string]$Message
)

Add-Type -AssemblyName PresentationFramework

# WPFウィンドウ定義
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="$Title"
        Height="150" Width="350"
        WindowStartupLocation="Manual"
        Topmost="True" ResizeMode="NoResize"
        WindowStyle="ToolWindow" Background="LightYellow" Opacity="0.95">
    <Border CornerRadius="8" BorderBrush="Gray" BorderThickness="1" Padding="10">
        <StackPanel>
            <TextBlock Text="$Title" FontSize="18" FontWeight="Bold" Margin="0,0,0,10"/>
            <TextBlock Text="$Message" FontSize="14" TextWrapping="Wrap"/>
        </StackPanel>
    </Border>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# 画面右下に配置
$screenWidth  = [System.Windows.SystemParameters]::PrimaryScreenWidth
$screenHeight = [System.Windows.SystemParameters]::PrimaryScreenHeight
$window.Left  = $screenWidth - $window.Width - 20
$window.Top   = $screenHeight - $window.Height - 150

# タイマー：10秒後に自動で閉じる
$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(10)
$timer.Add_Tick({ $window.Close() })
$timer.Start()

$window.ShowDialog() | Out-Null