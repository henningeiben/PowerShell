### CONFIG SECTION START
###

$adminUrl = Read-Host -Prompt "Enter SharePoint Tenant URL (eg. https://yourcompany.sharepoint.com)"

###
### CONFIG SECTION END

# load modules
#Import-Module Microsoft.Online.SharePoint.PowerShell
$0 = $myInvocation.MyCommand.Definition
$dp0 = [System.IO.Path]::GetDirectoryName($0)

# assume DLLs are in the same folder as the script
Add-Type -Path "$dp0\Microsoft.SharePoint.Client.Runtime.dll"
Add-Type -Path "$dp0\Microsoft.SharePoint.Client.dll"
Add-Type -Path "$dp0\Microsoft.SharePoint.Client.WorkflowServices.dll"

$cred = Get-Credential -Message "Enter SPO credentials"
$spoCred = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials ($cred.UserName, $cred.Password)

Connect-SPOService -Url $adminUrl -Credential $cred
$sites = Get-SPOSite -Limit ALL

function Execute-NintexAppFinder () {
    param(
        [Microsoft.SharePoint.Client.Web] $web = $(throw "Please provide a web-site"),
        [Microsoft.SharePoint.Client.ClientContext] $ctx = $(throw "Please provide context")
    )
    
    $ctx.Load($web)

    $addInInstances=[Microsoft.SharePoint.Client.AppCatalog]::GetAppInstances($ctx,$web)
    $ctx.Load($addInInstances)
    $ctx.ExecuteQuery()
    $webUrl = $web.Url

    $addInInstances | % {
        if ($_.ProductId -eq "353e0dc9-57f5-40da-ae3f-380cd5385ab9") {
            Write-Host "Found Nintex Forms for Office 365 on $webUrl; got to $($_.AppWebFullUrl)"
            Write-Host "... Client-ID: $($_.AppPrincipalId)"            
        }
        if ($_.ProductId -eq "5d3d5c89-3c4c-4b46-ac2c-86095ea300c7") {
            Write-Host "Found Nintex Workflow for Office 365 on $webUrl; got to $($_.AppWebFullUrl)"
            Write-Host "... Client-ID: $($_.AppPrincipalId)"
            # retrieving startpage, because it includes the correct app-version
            Get-WorkflowDefs -appPrincipalId $_.AppPrincipalId -web $web -ctx $ctx -startPageUrl $_.StartPage
        }
    }
}

function Get-WorkflowDefs () {
    param(
        [String] $appPrincipalId = $(throw "Please provide app principal"),
        [Microsoft.SharePoint.Client.Web]  $web = $(throw "Please provide a web-site"),
        [Microsoft.SharePoint.Client.ClientContext] $ctx = $(throw "Please provide context"),
        [String] $startPageUrl = $(throw "Please provide Start-Page URL of the app")
    )
    $clientId = "client_id=" + [System.Web.HttpUtility]::UrlEncode($appPrincipalId)

    $wfmgr = New-Object Microsoft.SharePoint.Client.WorkflowServices.WorkflowServicesManager($ctx, $web)
    $wfdpl = $wfmgr.GetWorkflowDeploymentService()
    $wfdefs = $wfdpl.EnumerateDefinitions($false)
    $ctx.Load($wfdefs)
    $ctx.Load($web)
    $ctx.ExecuteQuery()

    $webUrl = $web.Url

    $items = @()
    $wfdefs | % {
        $lauchUrl = $webUrl + "/_layouts/15/appredirect.aspx?"
        $lauchUrl += $clientId
        $lauchUrl += "&redirect_uri=" + [System.Web.HttpUtility]::UrlEncode($startPageUrl + "&ListId={" + $_.RestrictToScope + "}")

        # Skip SPD Workflow (no NWConfig-properties) as well as Nintex "internal/helper" Workflows"
        if (($_.Properties["NWConfig.Designer"] -ne $null) -and ($_.DisplayName -notlike 'Nintex*'))
        {
            $item = [pscustomobject] @{
                Name = $_.DisplayName
                Region = $_.Properties["NWConfig.Region"]
                Designer = $_.Properties["NWConfig.Designer"]
                Entitlement = $_.Properties["NWConfig.WorkflowEntitlementType"]

                Author = $_.Properties["AppAuthor"]
                LastModified = $_.Properties["ModifiedBy"]
                LastEditor = $_.Properties["SMLastModifiedDate"]

                Type = $_.RestrictToType
                ScopeId = $_.RestrictToScope
                Published = $_.Published

                Link = $lauchUrl
            }
        
            $items += $item
        }
    }

    $items | Export-Csv -Path "wfs.csv" -NoTypeInformation -Delimiter ";" -Append
}

function Process-SubWebs() {
    param (
        [Microsoft.SharePoint.Client.Web] $rootWeb = $(throw "Please provide a root web"),
        [Microsoft.SharePoint.Client.ClientContext] $ctx = $(throw "Please provide a context")
    )
    $webs = $rootWeb.Webs
    $ctx.Load($webs)
    $ctx.ExecuteQuery()

    $webs | % {
        Write-Progress -Activity "Analysing Site-Collections" -Status "Processing $siteColUrl" -PercentComplete ($i / $siteCount * 100) -Id 1 -CurrentOperation "Inspecting Web $($_.Title)"
        Execute-NintexAppFinder -web $_ -ctx $ctx
        Process-SubWebs -rootWeb $_ -ctx $ctx
    }
}

Remove-Item "wfs.csv" -ErrorAction Continue

$siteitems = @()
$i = 1
$siteCount = $sites.Count
$sites | % {
    $siteColUrl = $_.Url
    
    $siteitem = [pscustomobject] @{
        SiteUrl = $_.Url
        Title = $_.Title
    }
    
    Write-Host "Working on $siteColUrl"
    Write-Progress -Activity "Analysing Site-Collections" -Status "Processing $siteColUrl" -PercentComplete ($i / $siteCount * 100) -Id 1

    $ctx = New-Object Microsoft.SharePoint.Client.ClientContext($siteColUrl)
    $ctx.Credentials = $spoCred
    $rootWeb = $ctx.Web
    $currentUser = $rootWeb.CurrentUser

    $ctx.Load($rootWeb)
    $ctx.Load($currentUser)
    $ctx.ExecuteQuery()

    if ($currentUser.IsSiteAdmin) { # -or ($userName -eq $_.Owner)) {
        Execute-NintexAppFinder -web $rootWeb -ctx $ctx
        Process-SubWebs -rootWeb $rootWeb -ctx $ctx
        $siteitem | Add-Member -Type NoteProperty -Name Status -Value "Processed"
    } else {
        Write-Host "Not a site-admin for $siteColUrl"
        $siteitem | Add-Member -Type NoteProperty -Name Status -Value "Not an admin"
    }

    $siteitems += $siteitem
    $i++
}
$siteitems | Export-Csv -Path "sites.csv" -NoTypeInformation -Delimiter ";" -Append