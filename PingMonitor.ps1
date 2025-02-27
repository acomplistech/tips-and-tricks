###############################################################################
# Script Name:  PingMonitor.ps1
# Description:  Prompts user for IP & log file path, pings repeatedly,
#               logs dropped pings, logs consecutive loss periods,
#               logs any ping replies > 100 ms as an error,
#               logs script startup info (including the IP),
#               and logs script stop time upon termination.
###############################################################################

# Prompt for IP address/hostname
$Target = Read-Host "Enter the IP or hostname to ping"

# Prompt for log file path
$LogFile = Read-Host "Enter the full file path for the log (e.g. C:\ping_log.txt)"

# Record the script start time
$scriptStartTime = Get-Date

Write-Host "Monitoring pings to $Target. Logging to $LogFile."
Write-Host "Press Ctrl + C to stop."

# Log the script startup info: "Starting pings to [IP] - [date/time]"
Add-Content -Path $LogFile -Value "Starting pings to $Target - $($scriptStartTime.ToString())"
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

            # If the roundtrip time is greater than 100 ms, log as an error
            if ($replyTime -gt 100) {
                $warnTime = Get-Date
                LogMessage("$($warnTime): ERROR - High ping of $replyTime ms to $Target.")
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
