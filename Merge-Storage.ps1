param (
    [ValidateScript({Test-Path -PathType Leaf -Path $_})]
    [Parameter(Mandatory=$true, HelpMessage='The location of the storage config.')]
    $storageConfig, 
    $storageToUpdate="/Configuration/Global/Storages/Storage[@Id='defaultdb']",
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

$storageElement = (Select-Xml -Xml $config -XPath $storageToUpdate).Node

switch ($dbType) {
    'MSSQL' {
        $storageElement.DataSource.SetAttribute('Class', 'com.microsoft.sqlserver.jdbc.SQLServerDataSource')
    }
    'ORACLESQL' {
        $storageElement.DataSource.SetAttribute('Class', 'oracle.jdbc.pool.OracleDataSource')
        
    }
}
$storageElement.SetAttribute('dialect', $dbType)

(Select-Xml -Xml $storageElement -XPath "DataSource/Property[@Name='serverName']").Node.SetAttribute('Value', $dbhost)
(Select-Xml -Xml $storageElement -XPath "DataSource/Property[@Name='portNumber']").Node.SetAttribute('Value', $dbport)
(Select-Xml -Xml $storageElement -XPath "DataSource/Property[@Name='databaseName']").Node.SetAttribute('Value', $dbName)
(Select-Xml -Xml $storageElement -XPath "DataSource/Property[@Name='user']").Node.SetAttribute('Value', $dbUser)
(Select-Xml -Xml $storageElement -XPath "DataSource/Property[@Name='password']").Node.SetAttribute('Value', $dbPassword)

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