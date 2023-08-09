# Description: This script checks for the presence of a token file in a specified directory.

Param (
    [string[]]$TokenSelection = @('aws', 'azure', 'wireguard', 'msword-macro', 'pdf-acrobat-reader' )
)

# Note: Keep this section synchronized with CreateCanaryToken_remediation.ps1
$TokenOptions = @{
    'aws'                = @{
        TargetDirectory = "C:\aws"
        TokenType       = 'aws-id'
        TokenFilename   = 'credentials'
    }
    'azure'              = @{
        TargetDirectory = "C:\azure"
        TokenType       = 'azure-id'
        TokenFilename   = 'azure_cert.zip'
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

$AnyTokenPresent = $false

foreach ($token in $TokenSelection) {
    $TargetDirectory = $TokenOptions[$token].TargetDirectory
    $TokenFilename = $TokenOptions[$token].TokenFilename
    $OutputFileName = "$TargetDirectory\$TokenFilename"
    if (Test-Path $OutputFileName) {
        Write-Host -ForegroundColor Green "Token file $OutputFileName exists."
        $AnyTokenPresent = $true
        break
    }
}

if ($AnyTokenPresent) {
    Write-Host -ForegroundColor Green "At least one token is present ($OutputFileName)."
    exit 0
}
else {
    Write-Host -ForegroundColor Red "No tokens are present."
    exit 1
}
