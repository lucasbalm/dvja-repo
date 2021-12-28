$url_scdast_api = $args[0]
$cicdToken = $args[1]

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "FORTIFYTOKEN MzgyZTg1ZTUtOTI5ZC00MjQ5LWI3YzEtOTBmM2M5NDQ3YTU3")
$headers.Add("Content-Type", "application/json")

$body = "{
`n    `"cicdToken`": `"$cicdToken`"
`n}"

$response = Invoke-RestMethod "$url_scdast_api/api/scans/start-scan-cicd" -Method 'POST' -Headers $headers -Body $body
$response | ConvertTo-Json
