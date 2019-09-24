param (
    [string]$majorVersionsLimit = 100,
    [string]$minorVersionsLimit = 5, 
    [string]$tenantUrl = $(throw "-tenantUrl is required.")
)

$psCred = Get-Credential

#$psCred = New-Object System.Management.Automation.PSCredential -ArgumentList ($username, $password)
Connect-PnPOnline -url $tenantUrl -Credential $psCred

$tenantSites = Get-PnPTenantSite -IncludeOneDriveSites
$currentSizeUsage = 0
$afterSizeUsage = 0
$exportInfo = @()

function SetVersioningOnItems($ctx, $items)
{
    $items | ForEach-Object {

        try{
            #Get File Versions
            $File = $_.File
            $Versions = $File.Versions

            $ctx.Load($File)
            $ctx.Load($Versions)
            $ctx.ExecuteQuery()
 
            Write-host -f Yellow "--- Scanning File:"$File.Name
            $VersionsCount = $Versions.Count
            $VersionsToDelete = $VersionsCount - $minorVersionsLimit
            If($VersionsToDelete -gt 0)
            {
                write-host -f Cyan "`t --- Total Number of Versions of the File:" $VersionsCount
                #Delete versions
                For($i=0; $i -lt $VersionsToDelete; $i++)
                {
                    write-host -f Cyan "`t --- Deleting Version:" $Versions[0].VersionLabel
                    $Versions[0].DeleteObject()
                }
                $ctx.ExecuteQuery()
                Write-Host -f Green "`t --- Version History is cleaned for the File:"$File.Name
            }
        }
        catch { }
    }
}

function SetVersioningOnLists($list, $ctx)
{
    $items = Get-PnPListItem -List $list.Id -Query "<View Scope='RecursiveAll'><Query><Where><Eq><FieldRef Name='FSObjType'/><Value Type='Integer'>0</Value></Eq></Where></Query></View>"
    SetVersioningOnItems $ctx $items

    if($list.EnableMinorVersions -eq $true){
        Set-PnpList -Identity $list.ID -MinorVersions $minorVersionsLimit -ErrorAction Stop
        Set-PnpList -Identity $list.ID -MajorVersions $majorVersionsLimit -ErrorAction Stop
    }
    else
    {
        Set-PnpList -Identity $list.ID -MajorVersions $majorVersionsLimit -ErrorAction Stop
    }
    Write-Host "-- Versioning on list has been set" -ForegroundColor Green
}

$tenantSites | ForEach-Object {

    Connect-PnPOnline -Url $_.Url -Credentials $psCred
    $allLists = Get-PnPList
    $siteUrl = $_.Url
    Write-Host "-" $siteUrl "with " $_.StorageUsage "MB" -ForegroundColor Yellow

    $ctx= Get-PnPContext

    $initialSize = $_.StorageUsage
    $currentSizeUsage = $initialSize + $currentSizeUsage

    $exportInfo += New-Object -TypeName PSObject -Property @{            
        SiteCollection = $siteUrl              
        InitialStorageUsage =  $initialSize             
        FinalStorageUsage = 0
    }


    $allLists | where-object { 
    $_.EnableVersioning -eq $true -and ($_.MajorWithMinorVersionsLimit -gt $minorVersionsLimit -or $_.MajorVersionLimit -gt $majorVersionsLimit)
    } | ForEach-Object {
        Write-Host "--" $_.Title -ForegroundColor DarkYellow 
        try{
            SetVersioningOnLists $_ $ctx                          
        }
        catch {
            Write-Host "-- It was not possible to set versioning -" $_.Exception.Message -ForegroundColor Red
        }
    }

    Disconnect-PnPOnline
}
## Workaround to get latest storage quota ###Connect-PnPOnline -url $tenantUrl -Credential $psCredGet-PnPTenantSite -IncludeOneDriveSites | ForEach-Object {
    $currentUrl = $_.Ur
    $finalStorageUsage = $_.StorageUsage
    $afterSizeUsage = $_.StorageUsage + $afterSizeUsage

    $exportInfo | where-object { $_.SiteCollection -eq $_.currentUrl } | select-object{ $_.FinalStorageUsage = $finalStorageUsage }
}


Write-Host "## Tenant had " $currentSizeUsage "MB" -ForegroundColor DarkCyan
Write-Host "## Tenant now has " $afterSizeUsage "MB"  -ForegroundColor DarkCyan

$exportInfo | export-csv -Path C:\Temp\cleanupResults.csv -NoTypeInformation