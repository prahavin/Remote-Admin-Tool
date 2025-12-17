# RemoteAdmin Viewer - V1 (PS 5.1, WPF)
# Tabs: Startseite, Computer, Software
# Login = nur im RAM, wird für WinRM verwendet.
# VNC: öffnet immer C:\RemoteAdminLite\VNC\<ComputerName>.vnc  (ComputerName = Feld "Name" aus Computers.json)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase

# ----------------- State & Pfade -----------------
$Global:State = [ordered]@{
  Cred           = $null
  Computers      = @()
  ComputersPath  = 'C:\RemoteAdminLite\View\Computers.json'
  VncViewerPath  = 'C:\Program Files\uvnc bvba\UltraVNC\vncviewer.exe'  # dein Pfad
  VncProfilesDir = 'C:\RemoteAdminLite\VNC'                              # hier liegen <Name>.vnc
  LogsDir        = 'C:\RemoteAdminLite\Logs'
}

# Ordner sicherstellen
$dirs = @(
  (Split-Path $Global:State.ComputersPath -Parent),
  $Global:State.VncProfilesDir,
  $Global:State.LogsDir
) | Sort-Object -Unique

foreach ($d in $dirs) {
  if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

# Beispiel-Computers.json anlegen (falls fehlt)
if (-not (Test-Path $Global:State.ComputersPath)) {
@'
[
  { "Name": "Test-Laptop", "Host": "Prahavin", "Port": 5900, "Tags": "Home", "Notes": "Prahavin daheim" },
  { "Name": "Handy",       "Host": "192.168.254.4", "Port": 5900, "Tags": "Mobile", "Notes": "droidVNC-NG" }
]
'@ | Set-Content -Path $Global:State.ComputersPath -Encoding UTF8
}

# ----------------- XAML -----------------
$Xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="RemoteAdmin Viewer" Height="720" Width="1120"
        WindowStartupLocation="CenterScreen" Background="#0f1115" Foreground="#e5e7eb">
  <Grid>
    <!-- MAIN -->
    <Grid x:Name="MainGrid" Visibility="Collapsed" Margin="12">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
      </Grid.RowDefinitions>

      <DockPanel Grid.Row="0" Margin="0,0,0,10">
        <TextBlock x:Name="TxtLoginInfo" Foreground="#cbd5e1" FontSize="14" Text="Nicht angemeldet" />
        <DockPanel DockPanel.Dock="Right" LastChildFill="False">
          <Button x:Name="BtnReload" Content="Neu laden" Margin="8,0,0,0" Padding="10,4"/>
          <Button x:Name="BtnLogout" Content="Abmelden"  Margin="8,0,0,0" Padding="10,4"/>
        </DockPanel>
      </DockPanel>

      <TabControl x:Name="MainTabs" Grid.Row="1" Background="#141821">
        <TabItem Header="Startseite">
          <Grid Margin="10">
            <StackPanel>
              <TextBlock Text="RemoteAdmin Viewer – V1" FontSize="24" FontWeight="Bold" Margin="0,0,0,12"/>
              <TextBlock x:Name="TxtStatus" Text="Status: bereit" FontSize="14" Margin="0,0,0,8"/>
              <TextBlock x:Name="TxtCounts" Text="Computer: 0" FontSize="14" Margin="0,0,0,18"/>
              <TextBlock Text="VNC Profile:"/>
              <TextBlock Text="C:\RemoteAdminLite\VNC\<Name>.vnc" Foreground="#93c5fd"/>
              <TextBlock Text="(Die App öffnet immer die .vnc-Datei passend zum Computer-Namen.)"/>
            </StackPanel>
          </Grid>
        </TabItem>

        <TabItem Header="Computer">
          <Grid Margin="10">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="2*"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <DataGrid x:Name="DgComputers" Grid.Column="0" AutoGenerateColumns="False" CanUserAddRows="False"
                      HeadersVisibility="Column" IsReadOnly="True" SelectionMode="Single"
                      Background="#0f1115" AlternatingRowBackground="#1a1f2b">
              <DataGrid.Columns>
                <DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="*"/>
                <DataGridTextColumn Header="Host" Binding="{Binding Host}" Width="*"/>
                <DataGridTextColumn Header="Port" Binding="{Binding Port}" Width="80"/>
                <DataGridTextColumn Header="Tags" Binding="{Binding Tags}" Width="*"/>
                <DataGridTextColumn Header="Notes" Binding="{Binding Notes}" Width="2*"/>
              </DataGrid.Columns>
            </DataGrid>

            <StackPanel Grid.Column="1" Margin="10,0,0,0">
              <TextBlock Text="Aktionen" FontWeight="Bold" FontSize="16" Margin="0,0,0,8"/>
              <Button x:Name="BtnWsman"   Content="WinRM testen"          Margin="0,0,0,6" Padding="10,6"/>
              <Button x:Name="BtnMsg"     Content="Nachricht senden"      Margin="0,0,0,6" Padding="10,6"/>
              <Button x:Name="BtnVnc"     Content="VNC Viewer starten"    Margin="0,0,0,6" Padding="10,6"/>
              <Separator Margin="0,8,0,8"/>
              <TextBlock Text="Nachricht:"/>
              <TextBox x:Name="TbMessage" Height="90" TextWrapping="Wrap" AcceptsReturn="True"/>
            </StackPanel>
          </Grid>
        </TabItem>

        <TabItem Header="Software">
          <Grid Margin="10">
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <StackPanel Orientation="Horizontal" Grid.Row="0">
              <Button x:Name="BtnLoadSoftware" Content="Software-Inventar (Remote)" Padding="10,6" />
            </StackPanel>
            <DataGrid x:Name="DgSoftware" Grid.Row="1" AutoGenerateColumns="True"
                      Background="#0f1115" AlternatingRowBackground="#1a1f2b"/>
          </Grid>
        </TabItem>
      </TabControl>
    </Grid>

    <!-- LOGIN -->
    <Grid x:Name="LoginGrid" Margin="12">
      <Border Background="#141821" CornerRadius="10" Padding="24" BorderBrush="#1f2937" BorderThickness="1">
        <StackPanel>
          <TextBlock Text="Anmelden" FontSize="22" FontWeight="Bold" Margin="0,0,0,16"/>
          <TextBlock Text="Benutzer (z.B. PRAHAVIN\admin)"/>
          <TextBox   x:Name="TbUser" Margin="0,4,0,10" />
          <TextBlock Text="Passwort"/>
          <PasswordBox x:Name="TbPass" Margin="0,4,0,16" />
          <StackPanel Orientation="Horizontal">
            <Button x:Name="BtnLogin"  Content="Anmelden" Padding="14,6"/>
            <Button x:Name="BtnQuit"   Content="Beenden"  Padding="14,6" Margin="8,0,0,0"/>
          </StackPanel>
          <TextBlock x:Name="TxtLoginError" Foreground="#ef4444" Margin="0,12,0,0"/>
        </StackPanel>
      </Border>
    </Grid>
  </Grid>
</Window>
"@

# ----------------- XAML laden & Controls holen -----------------
$reader  = New-Object System.Xml.XmlNodeReader ([xml]$Xaml)
$Window  = [Windows.Markup.XamlReader]::Load($reader)

$MainGrid      = $Window.FindName('MainGrid')
$LoginGrid     = $Window.FindName('LoginGrid')
$TxtLoginInfo  = $Window.FindName('TxtLoginInfo')
$TxtStatus     = $Window.FindName('TxtStatus')
$TxtCounts     = $Window.FindName('TxtCounts')
$BtnReload     = $Window.FindName('BtnReload')
$BtnLogout     = $Window.FindName('BtnLogout')

$DgComputers   = $Window.FindName('DgComputers')
$BtnWsman      = $Window.FindName('BtnWsman')
$BtnMsg        = $Window.FindName('BtnMsg')
$BtnVnc        = $Window.FindName('BtnVnc')
$TbMessage     = $Window.FindName('TbMessage')

$BtnLoadSoftware = $Window.FindName('BtnLoadSoftware')
$DgSoftware      = $Window.FindName('DgSoftware')

$TbUser        = $Window.FindName('TbUser')
$TbPass        = $Window.FindName('TbPass')
$BtnLogin      = $Window.FindName('BtnLogin')
$BtnQuit       = $Window.FindName('BtnQuit')
$TxtLoginError = $Window.FindName('TxtLoginError')

# ----------------- Helper -----------------
function Show-Info($msg){ $TxtStatus.Text = "Status: $msg" }
function Alert($m){ [System.Windows.MessageBox]::Show($m,'Hinweis','OK','Information') | Out-Null }
function AlertErr($m){ [System.Windows.MessageBox]::Show($m,'Fehler','OK','Error') | Out-Null }

function Load-Computers {
  try {
    $json  = Get-Content $Global:State.ComputersPath -Raw -ErrorAction Stop
    $items = $json | ConvertFrom-Json
    if ($items -isnot [System.Collections.IEnumerable]) { $items = @($items) }
    $Global:State.Computers = @($items)
    $DgComputers.ItemsSource = $Global:State.Computers
    $TxtCounts.Text = ('Computer: {0}' -f ($Global:State.Computers.Count))
    Show-Info 'Computerliste geladen'
  } catch {
    AlertErr "Computers.json konnte nicht geladen werden:`n$($_.Exception.Message)"
  }
}

function Get-SelectedRow {
  $row = $DgComputers.SelectedItem
  if (-not $row) { Alert "Bitte erst einen Computer wählen."; return $null }
  if (-not $row.Name) { Alert "In der Zeile fehlt 'Name'."; return $null }
  if (-not $row.Host) { Alert "In der Zeile fehlt 'Host'."; return $null }
  return $row
}

function Ensure-Cred {
  if ($null -eq $Global:State.Cred) { Alert "Bitte erst anmelden."; return $false }
  return $true
}

function Get-SafeFileName([string]$name) {
  # Windows verbotene Zeichen raus
  $bad = [regex]::Escape([string]::Join('', [System.IO.Path]::GetInvalidFileNameChars()))
  return ([regex]::Replace($name, "[$bad]", '_')).Trim()
}

function Start-VncProfileByName([string]$computerName) {
  if (-not (Test-Path $Global:State.VncViewerPath)) {
    AlertErr "UltraVNC Viewer nicht gefunden:`n$($Global:State.VncViewerPath)"
    return
  }

  $safe = Get-SafeFileName $computerName
  $profile = Join-Path $Global:State.VncProfilesDir ($safe + '.vnc')

  if (-not (Test-Path $profile)) {
    AlertErr "VNC Profil fehlt:`n$profile`n`nErstelle es so:`n1) vncviewer.exe öffnen`n2) Verbinden`n3) Options → Password 1234`n4) Save to file → genau hier speichern."
    return
  }

  try {
    # Wichtig: Argumente als Array, damit Quotes sauber sind
    Start-Process -FilePath $Global:State.VncViewerPath -ArgumentList @('-config', $profile) | Out-Null
    Show-Info "VNC gestartet: $([System.IO.Path]::GetFileName($profile))"
  } catch {
    AlertErr "VNC Start fehlgeschlagen:`n$($_.Exception.Message)"
  }
}

# ----------------- Login Events -----------------
$BtnLogin.Add_Click({
  $TxtLoginError.Text = ''
  $user = $TbUser.Text
  $pass = $TbPass.Password

  if ([string]::IsNullOrWhiteSpace($user) -or [string]::IsNullOrWhiteSpace($pass)) {
    $TxtLoginError.Text = "Benutzer und Passwort eingeben."
    return
  }

  try {
    $sec  = ConvertTo-SecureString $pass -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($user,$sec)
    $Global:State.Cred = $cred

    $TxtLoginInfo.Text = "Angemeldet als: $user"
    $LoginGrid.Visibility = 'Collapsed'
    $MainGrid.Visibility  = 'Visible'
    Load-Computers
    Show-Info "angemeldet"
  } catch {
    $TxtLoginError.Text = "Fehler: $($_.Exception.Message)"
  }
})

$BtnQuit.Add_Click({ $Window.Close() })

$BtnLogout.Add_Click({
  $Global:State.Cred = $null
  $TxtLoginInfo.Text = "Nicht angemeldet"
  $MainGrid.Visibility  = 'Collapsed'
  $LoginGrid.Visibility = 'Visible'
  Show-Info "abgemeldet"
})

$BtnReload.Add_Click({ Load-Computers })

# ----------------- Computer Tab -----------------
$BtnWsman.Add_Click({
  if (-not (Ensure-Cred)) { return }
  $row = Get-SelectedRow; if (-not $row) { return }

  $target = [string]$row.Host
  try {
    Test-WSMan -ComputerName $target -ErrorAction Stop | Out-Null
    Alert "WinRM OK auf $target"
  } catch {
    AlertErr "WinRM Fehler auf $target:`n$($_.Exception.Message)"
  }
})

$BtnMsg.Add_Click({
  if (-not (Ensure-Cred)) { return }
  $row = Get-SelectedRow; if (-not $row) { return }

  $target = [string]$row.Host
  $text = $TbMessage.Text
  if ([string]::IsNullOrWhiteSpace($text)) { $text = "Hallo von RemoteAdmin" }

  try {
    Invoke-Command -ComputerName $target -Authentication Negotiate -Credential $Global:State.Cred -ScriptBlock {
      param($m)
      cmd /c "msg * $m"
    } -ArgumentList $text
    Alert "Nachricht gesendet."
  } catch {
    AlertErr "Senden fehlgeschlagen:`n$($_.Exception.Message)"
  }
})

$BtnVnc.Add_Click({
  $row = Get-SelectedRow; if (-not $row) { return }

  # NICHT host/Host verwenden (PowerShell reserved). Wir nutzen Name für .vnc-Datei.
  $computerName = [string]$row.Name
  Start-VncProfileByName -computerName $computerName
})

# ----------------- Software Tab -----------------
$BtnLoadSoftware.Add_Click({
  if (-not (Ensure-Cred)) { return }
  $row = Get-SelectedRow
  if (-not $row) { Alert "Bitte erst im Tab 'Computer' einen Host markieren."; return }

  $target = [string]$row.Host
  try {
    $data = Invoke-Command -ComputerName $target -Authentication Negotiate -Credential $Global:State.Cred -ScriptBlock {
      Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
        Where-Object { $_.DisplayName } |
        Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |
        Sort-Object DisplayName
    }
    $DgSoftware.ItemsSource = $data
    Show-Info "Software-Inventar geladen von $target"
  } catch {
    AlertErr "Inventar fehlgeschlagen:`n$($_.Exception.Message)"
  }
})

# ----------------- Show -----------------
$Window.ShowDialog() | Out-Null
