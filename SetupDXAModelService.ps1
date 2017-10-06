param(
[ValidateScript({Test-Path $_ -PathType 'Container'})] 
[string]$InstallerDirectoryPath='C:\Users\Administrator.WEB85\Downloads\SDL.DXA.Java.2.0.CTP.2',

[string]$ServicesDirectoryPath='C:\SDLServices', 
[string]$LoggingOutputPath='C:\SDLServiceLogs',
[string]$DeployerStorage='C:\SDLDeployerStorage',
[ValidateScript({Test-Path -PathType Leaf -Path $_})]
$licenseLocation='C:\SdlLicenses\cd_licenses.xml', 
$databaseServer='localhost',
$domainName='sdlweb'

)

$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path
. "$scriptPath\Utilities.ps1"

if (-not (isAdministrator) ) {throw "There's a bad moon rising. Best to get admin rights!"}

if (-not (Test-path $ServicesDirectoryPath) ){
    throw "You might want to run the main install first"
}
else {
    $ServicesDirectory = Get-Item $ServicesDirectoryPath
}
set-location $ServicesDirectory


# Live DXA Model service
Copy-Item -Recurse "$InstallerDirectoryPath\cis\dxa-model-service\standalone" "DxaModel"

$discoveryStorageConfig = (resolve-path ("Discovery\config\cd_storage_conf.xml"))
& "$ScriptPath\Merge-RoleToConfigRepository.ps1" -storageConfig $discoveryStorageConfig `
                                                 -roleName 'ContentServiceCapability' `
                                                 -roleProperties @{'dxa-model-service'="http://${$domainName}:8998"}

& "$ScriptPath\Merge-Logback.ps1" -logbackFile (resolve-path ("DxaModel\config\logback.xml")) `
                                  -logFolder "$LoggingOutputPath\DxaModel"



@'
$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path
& $scriptPath\installService.ps1 --Name=SDLDXAModelService --Description="SDL DXA Model Service" `
                                 --DisplayName="SDL DXA Model Service" --server.port=8998 --DependsOn=SDLWebDiscoveryService
'@ > .\DxaModel\bin\Invoke-InstallService.ps1

& .\DxaModel\bin\Invoke-InstallService.ps1


# Live DXA Model service
Copy-Item -Recurse "$InstallerDirectoryPath\cis\dxa-model-service\standalone" "StagingDxaModel"

$stagingDiscoveryStorageConfig = (resolve-path ("StagingDiscovery\config\cd_storage_conf.xml"))
& "$ScriptPath\Merge-RoleToConfigRepository.ps1" -storageConfig $stagingDiscoveryStorageConfig `
                                                 -roleName 'ContentServiceCapability' `
                                                 -roleProperties @{'dxa-model-service'="http://${$domainName}:9998"}


& "$ScriptPath\Merge-Logback.ps1" -logbackFile (resolve-path ("StagingDxaModel\config\logback.xml")) `
                                  -logFolder "$LoggingOutputPath\StagingDxaModel"

@'
$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path
& $scriptPath\installService.ps1 --Name=SDLDXAStagingModelService --Description="SDL DXA Staging Model Service" `
                                 --DisplayName="SDL DXA Staging Model Service" --server.port=9998 --DependsOn=SDLWebStagingDiscoveryService 
'@ > .\StagingDxaModel\bin\Invoke-InstallService.ps1

& .\StagingDxaModel\bin\Invoke-InstallService.ps1

pushd StagingDiscovery\config
& java -jar discovery-registration.jar update 
popd

pushd Discovery\config
& java -jar discovery-registration.jar update 
popd