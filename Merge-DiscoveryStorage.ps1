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
    $dbPassword
)

function AddPropertyElement($parent, $name , $value){
    $property = $parent.OwnerDocument.CreateElement("Property")
    $property.SetAttribute("Name", $name)
    $property.SetAttribute("Value", $value)
    $parent.AppendChild($property)
}

$config = [xml](gc $discoveryStorageConfig)
$defaultDb = [Xml.XmlElement](Select-Xml -Xml $config.DocumentElement -XPath "/Configuration/Global/Storages/Storage[@Id='defaultdb']").Node
$defaultDb.SetAttribute("dialect", $dbType)

$dataSource = [Xml.XmlElement](Select-Xml -Xml $defaultDb -XPath "Storage/DataSource").Node
Select-Xml -Xml $dataSource -XPath "Property" | % {$_.Node.ParentNode.RemoveChild($_.Node)}
switch ($dbType) {
    "MSSQL" {
        $dataSource.SetAttribute("Class", 'com.microsoft.sqlserver.jdbc.SQLServerDataSource')
        AddChildElement $dataSource "serverName" ""
        }
    "ORACLESQL" {
        $dataSource.SetAttribute("Class", 'oracle.jdbc.pool.OracleDataSource')
        }
}

$defaultDb