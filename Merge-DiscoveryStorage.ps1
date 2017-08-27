param (
    [ValidateScript({Test-Path -PathType Leaf -Path $_})]
    [Parameter(Mandatory=$true, HelpMessage='The location of the storage config for your discovery service.')]
    $discoveryStorageConfig, 
    $discoveryHost, 
    [ValidateSet('MSSQL','ORACLESQL')]
    $dbType,
    $dbHost, 
    $dbPort, 
    $dbName, 
    $dbUser, 
    $dbPassword,
    [switch]$stripComments
)

function AddPropertyElement($parent, $name , $value){
    $property = $parent.OwnerDocument.CreateElement("Property")
    $property.SetAttribute("Name", $name)
    $property.SetAttribute("Value", $value)
    $parent.AppendChild($property)
}

$config = [Xml.Linq.XDocument]::Load($discoveryStorageConfig)
$defaultDb = $config.Element('Configuration').Element('Global').Element('Storages').Element('Storage') | ? {$_.Attribute("Id").Value -eq 'defaultdb'}

$newStorage = .\CreateDatabaseStorageXElement.ps1 -ServerName $dbHost `
                                                    -DatabaseUserName $dbUser `
                                                    -DatabasePassword $dbPassword `
                                                    -DatabasePortNumber $dbPort `
                                                    -DatabaseName $dbName

$defaultDb.replaceWith($newStorage)

if ($stripComments) {
	$comments = $config.DescendantNodes() | ? {$_.NodeType -eq 'Comment'} 
	$comments | % {$_.Remove()}
}

$config.Save($discoveryStorageConfig) 