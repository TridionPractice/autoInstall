﻿# The general idea with this script is that it should be mostly 'declarative'. In other words
# the choices you want to make about how your CD should be set up belong here. Detailed config-hacking
# grunge belongs in some more detailed script or other. 

# Port numbers: default for Live. For staging add 1000 

# TODO: Set up the DependsOn relationships
# REVIEW: Staging services are running with different names. The uninstallService.ps1 scripts /do/ look for serviceName.txt. Is that robust enough?

param(
[ValidateScript({Test-Path $_ -PathType 'Container'})] 
[string]$InstallerDirectoryPath='C:\Users\Administrator.WEB85\Downloads\SDL Web 8.5',
[ValidateScript({Test-Path $_ -PathType 'Container'})] 
[string]$DXAInstallerDirectoryPath='C:\Users\Administrator.WEB85\Downloads\SDL.DXA.Java.2.0.CTP.2',
[string]$ServicesDirectoryPath='C:\SDLServices', 
[string]$LoggingOutputPath='C:\SDLServiceLogs',
[string]$DeployerStorage='C:\SDLDeployerStorage',
[ValidateScript({Test-Path -PathType Leaf -Path $_})]
$licenseLocation='C:\SdlLicenses\cd_licenses.xml', 
$databaseServer='localhost',
[Parameter(Mandatory=$false, HelpMessage='The name clients will use to find the services')]
$domainName='sdlweb'

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
Copy-Item "$InstallerDirectoryPath\Content Delivery\roles\discovery\registration\discovery-registration.jar" "Discovery\config"
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
                                             -discoveryHost $domainName

& "$ScriptPath\Merge-RoleToConfigRepository.ps1" -storageConfig $discoveryStorageConfig `
                                                 -roleName 'TokenServiceCapability' `
                                                 -roleUrl "http://$domainName`:8082/token.svc"

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
Copy-Item "$InstallerDirectoryPath\Content Delivery\roles\discovery\registration\discovery-registration.jar" "StagingDiscovery\config"
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
                                             -discoveryHost $domainName `
                                             -discoveryPort 9082 `

& "$ScriptPath\Merge-RoleToConfigRepository.ps1" -storageConfig $stagingDiscoveryStorageConfig `
                                                 -roleName 'TokenServiceCapability' `
                                                 -roleUrl "http://$domainName`:9082/token.svc"

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


#      <Role Name="DeployerCapability" Url="${deployerurl:-http://localhost:8084/httpupload}">
#        <Property Name="encoding" Value="UTF-8" />
#      </Role>
& "$ScriptPath\Merge-RoleToConfigRepository.ps1" -storageConfig $discoveryStorageConfig `
                                                 -roleName 'DeployerCapability' `
                                                 -roleUrl "http://$($domainName):8084/httpupload" `
                                                 -roleProperties @{encoding='UTF-8'}


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

& "$ScriptPath\Merge-RoleToConfigRepository.ps1" -storageConfig $stagingDiscoveryStorageConfig `
                                                 -roleName 'DeployerCapability' `
                                                 -roleUrl "http://$($domainName):9084/httpupload" `
                                                 -roleProperties @{encoding='UTF-8'}


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
                                                 -roleUrl "http://$($domainName):8081/content.svc"

& "$ScriptPath\Merge-RoleToConfigRepository.ps1" -storageConfig $discoveryStorageConfig `
                                                 -roleName 'WebCapability'       
                                                 
# Content service needs to be able to find its discovery
& "$ScriptPath\Merge-ConfigRepository.ps1" -storageConfig $contentStorageConfig `
                                           -discoveryHost 'localhost'
                                           

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

& "$ScriptPath\Merge-Storage.ps1" -storageConfig $stagingContentStorageConfig `
                                             -storageToUpdate "/Configuration/Global/Storages/Wrappers/Wrapper[@Name='SessionWrapper']/Storage[@Id='sessionDb']" `
                                             -dbType 'MSSQL' `
                                             -dbHost $databaseServer `
                                             -dbPort 1433 `
                                             -dbName 'Tridion_Preview' `
                                             -dbUser 'TridionBrokerUser' `
                                             -dbPassword 'Tridion1' 

& "$ScriptPath\Merge-RoleToConfigRepository.ps1" -storageConfig $stagingDiscoveryStorageConfig `
                                                 -roleName 'ContentServiceCapability' `
                                                 -roleUrl "http://$($domainName):9081/content.svc"

& "$ScriptPath\Merge-RoleToConfigRepository.ps1" -storageConfig $stagingDiscoveryStorageConfig `
                                                 -roleName 'WebCapability' 

& "$ScriptPath\Merge-ConfigRepository.ps1" -storageConfig $stagingContentStorageConfig `
                                             -discoveryHost 'localhost' `
                                             -discoveryPort 9082 `

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
                                             -storageToUpdate "/Configuration/Global/Storages/Wrappers/Wrapper[@Name='SessionWrapper']/Storage[@Id='sessionDb']" `
                                             -dbType 'MSSQL' `
                                             -dbHost $databaseServer `
                                             -dbPort 1433 `
                                             -dbName 'Tridion_Preview' `
                                             -dbUser 'TridionBrokerUser' `
                                             -dbPassword 'Tridion1' 

& "$ScriptPath\Merge-RoleToConfigRepository.ps1" -storageConfig $stagingDiscoveryStorageConfig `
                                                 -roleName 'PreviewWebServiceCapability' `
                                                 -roleUrl "http://$($domainName):8083/ws/preview.svc"

& "$ScriptPath\Merge-Logback.ps1" -logbackFile (resolve-path ("Preview\config\logback.xml")) `
                                  -logFolder "$LoggingOutputPath\Preview"

@'
$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path
& $scriptPath\installService.ps1 --Name=SDLWebSessionPreviewService --Description="SDL Web Session Preview Service" `
                                 --DisplayName="SDL Web Session Preview Service" --server.port=8083 
'@ > .\Preview\bin\Invoke-InstallService.ps1

& .\Preview\bin\Invoke-InstallService.ps1

# Live DXA Model service
Copy-Item -Recurse "$DXAInstallerDirectoryPath\cis\dxa-model-service\standalone" "DxaModel"

$discoveryStorageConfig = (resolve-path ("Discovery\config\cd_storage_conf.xml"))
& "$ScriptPath\Merge-RoleToConfigRepository.ps1" -storageConfig $discoveryStorageConfig `
                                                 -roleName 'ContentServiceCapability' `
                                                 -roleProperties @{'dxa-model-service'="http://$($domainName):8998"}

& "$ScriptPath\Merge-Logback.ps1" -logbackFile (resolve-path ("DxaModel\config\logback.xml")) `
                                  -logFolder "$LoggingOutputPath\DxaModel"



@'
$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path
& $scriptPath\installService.ps1 --Name=SDLDXAModelService --Description="SDL DXA Model Service" `
                                 --DisplayName="SDL DXA Model Service" --server.port=8998 --DependsOn=SDLWebDiscoveryService
'@ > .\DxaModel\bin\Invoke-InstallService.ps1

& .\DxaModel\bin\Invoke-InstallService.ps1


# Staging DXA Model service
Copy-Item -Recurse "$DXAInstallerDirectoryPath\cis\dxa-model-service\standalone" "StagingDxaModel"

$stagingDiscoveryStorageConfig = (resolve-path ("StagingDiscovery\config\cd_storage_conf.xml"))
& "$ScriptPath\Merge-RoleToConfigRepository.ps1" -storageConfig $stagingDiscoveryStorageConfig `
                                                 -roleName 'ContentServiceCapability' `
                                                 -roleProperties @{'dxa-model-service'="http://$($domainName):9998"}


& "$ScriptPath\Merge-Logback.ps1" -logbackFile (resolve-path ("StagingDxaModel\config\logback.xml")) `
                                  -logFolder "$LoggingOutputPath\StagingDxaModel"

@'
$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path
& $scriptPath\installService.ps1 --Name=SDLDXAStagingModelService --Description="SDL DXA Staging Model Service" `
                                 --DisplayName="SDL DXA Staging Model Service" --server.port=9998 --DependsOn=SDLWebStagingDiscoveryService 
'@ > .\StagingDxaModel\bin\Invoke-InstallService.ps1

& .\StagingDxaModel\bin\Invoke-InstallService.ps1

#  CONTEXT SERVICE - LIVE
Copy-Item -Recurse "$InstallerDirectoryPath\Content Delivery\roles\context\service\standalone" "Context"

$discoveryStorageConfig = (resolve-path ("Discovery\config\cd_storage_conf.xml"))
& "$ScriptPath\Merge-RoleToConfigRepository.ps1" -storageConfig $discoveryStorageConfig `
                                                 -roleName 'ContextServiceCapability' `
                                                 -roleUrl "http://$($domainName):8087"


& "$ScriptPath\Merge-Logback.ps1" -logbackFile (resolve-path ("Context\config\logback.xml")) `
                                  -logFolder "$LoggingOutputPath\Context"

@'
$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path
& $scriptPath\installService.ps1 --Name=SDLContextService --Description="SDL Context Service" `
                                 --DisplayName="SDL Context Service" --server.port=8087 --DependsOn=SDLWebDiscoveryService 
'@ > .\Context\bin\Invoke-InstallService.ps1

& .\Context\bin\Invoke-InstallService.ps1

#  CONTEXT SERVICE - STAGING
Copy-Item -Recurse "$InstallerDirectoryPath\Content Delivery\roles\context\service\standalone" "StagingContext"

$stagingDiscoveryStorageConfig = (resolve-path ("StagingDiscovery\config\cd_storage_conf.xml"))
& "$ScriptPath\Merge-RoleToConfigRepository.ps1" -storageConfig $stagingDiscoveryStorageConfig `
                                                 -roleName 'ContextServiceCapability' `
                                                 -roleUrl "http://$($domainName):9087"


& "$ScriptPath\Merge-Logback.ps1" -logbackFile (resolve-path ("StagingContext\config\logback.xml")) `
                                  -logFolder "$LoggingOutputPath\StagingContext"

@'
$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path
& $scriptPath\installService.ps1 --Name=SDLStagingContextService --Description="SDL Staging Context Service" `
                                 --DisplayName="SDL Staging Context Service" --server.port=9087 --DependsOn=SDLWebStagingDiscoveryService 
'@ > .\StagingContext\bin\Invoke-InstallService.ps1

& .\StagingContext\bin\Invoke-InstallService.ps1

#REGISTER
pushd StagingDiscovery\config
& java -jar discovery-registration.jar update 
popd

pushd Discovery\config
& java -jar discovery-registration.jar update 
popd




