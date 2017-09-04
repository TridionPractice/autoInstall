param(
[ValidateScript({Test-Path $_ -PathType 'Container'})] 
[string]$InstallerDirectoryPath='C:\Users\NetAdmin\Downloads\SDL Web 8.5',

[string]$ServicesDirectoryPath='C:\SDLServices', 
[string]$LoggingOutputPath='C:\SDLServiceLogs',
[ValidateScript({Test-Path -PathType Leaf -Path $_})]
$licenseLocation='C:\SdlLicenses\cd_licenses.xml'

)

$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path
. "$scriptPath\Utilities.ps1"

if (-not (isAdministrator) ) {throw "There's a bad moon rising. Best to get admin rights!"}

#TODO - check the ports are available and not blocked by firewall (probably quite tricky)

# ValidateScript won't check the default value, so do it here
if (-not (Test-Path ($InstallerDirectoryPath + '\Content Delivery'))) {throw "That doesn't look like the installation directory: bailing...."}

if (-not (Test-path $ServicesDirectoryPath) ){
    $ServicesDirectory = New-Item -ItemType Directory -Path $ServicesDirectoryPath
}
else {
    $ServicesDirectory = Get-Item $ServicesDirectoryPath
}
set-location $ServicesDirectory

#Disco
Copy-Item -Recurse "C:\Users\NetAdmin\Downloads\SDL Web 8.5\Content Delivery\roles\discovery\standalone" "Discovery"
& "$ScriptPath\Merge-DiscoveryStorage.ps1" -discoveryStorageConfig (resolve-path ("Discovery\config\cd_storage_conf.xml")) `
                                             -discoveryHost 'localhost' `
                                             -dbType 'MSSQL' `
                                             -dbHost 'sdlcd' `
                                             -dbPort 1433 `
                                             -dbName 'Tridion_Discovery' `
                                             -dbUser 'TridionBrokerUser' `
                                             -dbPassword 'Tridion1' `
                                             -licenseLocation $licenseLocation `
                                             -stripComments

& "$ScriptPath\Merge-Logback.ps1" -logbackFile (resolve-path ("Discovery\config\logback.xml")) `
                                  -logFolder "$LoggingOutputPath\Discovery"

#TODO - read Rick's comment about non-standard ports here https://tridion.stackexchange.com/a/14431/129
@'
$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path
& $scriptPath\installService.ps1 --Name=SDLWebDiscoveryService --Description="SDL Web Discovery Service" `
                                 --DisplayName="SDL Web Discovery Service" --server.port=8082 
'@ > .\Discovery\bin\Invoke-InstallService.ps1

& .\Discovery\bin\Invoke-InstallService.ps1


Copy-Item -Recurse "C:\Users\NetAdmin\Downloads\SDL Web 8.5\Content Delivery\roles\discovery\standalone" "StagingDiscovery"
& "$ScriptPath\Merge-DiscoveryStorage.ps1" -discoveryStorageConfig (resolve-path ("StagingDiscovery/config/cd_storage_conf.xml")) `
                                             -discoveryHost 'localhost' `
                                             -dbType 'MSSQL' `
                                             -dbHost 'sdlcd' `
                                             -dbPort 1433 `
                                             -dbName 'Tridion_Discovery_Staging' `
                                             -dbUser 'TridionBrokerUser' `
                                             -dbPassword 'Tridion1' `
                                             -licenseLocation $licenseLocation `
                                             -stripComments

& "$ScriptPath\Merge-Logback.ps1" -logbackFile (resolve-path ("StagingDiscovery\config\logback.xml")) `
                                  -logFolder "$LoggingOutputPath\StagingDiscovery"


@'
$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path
& $scriptPath\installService.ps1 --Name=SDLWebStagingDiscoveryService --Description="SDL Web Staging Discovery Service" `
                                 --DisplayName="SDL Web Staging Discovery Service" --server.port=9082 
'@ > .\StagingDiscovery\bin\Invoke-InstallService.ps1

& .\StagingDiscovery\bin\Invoke-InstallService.ps1




