# Load required assemblies
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# Function to display an input box
function Show-InputBox {
    param (
        [string]$message,
        [string]$title
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $title
    $form.Width = 400
    $form.Height = 150

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $message
    $label.AutoSize = $true
    $label.Top = 20
    $label.Left = 20
    $form.Controls.Add($label)

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Width = 350
    $textBox.Top = 50
    $textBox.Left = 20
    $form.Controls.Add($textBox)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "OK"
    $okButton.Top = 80
    $okButton.Left = 250
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Controls.Add($okButton)

    $form.AcceptButton = $okButton
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen

    if ($form.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $textBox.Text
    } else {
        return $null
    }
}

# Show a message to the user
[System.Windows.MessageBox]::Show("Starting the network adapter reset process. Please wait...", "Information")

# Enable disabled network adapters
Get-NetAdapter | Where-Object { $_.Status -eq "Disabled" } | Enable-NetAdapter -Confirm:$false
Start-Sleep -Seconds 5

# Get active network adapters
$adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }

# Check if there are active network adapters but not the Wi-Fi adapter
$wifiAdapter = $adapters | Where-Object { $_.Name -like "*Wi-Fi*" }

if ($null -eq $wifiAdapter) {
    [System.Windows.MessageBox]::Show("Wi-Fi adapter not found. Trying to reinstall drivers.", "Error")

    # Reinstall network drivers
    pnputil /scan-devices
    Start-Sleep -Seconds 10

    # Retry to get active network adapters
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    $wifiAdapter = $adapters | Where-Object { $_.Name -like "*Wi-Fi*" }

    if ($null -eq $wifiAdapter) {
        [System.Windows.MessageBox]::Show("Wi-Fi adapter not found after reinstalling drivers. Make sure the adapter is connected and try again.", "Error")
        exit
    }
}

# Show the adapters to the user and ask for a selection
$adapter = $wifiAdapter | Out-GridView -Title "Select the network adapter" -PassThru

if ($null -ne $adapter) {
    try {
        # Path to save backup copy of Wi-Fi settings
        $backupFolder = "C:\temp\WiFiBackup"

        # Create temporary folder if it does not exist
        if (-not (Test-Path $backupFolder)) {
            New-Item -ItemType Directory -Path $backupFolder
        }

        # Back up Wi-Fi settings
        netsh wlan export profile folder=$backupFolder key=clear | Out-Null

        $adapterName = $adapter.Name

        # Disable network adapter
        [System.Windows.MessageBox]::Show("Disabling network adapter: $adapterName", "Information")
        Disable-NetAdapter -Name $adapterName -Confirm:$false
        Start-Sleep -Seconds 5

        # Enable network adapter
        [System.Windows.MessageBox]::Show("Enabling network adapter: $adapterName", "Information")
        Enable-NetAdapter -Name $adapterName -Confirm:$false
        Start-Sleep -Seconds 10

        # Force driver reinstallation
        pnputil /scan-devices

        # Restore Wi-Fi settings
        $profiles = Get-ChildItem $backupFolder -Filter "*.xml"
        foreach ($profile in $profiles) {
            netsh wlan add profile filename=$profile.FullName | Out-Null
        }

        # Test your internet connection
        Start-Sleep -Seconds 20
        $pingResult = Test-Connection -ComputerName google.com -Count 4 -ErrorAction SilentlyContinue

        if ($pingResult) {
            [System.Windows.MessageBox]::Show("Internet connection successful.", "Success")
        } else {
            [System.Windows.MessageBox]::Show("Failed to connect to the Internet. Trying to reconnect to the home Wi-Fi network...", "Warning")
            
            # Get available Wi-Fi networks
            $wifiNetworks = netsh wlan show networks | Select-String -Pattern 'SSID' | ForEach-Object { $_.ToString().Split(':')[1].Trim() }
            $wifiNetwork = $wifiNetworks | Out-GridView -Title "Select the Wi-Fi network" -PassThru

            if ($null -ne $wifiNetwork) {
                $wifiPassword = Show-InputBox -message "Enter the password for the $wifiNetwork network" -title "Wi-Fi Network Password"
                
                if ($null -ne $wifiPassword) {
                    # Connect to selected Wi-Fi network
                    netsh wlan connect name=$wifiNetwork ssid=$wifiNetwork key=$wifiPassword

                    # Wait a few seconds and try the connection again
                    Start-Sleep -Seconds 10
                    $pingResult = Test-Connection -ComputerName google.com -Count 4 -ErrorAction SilentlyContinue

                    if ($pingResult) {
                        [System.Windows.MessageBox]::Show("Internet connection successful.", "Success")
                    } else {
                        [System.Windows.MessageBox]::Show("Failed to connect to the Internet. Please check your network settings.", "Error")
                    }
                } else {
                    [System.Windows.MessageBox]::Show("No password provided. Operation canceled.", "Error")
                }
            } else {
                [System.Windows.MessageBox]::Show("No Wi-Fi network selected. Operation canceled.", "Error")
            }
        }
    } catch {
        [System.Windows.MessageBox]::Show("An error occurred: $_", "Error")
    }
} else {
    [System.Windows.MessageBox]::Show("Operation canceled by the user.", "Information")
}
