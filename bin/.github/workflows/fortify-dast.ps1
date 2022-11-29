$url_scdast_api = $args[0]
$cicdToken = $args[1]
$user  = $args[2]
$password  = $args[3]
$ErrorActionPreference = "Stop"

$StopWatch = New-Object -TypeName System.Diagnostics.Stopwatch
$StopWatch.Start()

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("accept", "text/plain")
$headers.Add("Content-Type", "application/json-patch+json")

$body = "{`"username`":`"" + $user + "`",`"password`":`"" + $password + "`"}"

$tokenurl = $url_scdast_api + '/api/v2/auth'

$responsetoken = Invoke-RestMethod $tokenurl -Method 'POST' -Headers $headers -Body $body

$login_token = $responsetoken.token

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "$login_token")
$headers.Add("Content-Type", "application/json")

$body = "{
`n    `"cicdToken`": `"$cicdToken`"
`n}"

$responseurl = $url_scdast_api + '/api/scans/start-scan-cicd'
$response = Invoke-RestMethod $responseurl -Method 'POST' -Headers $headers -Body $body
#$response | ConvertTo-Json

$scanId = $response.id

#$response | ConvertTo-Json

Write-Host -ForegroundColor Green ("Scan started succesfully with Scan Id: " + $scanId)

#2. Get the current Status of the Scan
$StatusUrl = $url_scdast_api + '/api/v2/scans/' + $scanId + '/scan-summary'
$ScanCompleted = "5"
$ScanStopped = "3"
$ScanInterrupted = "6"
$ScanFailed = "10"

#Wait until the ScanStatus changed to ScanCompleted, ScanStopped or ScanInterrupted
do{
    $status = Invoke-RestMethod $StatusUrl -Method 'GET' -Headers $headers
    $ScanRequests = "Requests: " + $status.item.requestCount
    $ScanFindings =  "Critical: " + $status.item.criticalCount + ", High: " + $status.item.highCount + ", Medium: " + $status.item.mediumCount + ", Low: " + $status.item.lowCount
    $CreatedScanDate =  $status.item.createdDateTime
    $ScanStatus =  $status.item.scanStatusType

    switch ($ScanStatus){
    1 { $result = 'Queued'     }
    2 { $result = 'Pending'    }
    3 { $result = 'Paused'     }
    4 { $result = 'Running'    }
    5 { $result = 'Complete'   }
    6 { $result = 'Interrupted'}
    7 { $result = 'Unknown'    }
    }

    if($ScanStatusNew -ne $ScanStatus){
        Write-Host ("Created: " + $CreatedScanDate + " - Duration: " + $StopWatch.Elapsed.ToString() + " - Status: " + $result) -ForegroundColor Yellow
    }
    $ScanStatusNew = $ScanStatus
    if($result -eq "Running"){
        Write-Host $ScanRequests $ScanFindings
    }
    Start-Sleep -Seconds 10
}
while(($ScanStatus -ne $ScanCompleted) -and ($ScanStatus -ne $ScanStopped) -and ($ScanStatus -ne $ScanInterrupted) -and ($ScanStatus -ne $ScanFailed))
 
if ($ScanStatus -eq $ScanCompleted){
    Write-Host -ForegroundColor Green ("Scan completed!") `n

    #3. Export the scan to the FPR format
    $fprurl = $url_scdast_api + '/api/v2/scans/' + $scanId + '/download-fpr'
    $path = 'Scan_' + $scanId + '_FPR.fpr'

    Write-Host ("Downloading the result file (fpr)...")
    Invoke-RestMethod -Method GET -OutFile $path -uri "$fprurl" -Headers $headers
    Write-Host -ForegroundColor Green ("Result file (fpr) download done!") `n

    #4. Upload the Results to SSC

    $headers.Add("Accept", "application/json, text/plain, */*")
    $headers.Add("X-Requested-With", "XMLHttpRequest")
    Write-Host ("Publishing results to SSC...")
    $PublishUrl = $url_scdast_api + '/api/v2/scans/' + $scanId + '/scan-action'
    $response = Invoke-RestMethod $PublishUrl -Method 'POST' -Headers $headers -Body "{`"ScanActionType`":5}"
    Write-Host -ForegroundColor Green ("Finished! Scan Results are now availible in the Software Security Center!")
     
 }
else {
    Write-Host -ForegroundColor Red ("Error occured after Scan was finished!")
}
