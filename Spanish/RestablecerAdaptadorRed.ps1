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
[System.Windows.MessageBox]::Show("Iniciando el proceso de reinicio del adaptador de red. Por favor, espere...", "Información")

# Enable disabled network adapters
Get-NetAdapter | Where-Object { $_.Status -eq "Disabled" } | Enable-NetAdapter -Confirm:$false
Start-Sleep -Seconds 5

# Get active network adapters
$adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }

# Check if there are active network adapters but not the Wi-Fi adapter
$wifiAdapter = $adapters | Where-Object { $_.Name -like "*Wi-Fi*" }

if ($null -eq $wifiAdapter) {
    [System.Windows.MessageBox]::Show("No se encontró el adaptador Wi-Fi. Intentando reinstalar controladores.", "Error")

    # Reinstall network drivers
    pnputil /scan-devices
    Start-Sleep -Seconds 10

    # Retry to get active network adapters
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    $wifiAdapter = $adapters | Where-Object { $_.Name -like "*Wi-Fi*" }

    if ($null -eq $wifiAdapter) {
        [System.Windows.MessageBox]::Show("No se encontró el adaptador Wi-Fi después de reinstalar controladores. Asegúrese de que el adaptador esté conectado y vuelva a intentarlo.", "Error")
        exit
    }
}

# Show the adapters to the user and ask for a selection
$adapter = $wifiAdapter | Out-GridView -Title "Seleccione el adaptador de red" -PassThru

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
        [System.Windows.MessageBox]::Show("Deshabilitando el adaptador de red: $adapterName", "Información")
        Disable-NetAdapter -Name $adapterName -Confirm:$false
        Start-Sleep -Seconds 5

        # Enable network adapter
        [System.Windows.MessageBox]::Show("Habilitando el adaptador de red: $adapterName", "Información")
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
            [System.Windows.MessageBox]::Show("Conexión a Internet exitosa.", "Éxito")
        } else {
            [System.Windows.MessageBox]::Show("Fallo en la conexión a Internet. Intentando reconectar a la red Wi-Fi de casa...", "Advertencia")
            
            # Get available Wi-Fi networks
            $wifiNetworks = netsh wlan show networks | Select-String -Pattern 'SSID' | ForEach-Object { $_.ToString().Split(':')[1].Trim() }
            $wifiNetwork = $wifiNetworks | Out-GridView -Title "Seleccione la red Wi-Fi" -PassThru

            if ($null -ne $wifiNetwork) {
                $wifiPassword = Show-InputBox -message "Introduzca la contraseña para la red $wifiNetwork" -title "Contraseña de la red Wi-Fi"
                
                if ($null -ne $wifiPassword) {
                    # Connect to selected Wi-Fi network
                    netsh wlan connect name=$wifiNetwork ssid=$wifiNetwork key=$wifiPassword

                    # Wait a few seconds and try the connection again
                    Start-Sleep -Seconds 10
                    $pingResult = Test-Connection -ComputerName google.com -Count 4 -ErrorAction SilentlyContinue

                    if ($pingResult) {
                        [System.Windows.MessageBox]::Show("Conexión a Internet exitosa.", "Éxito")
                    } else {
                        [System.Windows.MessageBox]::Show("Fallo en la conexión a Internet. Por favor, verifique la configuración de su red.", "Error")
                    }
                } else {
                    [System.Windows.MessageBox]::Show("No se proporcionó una contraseña. Operación cancelada.", "Error")
                }
            } else {
                [System.Windows.MessageBox]::Show("No se seleccionó ninguna red Wi-Fi. Operación cancelada.", "Error")
            }
        }
    } catch {
        [System.Windows.MessageBox]::Show("Ocurrió un error: $_", "Error")
    }
} else {
    [System.Windows.MessageBox]::Show("Operación cancelada por el usuario.", "Información")
}
