# Description: Remediation Script to deploy a random Canary Token to a Windows device using the Canary Console API.

Param (
    [string]$Domain = '.canary.tools', 
    [string]$FactoryAuth = '', 
    [string]$FlockID = 'flock:', 
    # [string]$TokenSelection = 'aws' # Uncomment this line and comment the next line to select a specific token type.
    [string[]]$TokenSelection = @('aws', 'azure', 'wireguard', 'msword-macro', 'pdf-acrobat-reader' ) # Define all possible Types that will be randomly selected.
)

# ToDo Randomisieren
$TokenSelection = Get-Random -InputObject $TokenSelection # Randomly select a value

# Change the TargetDirectory to your liking.
# Note: Keep this section synchronized with CreateCanaryToken_detection.ps1
$TokenOptions = @{
    'aws'                = @{
        TargetDirectory = "C:\aws"
        TokenType       = 'aws-id'
        TokenFilename   = 'credentials'
    }
    'azure'              = @{
        TargetDirectory = "C:\azure"
        TokenType       = 'azure-id'
        TokenFilename   = 'azure_cert.zip' # You will also have to define the Cert File Name in the PostData section.
    }
    'wireguard'          = @{
        TargetDirectory = "C:\wireguard"
        TokenType       = 'wireguard'
        TokenFilename   = 'wireguard.conf'
    }
    'msword-macro'       = @{
        TargetDirectory = "C:\word"
        TokenType       = 'msword-macro'
        TokenFilename   = 'test.docm'
    }
    'pdf-acrobat-reader' = @{
        TargetDirectory = "C:\pdf"
        TokenType       = 'pdf-acrobat-reader'
        TokenFilename   = 'test.pdf'
    }
}

$TokenType = $TokenOptions[$TokenSelection].TokenType
$TokenFilename = $TokenOptions[$TokenSelection].TokenFilename
$TargetDirectory = $TokenOptions[$TokenSelection].TargetDirectory

# Force TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;

# Connect to API
$ApiBaseURL = '/api/v1'

Write-Host -ForegroundColor Green "Checking if parameters are present: ..."

if ([string]::IsNullOrEmpty($FactoryAuth) -or [string]::IsNullOrEmpty($TokenType) -or [string]::IsNullOrEmpty($FlockID)) {
    Write-Host -ForegroundColor Red "One or more required parameters are missing or empty. Please check your input."
    Exit
}
else {
    Write-Host -ForegroundColor Green "All required parameters are present."
}

Write-Host -ForegroundColor Green "[*] Checking if '$TargetDirectory' exists..."

# Creates the target directory if it does not exist
If (!(Test-Path $TargetDirectory)) {
    Write-Host -ForegroundColor Green "[*] '$TargetDirectory' doesn't exist, creating it ..."
    New-Item -ItemType Directory -Force -Verbose -ErrorAction Stop -Path "$TargetDirectory"
}
# Check whether token file already exists on the local machine
$OutputFileName = "$TargetDirectory\$TokenFilename"
Write-Host -ForegroundColor Green "[*] Dropping '$OutputFileName' ..."

If (Test-Path $OutputFileName) {
    Write-Host Skipping $OutputFileName, file already exists.
    Exit        
}

# Create token on Console
$TokenName = $OutputFileName
$PostData = @{
    factory_auth            = "$FactoryAuth"
    kind                    = "$TokenType"
    flock_id                = "$FlockID"
    memo                    = "$([System.Net.Dns]::GetHostName()) - $TokenName"
    azure_id_cert_file_name = "finance_az_prod.pem"
}
Write-Host -ForegroundColor Green "[*] Hitting API to create token ..."

# Error Handling and Retry Logic if the API call fails
$MaxRetryCount = 3
$RetryCount = 0
do {
    try {
        $RetryCount++
        # API call to create token
        $CreateResult = Invoke-RestMethod -Method Post -Uri "https://$Domain$ApiBaseURL/canarytoken/factory/create" -Body $PostData -ErrorAction Stop
        $Result = $CreateResult.result
        $RetryCount = $MaxRetryCount
    } 
    catch {
        if ($RetryCount -ge $MaxRetryCount) {
            Write-Host "Failed to hit API after $MaxRetryCount attempts. Exiting script."
            Exit
        }
        else {
            Write-Host "Failed to hit API. Attempt $RetryCount of $MaxRetryCount."
            Start-Sleep -Seconds (2 * $RetryCount) 
        }
    }
} while ($RetryCount -lt $MaxRetryCount)


If ($Result -ne 'success') {
    Write-Host -ForegroundColor Red "[X] Creation of $TokenName failed."
    Exit
}
Else {
    $TokenID = $($CreateResult).canarytoken.canarytoken
    Write-Host -ForegroundColor Green "[*] Token Created (ID: $TokenID)."
}

# Downloads token and places it in the destination folder.
Write-Host -ForegroundColor Green "[*] Downloading Token from Console..."
try {
    # API call to download token
    Invoke-RestMethod -Method Get -Uri "https://$Domain$ApiBaseURL/canarytoken/factory/download?factory_auth=$FactoryAuth&canarytoken=$TokenID" -OutFile "$OutputFileName"
}
catch {
    Write-Host -ForegroundColor Red "Failed to download token. Error: $_"
    Exit
}
Write-Host -ForegroundColor Green "[*] Token Successfully written to destination: '$OutputFileName'."