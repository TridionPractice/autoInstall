param(
    [ValidateScript({Test-Path $_ -PathType 'Container'})] 
    [string]$InstallerDirectoryPath='C:\Users\NetAdmin\Downloads\SDL Web 8.5'

)

$TestDir = '.'

rm -Force cd_storage_conf.xml | Out-Null

$discoveryStorageConfig = cp -PassThru ($InstallerDirectoryPath + '\Content Delivery\roles\deployer\deployer-combined\standalone\config\cd_storage_conf.xml') $TestDir
$discoveryHost = 'theServer'
$dbType='MSSQL'
$dbHost='theDatabaseServer' 
$dbPort=1234
$dbName='itsTheBroker' 
$dbUser='theBrokerUser' 
$dbPassword='topSecret'
    


.\Merge-DiscoveryStorage.ps1 -discoveryStorageConfig $discoveryStorageConfig `
                             -discoveryHost $discoveryHost `
                             -dbType $dbType `
                             -dbHost $dbHost `
                             -dbPort $dbPort `
                             -dbName $dbName `
                             -dbUser $dbUser `
                             -dbPassword $dbPassword `
                             -stripComments

 