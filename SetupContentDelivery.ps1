# The general idea with this script is that it should be mostly 'declarative'. In other words
# the choices you want to make about how your CD should be set up belong here. Detailed config-hacking
# grunge belongs in some more detailed script or other. 

# Port numbers: default for Live. For staging add 1000 

param(
[ValidateScript({Test-Path $_ -PathType 'Container'})] 
[string]$InstallerDirectoryPath='C:\Users\NetAdmin\Downloads\SDL Web 8.5',

[string]$ServicesDirectoryPath='C:\SDLServices', 
[string]$LoggingOutputPath='C:\SDLServiceLogs',
[string]$DeployerStorage='C:\SDLDeployerStorage',
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

$deployerConfig = (resolve-path ("Deployer\config\deployer-conf.xml"))
& "$ScriptPath\Merge-Deployer.ps1" -deployerConfig $deployerConfig `
                                             -dbAdapter 'mssql' `
                                             -dbHost $databaseServer `
                                             -dbPort 1433 `
                                             -dbName 'Tridion_Deployer_State' `
                                             -dbUser 'TridionBrokerUser' `
                                             -dbPassword 'Tridion1' `
                                             -binaryStoragePath "$DeployerStorage\Live\Binary" `
                                             -queuePath "$DeployerStorage\Live\Queue" `
                                             -licenseLocation $licenseLocation `
                                             -stripComments


& "$ScriptPath\Merge-Logback.ps1" -logbackFile (resolve-path ("Deployer\config\logback.xml")) `
                                  -logFolder "$LoggingOutputPath\Deployer"

@'
$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path
& $scriptPath\installService.ps1 --Name=SDLWebDeployerService --Description="SDL Web Deployer Service" `
                                 --DisplayName="SDL Web Deployer Service" --server.port=8084 
'@ > .\Deployer\bin\Invoke-InstallService.ps1

& .\Deployer\bin\Invoke-InstallService.ps1

# STAGING DEPLOYER 
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

$stagingDeployerConfig = (resolve-path ("StagingDeployer\config\deployer-conf.xml"))
& "$ScriptPath\Merge-Deployer.ps1" -deployerConfig $stagingDeployerConfig `
                                             -dbAdapter 'mssql' `
                                             -dbHost $databaseServer `
                                             -dbPort 1433 `
                                             -dbName 'Tridion_Deployer_State_Staging' `
                                             -dbUser 'TridionBrokerUser' `
                                             -dbPassword 'Tridion1' `
                                             -binaryStoragePath "$DeployerStorage\Staging\Binary" `
                                             -queuePath "$DeployerStorage\Staging\Queue" `
                                             -licenseLocation $licenseLocation `
                                             -stripComments

& "$ScriptPath\Merge-Logback.ps1" -logbackFile (resolve-path ("StagingDeployer\config\logback.xml")) `
                                  -logFolder "$LoggingOutputPath\StagingDeployer"

@'
$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path
& $scriptPath\installService.ps1 --Name=SDLWebStagingDeployerService --Description="SDL Web Staging Deployer Service" `
                                 --DisplayName="SDL Web Staging Deployer Service" --server.port=9084 
'@ > .\StagingDeployer\bin\Invoke-InstallService.ps1

& .\StagingDeployer\bin\Invoke-InstallService.ps1

# Live Content service (therefore not Session-Enabled)
Copy-Item -Recurse "$InstallerDirectoryPath\Content Delivery\roles\content\standalone" "Content"
$contentStorageConfig = (resolve-path ("Content\config\cd_storage_conf.xml"))
& "$ScriptPath\Merge-Storage.ps1" -storageConfig $contentStorageConfig `
                                             -dbType 'MSSQL' `
                                             -dbHost $databaseServer `
                                             -dbPort 1433 `
                                             -dbName 'Tridion_Broker' `
                                             -dbUser 'TridionBrokerUser' `
                                             -dbPassword 'Tridion1' `
                                             -licenseLocation $licenseLocation `
                                             -stripComments

& "$ScriptPath\Merge-RoleToConfigRepository.ps1" -storageConfig $discoveryStorageConfig `
                                                 -roleName 'ContentServiceCapability' `
                                                 -roleUrl 'http://localhost:8081/content.svc'

& "$ScriptPath\Merge-Logback.ps1" -logbackFile (resolve-path ("Content\config\logback.xml")) `
                                  -logFolder "$LoggingOutputPath\Content"

@'
$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path
& $scriptPath\installService.ps1 --Name=SDLWebContentService --Description="SDL Web Content Service" `
                                 --DisplayName="SDL Web Content Service" --server.port=8081 
'@ > .\Content\bin\Invoke-InstallService.ps1

& .\Content\bin\Invoke-InstallService.ps1

# Staging Content service (therefore Session-Enabled)
Copy-Item -Recurse "$InstallerDirectoryPath\Content Delivery\roles\session\service\standalone" "StagingContent"
$stagingContentStorageConfig = (resolve-path ("StagingContent\config\cd_storage_conf.xml"))

& "$ScriptPath\Merge-Storage.ps1" -storageConfig $stagingContentStorageConfig `
                                             -dbType 'MSSQL' `
                                             -dbHost $databaseServer `
                                             -dbPort 1433 `
                                             -dbName 'Tridion_Broker_Staging' `
                                             -dbUser 'TridionBrokerUser' `
                                             -dbPassword 'Tridion1' `
                                             -licenseLocation $licenseLocation `
                                             -stripComments

& "$ScriptPath\Merge-RoleToConfigRepository.ps1" -storageConfig $discoveryStorageConfig `
                                                 -roleName 'ContentServiceCapability' `
                                                 -roleUrl 'http://localhost:9081/content.svc'

& "$ScriptPath\Merge-Logback.ps1" -logbackFile (resolve-path ("StagingContent\config\logback.xml")) `
                                  -logFolder "$LoggingOutputPath\StagingContent"

@'
$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path
& $scriptPath\installService.ps1 --Name=SDLWebStagingContentService --Description="SDL Web Staging Content Service" `
                                 --DisplayName="SDL Web Staging Content Service" --server.port=9081 
'@ > .\StagingContent\bin\Invoke-InstallService.ps1

& .\StagingContent\bin\Invoke-InstallService.ps1

#Preview
Copy-Item -Recurse "$InstallerDirectoryPath\Content Delivery\roles\preview\standalone" "Preview"
$previewStorageConfig = (resolve-path ("Preview\config\cd_storage_conf.xml"))

# First fix up the normal storage
& "$ScriptPath\Merge-Storage.ps1" -storageConfig $previewStorageConfig `
                                             -dbType 'MSSQL' `
                                             -dbHost $databaseServer `
                                             -dbPort 1433 `
                                             -dbName 'Tridion_Broker_Staging' `
                                             -dbUser 'TridionBrokerUser' `
                                             -dbPassword 'Tridion1' `
                                             -licenseLocation $licenseLocation `
                                             -stripComments

# Then call the same script again to do the preview storage in the wrapper
& "$ScriptPath\Merge-Storage.ps1" -storageConfig $previewStorageConfig `
                                             -storageToUpdate "/Configuration/Global/Storages/Wrappers/Wrapper[@Name='SessionWrapper]/Storage[@Id='sessiondb']" `
                                             -dbType 'MSSQL' `
                                             -dbHost $databaseServer `
                                             -dbPort 1433 `
                                             -dbName 'Tridion_Preview' `
                                             -dbUser 'TridionBrokerUser' `
                                             -dbPassword 'Tridion1' 

& "$ScriptPath\Merge-RoleToConfigRepository.ps1" -storageConfig $discoveryStorageConfig `
                                                 -roleName 'PreviewWebServiceCapability' `
                                                 -roleUrl 'http://localhost:8083/ws/preview.svc'

& "$ScriptPath\Merge-Logback.ps1" -logbackFile (resolve-path ("Preview\config\logback.xml")) `
                                  -logFolder "$LoggingOutputPath\Preview"

@'
$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path
& $scriptPath\installService.ps1 --Name=SDLWebSessionPreviewService --Description="SDL Web Session Preview Service" `
                                 --DisplayName="SDL Web Session Preview Service" --server.port=8083 
'@ > .\Preview\bin\Invoke-InstallService.ps1

& .\Preview\bin\Invoke-InstallService.ps1



