###############################################################################
# Script Name:  PingMonitor.ps1
# Description:  Prompts user for:
#               1) IP/hostname to ping
#               2) Log file path
#               3) (Optional) High ping threshold in ms (default 100 ms)
#               4) A user comment which is logged and displayed
#
#               Continuously pings, logs dropped pings,
#               logs consecutive loss periods, logs any reply times above the
#               threshold as an error, logs script startup info (incl. comment),
#               and logs the script stop time upon termination.
###############################################################################

# Prompt for IP address/hostname
$Target = Read-Host "Enter the IP or hostname to ping"

# Prompt for log file path
$LogFile = Read-Host "Enter the full file path for the log (e.g. C:\ping_log.txt)"

# Prompt for high-ping threshold (default: 100 ms)
$HighPingThreshold = Read-Host "Enter the max acceptable round trip time in ms (Press Enter for default: 100)"
if ([string]::IsNullOrWhiteSpace($HighPingThreshold)) {
    $HighPingThreshold = 100
}
else {
    [int]$HighPingThreshold
}

# Prompt for user comment
$UserComment = Read-Host "Enter any notes or comment to log"

# Record the script start time
$scriptStartTime = Get-Date

# Display summary of script startup
Write-Host "Monitoring pings to: $Target"
Write-Host "Logging to: $LogFile"
Write-Host "High-ping threshold: $HighPingThreshold ms"
Write-Host "Comment: $UserComment"
Write-Host "Press Ctrl + C to stop."

# Log the script startup info
Add-Content -Path $LogFile -Value "=================================================="
Add-Content -Path $LogFile -Value "Starting pings to $Target - $($scriptStartTime.ToString())"
Add-Content -Path $LogFile -Value "High-ping threshold: $HighPingThreshold ms"
Add-Content -Path $LogFile -Value "User comment: $UserComment"
Add-Content -Path $LogFile -Value "=================================================="
Add-Content -Path $LogFile -Value ""

# Variables to track loss periods
$inLossPeriod = $false
$lossStart    = $null
$lossCount    = 0

# Helper function to log messages to file and console
function LogMessage([string]$message) {
    $message | Out-File -FilePath $LogFile -Append
    Write-Host $message
}

try {
    while ($true) {
        # Attempt a single ping. Use -ErrorAction SilentlyContinue so it doesn't throw on failures.
        $PingResponse = Test-Connection -ComputerName $Target -Count 1 -ErrorAction SilentlyContinue

        if (-not $PingResponse) {
            # No response => ping dropped
            $dropTime = Get-Date
            LogMessage("$($dropTime): Ping to $Target DROPPED.")

            # Check if we're already in a loss period
            if (-not $inLossPeriod) {
                # Start of a new loss period
                $inLossPeriod = $true
                $lossStart = $dropTime
                $lossCount = 1
                LogMessage("$($dropTime): --- LOSS PERIOD STARTED ---")
            }
            else {
                # Already in a loss period; just increment the count
                $lossCount++
            }
        }
        else {
            # We have a ping reply; check RoundtripTime
            $replyTime = $PingResponse[0].ResponseTime

            # If the roundtrip time is greater than the threshold, log as an error
            if ($replyTime -gt $HighPingThreshold) {
                $warnTime = Get-Date
                LogMessage("$($warnTime): ERROR - High ping of $replyTime ms to $Target (Threshold: $HighPingThreshold ms).")
            }

            # If we were in a loss period, end it
            if ($inLossPeriod) {
                $lossEnd = Get-Date
                $duration = $lossEnd - $lossStart

                LogMessage("$($lossEnd): +++ LOSS PERIOD ENDED +++")
                LogMessage("    Duration (seconds): {0}" -f $duration.TotalSeconds)
                LogMessage("    Total pings lost   : $lossCount")
                LogMessage("")

                # Reset loss period tracking
                $inLossPeriod = $false
                $lossStart = $null
                $lossCount = 0
            }
        }

        # Adjust the delay to your preference
        Start-Sleep -Seconds 1
    }
}
finally {
    # Log script stop time
    $stopTime = Get-Date
    Add-Content -Path $LogFile -Value "Script stopped at: $($stopTime.ToString())"
    Write-Host "Script stopped at: $stopTime"
}
