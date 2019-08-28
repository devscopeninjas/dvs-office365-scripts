param (
    [string]$majorVersionsLimit = 100,
    [string]$minorVersionsLimit = 5, 
    [string]$tenantUrl = $(throw "-tenantUrl is required.")
)

$psCred = Get-Credential

Connect-PnPOnline -url $tenantUrl -Credential $psCred

$tenantSites = Get-PnPTenantSite
$currentSizeUsage = 0
$afterSizeUsage = 0
$exportInfo = @()

$tenantSites | ForEach-Object {

    Connect-PnPOnline -Url $_.Url -Credentials $psCred
    $allLists = Get-PnPList
    $siteUrl = $_.Url
    Write-Host $siteUrl "with " $_.StorageUsage "MB" -ForegroundColor Yellow

    $currentSizeUsage = $_.StorageUsage + $currentSizeUsage

        $allLists | where-object { 
        $_.AllowDeletion -ne $true -and $_.EnableVersioning -eq $true -and ($_.MajorWithMinorVersionsLimit -gt $minorVersionsLimit -or $_.MajorVersionLimit -gt $majorVersionsLimit)
        } | ForEach-Object {
            Write-Host $_.Title -ForegroundColor DarkYellow
            try{
                if($_.EnableMinorVersions -eq $true){
                    Set-PnpList -Identity $_.ID -MinorVersions $minorVersionsLimit -ErrorAction Stop
                    Set-PnpList -Identity $_.ID -MajorVersions $majorVersionsLimit -ErrorAction Stop
                }
                else
                {
                   Set-PnpList -Identity $_.ID -MajorVersions $majorVersionsLimit -ErrorAction Stop
                }
                Write-Host "Versioning has been set" -ForegroundColor Green                         
            }
            catch {
                Write-Host "It was not possible to set versioning -" $_.Exception.Message -ForegroundColor Red
            }
        }

    $afterSizeUsage = $_.StorageUsage + $afterSizeUsage

    $exportInfo += New-Object -TypeName PSObject -Property @{            
        SiteCollection = $siteUrl              
        InitialStorageUsage = $currentSizeUsage                 
        FinalStorageUsage = $afterSizeUsage
    }
}

Write-Host "Tenant had " $currentSizeUsage "MB" -ForegroundColor DarkCyan
Write-Host "Tenant now has " $afterSizeUsage "MB"  -ForegroundColor DarkCyan

$exportInfo | export-csv -Path C:\Temp\cleanupResults.csv -NoTypeInformation