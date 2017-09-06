param (
    [ValidateScript({Test-Path -PathType Leaf -Path $_})]
    [Parameter(Mandatory=$true, HelpMessage='The location of the storage config for your discovery service.')]
    $discoveryStorageConfig, 
    $discoveryHost,
    $discoveryPort=8082, 
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

Add-Type -Assembly System.Xml.Linq

function AddPropertyElement($parent, $name , $value){
    $property = $parent.OwnerDocument.CreateElement("Property")
    $property.SetAttribute("Name", $name)
    $property.SetAttribute("Value", $value)
    $parent.AppendChild($property)
}

$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path

$config = [Xml.Linq.XDocument]::Load($discoveryStorageConfig)
$defaultDb = $config.Element('Configuration').Element('Global').Element('Storages').Elements('Storage') | ? {$_.Attribute("Id").Value -eq 'defaultdb'}

$newStorage = & "$scriptPath\CreateDatabaseStorageXElement.ps1" -ServerName $dbHost `
                                                                -DatabaseUserName $dbUser `
                                                                -DatabasePassword $dbPassword `
                                                                -DatabasePortNumber $dbPort `
                                                                -DatabaseName $dbName

$defaultDb.replaceWith($newStorage)

$reslashedLicenseLocation = $licenseLocation -replace '\\','/'
$licenseElement = [Xml.Linq.XElement]::Parse("<License Location='$reslashedLicenseLocation'/>")
$config.Element('Configuration').Element('ItemTypes').AddAfterSelf($licenseElement)`
if ($usePlaceHolders) {
    $discoveryServiceUri = "`$`{discoveryurl:-http://$discoveryHost`:$discoveryPort/discovery.svc`}"  
    $tokenServiceUri =    "`$`{tokenurl:-http://$discoveryHost`:$discoveryPort/token.svc`}"  
} else {
    $discoveryServiceUri = "http://$discoveryHost`:$discoveryPort/discovery.svc"    
    $tokenServiceUri =    "http://$discoveryHost`:$discoveryPort/token.svc"  
}

$configRepository = $config.Element('Configuration').Element('ConfigRepository')
$configRepository.setAttributeValue("ServiceUri", $discoveryServiceUri)
$configRepository.setAttributeValue("TokenServiceUrl", $tokenServiceUri)
$tokenRole =$configRepository.Element('Roles').Elements('Role') | ? {$_.Attribute("Name").Value -eq 'TokenServiceCapability'}
$tokenRole.setAttributeValue("Url", $tokenServiceUri)


if ($stripComments) {
	$comments = $config.DescendantNodes() | ? {$_.NodeType -eq 'Comment'} 
	$comments | % {$_.Remove()}
}

$config.Save($discoveryStorageConfig) 