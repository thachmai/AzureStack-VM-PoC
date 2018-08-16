function DownloadWithRetry([string] $Uri, [string] $DownloadLocation, [int] $Retries = 5, [int]$RetryInterval = 10)
{
    while($true)
    {
        try
        {
            Start-BitsTransfer -Source $Uri -Destination $DownloadLocation -DisplayName $Uri
            break
        }
        catch
        {
            $exceptionMessage = $_.Exception.Message
            Write-Host "Failed to download '$Uri': $exceptionMessage"
            if ($retries -gt 0) {
                $retries--
                Write-Host "Waiting $RetryInterval seconds before retrying. Retries left: $Retries"
                Clear-DnsClientCache
                Start-Sleep -Seconds $RetryInterval
 
            }
            else
            {
                $exception = $_.Exception
                throw $exception
            }
        }
    }
}
function Disable-InternetExplorerESC {
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
}

function Write-Log ([string]$Message, [string]$LogFilePath, [switch]$Overwrite)
{
    $t = Get-Date -Format "yyyy-MM-dd hh:mm:ss"
    Write-Verbose "$Message - $t" -Verbose
    if ($Overwrite)
    {
        Set-Content -Path $LogFilePath -Value "$Message - $t"
    }
    else
    {
        Add-Content -Path $LogFilePath -Value "$Message - $t"
    }
}

function findLatestASDK ($asdkURIRoot, [string[]]$asdkFileList, $count = 8)
{
    $versionArray = @()
    $version = Get-Date -Format "yyMM"
    for ($i = 0; $i -lt $count; $i++)
    {
        $version = (Get-Date (Get-Date).AddMonths(-$i) -Format "yyMM")
        if ($version -eq 1804)
        {
            $version = "$version" + "-1"
        }
        try
        {
            $r = (Invoke-WebRequest -Uri $($asdkURIRoot + $version + '/' + $asdkFileList[0]) -UseBasicParsing -DisableKeepAlive -Method Head -ErrorAction SilentlyContinue).StatusCode
            if ($r -eq 200)
            {
                Write-Verbose "ASDK$version is available." -Verbose
                $versionArray += $version
            }
        }
        catch [System.Net.WebException],[System.Exception]
        {
            Write-Verbose "ASDK$version cannot be located." -Verbose
            $r = 404
        }
    }
    return $versionArray
}

function testASDKFilesPresence ([string]$asdkURIRoot, $version, [array]$asdkfileList) 
{
    $Uris = @()

    foreach ($file in $asdkfileList)
    {
        try
        {
            $Uri = ($asdkURIRoot + $version + '/' + $file)
            $r = (Invoke-WebRequest -Uri $Uri -UseBasicParsing -DisableKeepAlive -Method head -ErrorAction SilentlyContinue).statuscode
            if ($r -eq 200)
            {
                $Uris += $Uri
                Write-Verbose $Uri -Verbose
            }    
        }
        catch
        {
            $r = 404
        }
    }
    return $Uris
}

function ASDKDownloader
{
    param
    (
        [switch]
        $Interactive,

        [System.Collections.ArrayList]
        $AsdkFileList,

        [string]
        $ASDKURIRoot = "https://azurestack.azureedge.net/asdk",

        [string]
        $Version,

        [string]
        $Destination = "D:\"
    )
    if (!($AsdkFileList))
    {
        $AsdkFileList = @("AzureStackDevelopmentKit.exe")
        1..10 | ForEach-Object {$AsdkFileList += "AzureStackDevelopmentKit-$_" + ".bin"}
    }

    if ($Interactive)
    {
        $versionArray = findLatestASDK -asdkURIRoot $ASDKURIRoot -asdkFileList $AsdkFileList
        
        Write-Verbose "Version is now: $Version" -Verbose
        Write-Verbose "VersionArray is now: $versionArray" -Verbose
        if ($Version -eq $null -or $Version -eq "")
        {
            do
            {
                Clear-Host
                $i = 1
                Write-Host ""
                foreach ($v in $versionArray)
                {
                    Write-Host "$($i)`. ASDK version: $v"
                    $i++
                }
                Write-Host ""
                Write-Host -ForegroundColor Yellow -BackgroundColor DarkGray -NoNewline  -Object "Unless it is instructed, select only latest tested ASDK Version "
                Write-Host -ForegroundColor Green -BackgroundColor DarkGray -Object $gitbranchconfig.lastversiontested
                Write-Host ""
                $s = (Read-Host -Prompt "Select ASDK version to install")
                if ($s -match "\d")
                {
                    $s = $s - 1
                }
            }
            until ($versionArray[$s] -in $versionArray)
            $version = $versionArray[$s]
        }
    }
        $downloadList = testASDKFilesPresence -asdkURIRoot $ASDKURIRoot -version $Version -asdkfileList $AsdkFileList
        return $downloadList
        $downloadList | ForEach-Object {Start-BitsTransfer -Source $_ -DisplayName $_ -Destination $Destination}      
}

function ExtractASDK ($Source, $Destination)
{

}