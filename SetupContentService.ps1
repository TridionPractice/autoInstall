# Intended to be merged into the main setup - so starting with exactly the same params
param(
[ValidateScript({Test-Path $_ -PathType 'Container'})] 
[string]$InstallerDirectoryPath='C:\Users\Administrator.WEB85\Downloads\SDL Web 8.5',

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

#  CONTEXT SERVICE - LIVE
Copy-Item -Recurse "$InstallerDirectoryPath\Content Delivery\roles\context\service\standalone" "Context"

$discoveryStorageConfig = (resolve-path ("Discovery\config\cd_storage_conf.xml"))
& "$ScriptPath\Merge-RoleToConfigRepository.ps1" -storageConfig $discoveryStorageConfig `
                                                 -roleName 'ContextServiceCapability' `
                                                 -roleUrl "http://${$domainName}:8087"


& "$ScriptPath\Merge-Logback.ps1" -logbackFile (resolve-path ("Context\config\logback.xml")) `
                                  -logFolder "$LoggingOutputPath\Context"

@'
$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path
& $scriptPath\installService.ps1 --Name=ContextService --Description="SDL Context Service" `
                                 --DisplayName="SDL Context Service" --server.port=8087 --DependsOn=SDLWebDiscoveryService 
'@ > .\Context\bin\Invoke-InstallService.ps1

& .\Context\bin\Invoke-InstallService.ps1

#  CONTEXT SERVICE - STAGING
Copy-Item -Recurse "$InstallerDirectoryPath\Content Delivery\roles\context\service\standalone" "StagingContext"

$stagingDiscoveryStorageConfig = (resolve-path ("Discovery\config\cd_storage_conf.xml"))
& "$ScriptPath\Merge-RoleToConfigRepository.ps1" -storageConfig $stagingDiscoveryStorageConfig `
                                                 -roleName 'ContextServiceCapability' `
                                                 -roleUrl "http://${$domainName}:9087"


& "$ScriptPath\Merge-Logback.ps1" -logbackFile (resolve-path ("StagingContext\config\logback.xml")) `
                                  -logFolder "$LoggingOutputPath\StagingContext"

@'
$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path
& $scriptPath\installService.ps1 --Name=SDLStagingContextService --Description="SDL Staging Context Service" `
                                 --DisplayName="SDL Staging Context Service" --server.port=9087 --DependsOn=SDLWebStagingDiscoveryService 
'@ > .\StagingContext\bin\Invoke-InstallService.ps1

& .\StagingContext\bin\Invoke-InstallService.ps1


pushd Context\config
& java -jar discovery-registration.jar update 
popd

pushd StagingContext\config
& java -jar discovery-registration.jar update 
popd
