param(
    [String]$sourceStorageAccount,
    [String]$targetStorageAccount,
    [String]$sourceFolder,
    [String]$targetFolder,
    [String]$sourceSasToken,
    [String]$targetSasToken,
    [String]$triggerPeriod,
    [Int32]$azCopyConcurrency
)

# Define variables
$SrcStgAccURI = "https://$sourceStorageAccount.blob.core.windows.net/"
$SrcBlobContainer = "$sourceFolder"
$SrcSASToken = "$sourceSasToken"
$SrcFullPath = "$($SrcStgAccURI)$($SrcBlobContainer)?$($SrcSASToken)"
$DstStgAccURI = "https://$targetStorageAccount.blob.core.windows.net/"

if ($triggerPeriod -eq 'daily')
{
   $DstFileShare = "daily/$(Get-Date -format yyyyMMdd)/$targetFolder"
}
else 
{
   $DstFileShare = "weekly/$(Get-Date -format yyyyMMdd)/$targetFolder"
}
$DstSASToken = "$targetSasToken"
$DstFullPath = "$($DstStgAccURI)$($DstFileShare)?$($DstSASToken)"
if ($triggerPeriod -eq 'daily')
{
   $IncludeAfterDateTimeISOString = (Get-Date).AddHours(-25).ToString("o") # One hour overlap with the previous daily run
}

Write-Output "Initializing backup process"
Write-Output "Source: $sourceFolder"
Write-Output "Target: $DstFileShare"
Write-Output "Trigger period: $triggerPeriod `n"
if ($triggerPeriod -eq 'daily')
{
   Write-Output ("Trigger period: {0}" -f $IncludeAfterDateTimeISOString)
}

# Test if AzCopy.exe exists in current folder
$WantFile = "azcopy.exe"
$AzCopyExists = Test-Path $WantFile
Write-Output ("AzCopy exists: {0}" -f $AzCopyExists)

# Download AzCopy if it doesn't exist
If ($AzCopyExists -eq $False)
{
   Write-Output "AzCopy not found. Downloading..."
   
   #Download AzCopy
   Invoke-WebRequest -Uri "https://aka.ms/downloadazcopy-v10-windows" -OutFile AzCopy.zip -UseBasicParsing

   #Expand Archive
   Write-Output "Expanding archive...`n"
   Expand-Archive ./AzCopy.zip ./AzCopy -Force

   # Copy AzCopy to current dir
   Get-ChildItem ./AzCopy/*/azcopy.exe | Copy-Item -Destination "./azcopy.exe"
}
else
{
   Write-Output "AzCopy found, skipping download.`n"
}

$env:AZCOPY_CONCURRENCY_VALUE = $azCopyConcurrency

# Run AzCopy from source blob to destination file share

Write-Host "Backing up storage account..."

$stopLoop = $false  
$retryCount = 0

do {
   Write-Host "Attempt: $retryCount"
   if ($triggerPeriod -eq 'daily')
   {
      Write-Host ("./azcopy.exe copy $SrcFullPath $DstFullPath --block-blob-tier Cool --recursive --overwrite=ifsourcenewer --log-level=NONE --include-after $IncludeAfterDateTimeISOString`n")
      ./azcopy.exe copy $SrcFullPath $DstFullPath --block-blob-tier Cool --recursive --overwrite=ifsourcenewer --log-level=NONE --include-after $IncludeAfterDateTimeISOString
   }
   else
   {
      Write-Host ("./azcopy.exe copy $SrcFullPath $DstFullPath --block-blob-tier Cool --recursive --overwrite=ifsourcenewer --log-level=NONE`n")
      ./azcopy.exe copy $SrcFullPath $DstFullPath --block-blob-tier Cool --recursive --overwrite=ifsourcenewer --log-level=NONE
   }

   if ($LASTEXITCODE -ne 0) {
      $retryCount++   
   }
   elseif ($LASTEXITCODE -eq 0){
      $stopLoop = $true
   }

   if ($retryCount -eq 3) {
      throw "Failed after $retryCount attempts"
   }
}
While ($stopLoop -eq $false)