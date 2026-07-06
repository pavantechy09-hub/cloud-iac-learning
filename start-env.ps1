# AWS - Floci
$env:AWS_ENDPOINT_URL = "http://localhost:4566"
$env:AWS_ACCESS_KEY_ID = "test"
$env:AWS_SECRET_ACCESS_KEY = "test"
$env:AWS_DEFAULT_REGION = "us-east-1"

# Azure - floci-az
$env:AZURE_STORAGE_CONNECTION_STRING = "DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://localhost:4577/devstoreaccount1;QueueEndpoint=http://localhost:4577/devstoreaccount1;TableEndpoint=http://localhost:4577/devstoreaccount1;"
$env:AZURE_STORAGE_ACCOUNT = "devstoreaccount1"
$env:AZURE_STORAGE_KEY = "Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw=="

# PATH
$env:PATH += ";C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\lib\terraform\tools"
$env:PATH += ";C:\Users\golip\AppData\Local\floci\bin"

Write-Host "Environment ready - AWS + Azure" -ForegroundColor Green
floci start
floci az start