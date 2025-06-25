# Verbindung zu Microsoft Graph
Connect-MgGraph -Scopes "DeviceManagementServiceConfig.Read.All", "DeviceManagementManagedDevices.Read.All"

# Autopilot-Geräte abrufen
$devices = @()
$uri = "/beta/deviceManagement/windowsAutopilotDeviceIdentities"
do {
    $response = Invoke-MgGraphRequest -Method GET -Uri $uri
    $devices += $response.value
    $uri = $response.'@odata.nextLink'
} while ($uri)

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

# Daten zusammenführen
$report = foreach ($device in $devices) {
    $profile = $profiles | Where-Object { $_.id -eq $device.deploymentProfileId }
    $event   = $events   | Where-Object { $_.deviceSerialNumber -eq $device.serialNumber }

    [PSCustomObject]@{
        DeviceName          = $device.displayName
        SerialNumber        = $device.serialNumber
        UserPrincipalName   = $device.addressableUserName
        GroupTag            = $device.groupTag
        DeploymentProfile   = $profile.displayName
        DeploymentStatus    = $device.deploymentProfileAssignmentStatus
        AssignmentDate      = $device.deploymentProfileAssignedDateTime
        Manufacturer        = $device.manufacturer
        Model               = $device.model
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

# HTML-Tabelle mit CSS-Klassen je nach DeploymentState
$htmlContent = @()
$htmlContent += "<html><head><meta charset='UTF-8'><title>Autopilot Deployment Report</title>$style</head><body>"
$htmlContent += "<h2>Autopilot Deployment Uebersicht</h2>"
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
$htmlContent -join "`n" | Out-File -Encoding UTF8 -FilePath $htmlPath

# Öffnen
Invoke-Item $htmlPath
