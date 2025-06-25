# Verbindung zu Microsoft Graph (Beta-Endpunkte)
Connect-MgGraph -Scopes "DeviceManagementServiceConfig.Read.All", "DeviceManagementManagedDevices.Read.All"

# Autopilot-Geräte abrufen
$devices = @()
$uri = "/beta/deviceManagement/windowsAutopilotDeviceIdentities"
do {
    $response = Invoke-MgGraphRequest -Method GET -Uri $uri
    $devices += $response.value
    $uri = $response.'@odata.nextLink'
} while ($uri)

$devices[0] | Format-List


# Deployment-Profile abrufen
$profiles = (Invoke-MgGraphRequest -Method GET -Uri "/beta/deviceManagement/windowsAutopilotDeploymentProfiles").value

# Autopilot-Events abrufen
$events = @()
$uri = "/beta/deviceManagement/autopilotEvents"
do {
    $response = Invoke-MgGraphRequest -Method GET -Uri $uri
    $events += $response.value
    $uri = $response.'@odata.nextLink'
} while ($uri)

$events[0] | Format-List


# Daten zusammenführen
$report = foreach ($device in $devices) {
    $profile = $profiles | Where-Object { $_.id -eq $device.deploymentProfileId }

    $event = $events | Where-Object {
        $_.deviceSerialNumber -eq $device.serialNumber -or
        $_.managedDeviceName -eq $device.displayName
    } | Sort-Object eventDateTime -Descending | Select-Object -First 1

    [PSCustomObject]@{
        DeviceName          = $device.displayName
        SerialNumber        = $device.serialNumber
        UserPrincipalName   = $device.addressableUserName
        GroupTag            = $device.groupTag
        DeploymentProfile   = $profile.displayName
        DeploymentStartTime = $event.enrollmentStartDateTime
        DeploymentEndTime   = $event.eventDateTime
        DeploymentState     = $event.deploymentState
        SetupStatus         = $event.deviceSetupStatus
    }
}

# HTML mit CSS erzeugen
$htmlPath = "C:\Temp\AutopilotDeploymentReport_$(Get-Date -Format 'yyyyMMdd_HHmm').html"
$style = @"
<style>
    body { font-family: Segoe UI, sans-serif; margin: 20px; }
    h2 { color: #2e6c80; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #ccc; padding: 8px; text-align: left; }
    th { background-color: #f2f2f2; }
    tr.success { background-color: #e6ffe6; }
    tr.failure { background-color: #ffe6e6; }
    tr.inProgress { background-color: #fffbe6; }
</style>
"@

$htmlContent = @()
$htmlContent += "<html><head><meta charset='UTF-8'><title>Autopilot Deployment Report</title>$style</head><body>"
$htmlContent += "<h2>Autopilot Deployment Übersicht</h2>"
$htmlContent += "<table><tr>" + ($report[0].psobject.Properties.Name | ForEach-Object { "<th>$_</th>" }) -join "" + "</tr>"

foreach ($row in $report) {
    $stateClass = switch ($row.DeploymentState) {
        "success"     { "success" }
        "failure"     { "failure" }
        "inProgress"  { "inProgress" }
        default       { "" }
    }

    $htmlContent += "<tr class='$stateClass'>" + ($row.psobject.Properties.Value | ForEach-Object { "<td>$($_)</td>" }) -join "" + "</tr>"
}

$htmlContent += "</table></body></html>"

# UTF-8 mit BOM schreiben
[System.IO.File]::WriteAllText($htmlPath, ($htmlContent -join "`n"), [System.Text.Encoding]::UTF8)

# Öffnen
Invoke-Item $htmlPath
