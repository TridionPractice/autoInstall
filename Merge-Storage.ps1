param (
    [ValidateScript({Test-Path -PathType Leaf -Path $_})]
    [Parameter(Mandatory=$true, HelpMessage='The location of the storage config.')]
    $storageConfig, 
    $storageToReplace="/Configuration/Global/Storages/Storage[@Id='defaultdb']",
    [ValidateSet('MSSQL','ORACLESQL')]
    $dbType,
    $dbHost, 
    $dbPort, 
    $dbName, 
    $dbUser, 
    $dbPassword,
    [ValidateScript({Test-Path -PathType Leaf -Path $_})]
    $licenseLocation,
    [switch]$usePlaceholders=$false,
    [switch]$stripComments
)

$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path

$config = [xml](gc $storageConfig)
$defaultDb = (Select-Xml -Xml $config -XPath $StorageToReplace).Node

$newStorage = & "$scriptPath\CreateDatabaseStorageXmlElement.ps1" -ServerName $dbHost `
                                                                -DatabaseUserName $dbUser `
                                                                -DatabasePassword $dbPassword `
                                                                -DatabasePortNumber $dbPort `
                                                                -DatabaseName $dbName

$defaultDb.ParentNode.replaceChild($defaultDb.OwnerDocument.ImportNode($newStorage, $true), $defaultDb) 

if ($licenseLocation) {
    $itemTypesElement = (Select-Xml -Xml $config -XPath "/Configuration/ItemTypes").Node
    $reslashedLicenseLocation = $licenseLocation -replace '\\','/'
    $licenseElement = $itemTypesElement.OwnerDocument.CreateElement('License')
    $licenseElement.SetAttribute('Location', $reslashedLicenseLocation)    $itemTypesElement.ParentNode.InsertAfter($licenseElement, $itemTypesElement)}
if ($stripComments) {
    Select-Xml -Xml $config -XPath '//comment()' | % {$_.Node.ParentNode.removeChild($_.Node)} | Out-Null
}

#avoid writing a BOM which might upset the service
$encoding = new-object System.Text.UTF8Encoding $false
$writer = new-object System.IO.StreamWriter($storageConfig,$false,$encoding)
$config.Save($writer)
$writer.Close()