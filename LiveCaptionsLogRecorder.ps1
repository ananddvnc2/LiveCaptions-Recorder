Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$desktopPath = [Environment]::GetFolderPath("Desktop")
$folderName = "LiveCaptionsLogs"
$subfolderPath = "$desktopPath\$folderName"

if (-not (Test-Path $subfolderPath)) {
    New-Item -ItemType Directory -Path $subfolderPath | Out-Null
}

$dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$outFile = "$subfolderPath\$dateTime.txt"

function Get-CaptionsWindow {
    $desktop = [System.Windows.Automation.AutomationElement]::RootElement
    $condition = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::NameProperty, "Live Captions"
    )
    return $desktop.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
}

function Get-CaptionText($window) {
    $condition = [System.Windows.Automation.Condition]::TrueCondition
    $elements = $window.FindAll([System.Windows.Automation.TreeScope]::Descendants, $condition)
    $texts = @()
    foreach ($el in $elements) {
        $name = $el.Current.Name
        if ($name -and $name.Trim() -ne "" -and $name -ne "Live Captions") {
            $texts += $name.Trim()
        }
    }
    return ($texts | Sort-Object Length -Descending | Select-Object -First 1)
}

$lastSeen = ""      # what we saw last poll
$lastSaved = ""     # what we last wrote to file
$sessionLog = @()
$sessionLog += "=== Live Captions Session: $(Get-Date) ==="
$sessionLog += ""

Write-Host "======================================" -ForegroundColor Cyan
Write-Host " Live Captions Recorder Started" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Saving to: $outFile" -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop.`n" -ForegroundColor Yellow

try {
    while ($true) {
        $win = Get-CaptionsWindow

        if ($null -eq $win) {
            Write-Host "Waiting for Live Captions window..." -ForegroundColor Yellow
            Start-Sleep -Seconds 3
            continue
        }

        $text = Get-CaptionText $win

        if ($text -and $text.Length -gt 5) {
            if ($text -eq $lastSeen -and $text -ne $lastSaved) {
                # Text stopped changing — sentence is complete, save it
                $timestamp = Get-Date -Format "HH:mm:ss"
                $line = "[$timestamp] $text"
                Write-Host $line -ForegroundColor Green
                $sessionLog += $line
                $sessionLog | Out-File -FilePath $outFile -Encoding UTF8
                $lastSaved = $text
            }
            $lastSeen = $text
        }

        Start-Sleep -Milliseconds 800
    }
}
finally {
    Write-Host "`nFile saved to: $outFile" -ForegroundColor Green
}