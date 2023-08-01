# Authentication parameters
$clientId = "" # Replace with your Azure AD application client ID
$tenantId = "" # Replace with your tenant ID
$authority = "https://login.microsoftonline.com/$tenantId"
$scopes = @("https://graph.microsoft.com/.default")

# Load necessary assemblies for GUI
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

# Define the form
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Select Win32 App'
$form.Size = New-Object System.Drawing.Size(1000, 600)

# Define the ListView
$ListView = New-Object System.Windows.Forms.ListView
$ListView.Location = New-Object System.Drawing.Point(10, 10)
$ListView.Size = New-Object System.Drawing.Size(960, 400)
$ListView.Font = New-Object System.Drawing.Font("Arial", 12)
$ListView.View = [System.Windows.Forms.View]::Details
$ListView.CheckBoxes = $true

# Add columns
$ListView.Columns.Add('Display Name', 400)
$ListView.Columns.Add('Status', 200)
$ListView.Columns.Add('App ID', 350)

# Acquire a token
$tokenResult = Get-MsalToken -ClientId $clientId -Authority $authority -Scopes $scopes
$token = $tokenResult.AccessToken

# Get the list of apps
$uri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?$filter=(isof('microsoft.graph.win32LobApp'))&$select=id,displayName,allowAvailableUninstall"
$headers = @{
    'Authorization' = "Bearer $token"
}
$response = Invoke-RestMethod -Uri $uri -Headers $headers

# Populate the ListView with app names, status, and IDs
foreach ($app in $response.value) {
    $status = if ($app.allowAvailableUninstall) { "Enabled" } else { "Disabled" }
    $item = New-Object System.Windows.Forms.ListViewItem($app.displayName)
    $item.SubItems.Add($status)
    $item.SubItems.Add($app.id)
    $ListView.Items.Add($item) | Out-Null
}

# Function to update the allowAvailableUninstall property
function Update-App([bool]$value) {
    $selectedApps = $ListView.Items | Where-Object { $_.Checked }

    if ($selectedApps.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select an app to update.", "Warning")
        return
    }

    foreach ($item in $selectedApps) {
        $appID = $item.SubItems[2].Text
        $updateUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$appID"
        $json = @{
            "@odata.type"             = "#microsoft.graph.win32LobApp"
            "allowAvailableUninstall" = $value.ToString().ToLower()
        } | ConvertTo-Json
        Invoke-RestMethod -Uri $updateUri -Headers $headers -Method Patch -ContentType "application/json" -Body $json
        $item.SubItems[1].Text = if ($value) { "Enabled" } else { "Disabled" }
    }
    [System.Windows.Forms.MessageBox]::Show("Updated successfully!", "Success")
}

# Define the buttons
$enableButton = New-Object System.Windows.Forms.Button
$enableButton.Location = New-Object System.Drawing.Point(10, 420)
$enableButton.Size = New-Object System.Drawing.Size(480, 60)
$enableButton.Text = 'Enable'
$enableButton.Font = New-Object System.Drawing.Font("Arial", 12)
$enableButton.Add_Click({ Update-App $true })

$disableButton = New-Object System.Windows.Forms.Button
$disableButton.Location = New-Object System.Drawing.Point(500, 420)
$disableButton.Size = New-Object System.Drawing.Size(480, 60)
$disableButton.Text = 'Disable'
$disableButton.Font = New-Object System.Drawing.Font("Arial", 12)
$disableButton.Add_Click({ Update-App $false })

# Add controls to form
$form.Controls.Add($ListView)
$form.Controls.Add($enableButton)
$form.Controls.Add($disableButton)

# Show the form
$form.ShowDialog()