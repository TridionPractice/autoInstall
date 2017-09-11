param(
[ValidateScript({Test-Path $_ -PathType 'Container'})] 
[string]$InstallerDirectoryPath='C:\Users\NetAdmin\Downloads\SDL Web 8.5',

[string]$ServicesDirectoryPath='C:\SDLServices', 
[string]$LoggingOutputPath='C:\SDLServiceLogs',
[ValidateScript({Test-Path -PathType Leaf -Path $_})]
$licenseLocation='C:\SdlLicenses\cd_licenses.xml', 
$databaseServer='localhost'

)

$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path
. "$scriptPath\Utilities.ps1"

if (-not (isAdministrator) ) {throw "There's a bad moon rising. Best to get admin rights!"}

# ValidateScript won't check the default value, so do it here
if (-not (Test-Path ($InstallerDirectoryPath + '\Content Delivery'))) {throw "That doesn't look like the installation directory: bailing...."}

if (-not (Test-path $ServicesDirectoryPath) ){
    $ServicesDirectory = New-Item -ItemType Directory -Path $ServicesDirectoryPath
}
else {
    $ServicesDirectory = Get-Item $ServicesDirectoryPath
}
set-location $ServicesDirectory

#  DISCOVERY SERVICE - LIVE
Copy-Item -Recurse "$InstallerDirectoryPath\Content Delivery\roles\discovery\standalone" "Discovery"
$discoveryStorageConfig = (resolve-path ("Discovery\config\cd_storage_conf.xml"))
& "$ScriptPath\Merge-Storage.ps1" -storageConfig $discoveryStorageConfig `
                                             -dbType 'MSSQL' `
                                             -dbHost $databaseServer `
                                             -dbPort 1433 `
                                             -dbName 'Tridion_Discovery' `
                                             -dbUser 'TridionBrokerUser' `
                                             -dbPassword 'Tridion1' `
                                             -licenseLocation $licenseLocation `
                                             -stripComments

& "$ScriptPath\Merge-ConfigRepository.ps1" -storageConfig $discoveryStorageConfig `
                                             -discoveryHost 'localhost' 


& "$ScriptPath\Merge-Logback.ps1" -logbackFile (resolve-path ("Discovery\config\logback.xml")) `
                                  -logFolder "$LoggingOutputPath\Discovery"

@'
$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path
& $scriptPath\installService.ps1 --Name=SDLWebDiscoveryService --Description="SDL Web Discovery Service" `
                                 --DisplayName="SDL Web Discovery Service" --server.port=8082 
'@ > .\Discovery\bin\Invoke-InstallService.ps1

& .\Discovery\bin\Invoke-InstallService.ps1

#  DISCOVERY SERVICE - STAGING 
Copy-Item -Recurse "$InstallerDirectoryPath\Content Delivery\roles\discovery\standalone" "StagingDiscovery"
$stagingDiscoveryStorageConfig = (resolve-path ("StagingDiscovery\config\cd_storage_conf.xml"))
& "$ScriptPath\Merge-Storage.ps1" -storageConfig $stagingDiscoveryStorageConfig `
                                             -dbType 'MSSQL' `
                                             -dbHost $databaseServer `
                                             -dbPort 1433 `
                                             -dbName 'Tridion_Discovery_Staging' `
                                             -dbUser 'TridionBrokerUser' `
                                             -dbPassword 'Tridion1' `
                                             -licenseLocation $licenseLocation `
                                             -stripComments

& "$ScriptPath\Merge-ConfigRepository.ps1" -storageConfig $stagingDiscoveryStorageConfig `
                                             -discoveryHost 'localhost' `
                                             -discoveryPort 9082 `

& "$ScriptPath\Merge-Logback.ps1" -logbackFile (resolve-path ("StagingDiscovery\config\logback.xml")) `
                                  -logFolder "$LoggingOutputPath\StagingDiscovery"

@'
$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path
& $scriptPath\installService.ps1 --Name=SDLWebStagingDiscoveryService --Description="SDL Web Staging Discovery Service" `
                                 --DisplayName="SDL Web Staging Discovery Service" --server.port=9082 
'@ > .\StagingDiscovery\bin\Invoke-InstallService.ps1

& .\StagingDiscovery\bin\Invoke-InstallService.ps1

#  DEPLOYER SERVICES 
    # Either deployer-combined or deployer/deployer-worker
    # We'll start with deployer-combined

Copy-Item -Recurse "$InstallerDirectoryPath\Content Delivery\roles\deployer\deployer-combined\standalone" "Deployer"
$deployerStorageConfig = (resolve-path ("Deployer\config\cd_storage_conf.xml"))
& "$ScriptPath\Merge-Storage.ps1" -storageConfig $deployerStorageConfig `
                                             -dbType 'MSSQL' `
                                             -dbHost $databaseServer `
                                             -dbPort 1433 `
                                             -dbName 'Tridion_Broker' `
                                             -dbUser 'TridionBrokerUser' `
                                             -dbPassword 'Tridion1' `
                                             -licenseLocation $licenseLocation `
                                             -stripComments

Copy-Item -Recurse "$InstallerDirectoryPath\Content Delivery\roles\deployer\deployer-combined\standalone" "StagingDeployer"
$stagingDeployerStorageConfig = (resolve-path ("StagingDeployer\config\cd_storage_conf.xml"))
& "$ScriptPath\Merge-Storage.ps1" -storageConfig $stagingDeployerStorageConfig `
                                             -dbType 'MSSQL' `
                                             -dbHost $databaseServer `
                                             -dbPort 1433 `
                                             -dbName 'Tridion_Broker_Staging' `
                                             -dbUser 'TridionBrokerUser' `
                                             -dbPassword 'Tridion1' `
                                             -licenseLocation $licenseLocation `
                                             -stripComments
