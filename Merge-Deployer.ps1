param (
    [ValidateScript({Test-Path -PathType Leaf -Path $_})]
    [Parameter(Mandatory=$true, HelpMessage='The location of the deployer config.')]
    $deployerConfig,     
    [ValidateSet('mssql','oracle')]
    $dbAdapter='mssql',
    $dbHost, 
    $dbPort, 
    $dbName, 
    $dbUser, 
    $dbPassword,
    $binaryStoragePath,     
    $queuePath,
    [switch]$stripComments
)

$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path

$config = [xml](gc $deployerConfig)
$stateStorageElement = (Select-Xml -Xml $config -XPath '/Deployer/State/Storage').Node
$stateStorageElement.SetAttribute('Adapter', $dbAdapter)
switch ($dbAdapter) {
    'mssql' {
        $stateStorageElement.SetAttribute('driver', 'com.microsoft.sqlserver.jdbc.SQLServerDriver')
    }
    'oracle' {
        $stateStorageElement.SetAttribute('driver', 'oracle.jdbc.driver.OracleDriver')
    }
}

$binaryPathElement = (Select-Xml -Xml $config -XPath "/Deployer/BinaryStorage[@Id='PackageStorage']/Property[@Name='Path']").Node
$binaryPathElement.SetAttribute("Value", $binaryStoragePath)

$contentQueueDestinationElement = [Xml.XmlElement](Select-Xml -Xml $config -XPath "/Deployer/Queues/Queue[@Id='ContentQueue']/Property[@Name='Destination']").Node
$contentQueueDestinationElement.SetAttribute("Value", $queuePath)
$commitQueueDestinationElement = [Xml.XmlElement](Select-Xml -Xml $config -XPath "/Deployer/Queues/Queue[@Id='CommitQueue']/Property[@Name='Destination']").Node
$commitQueueDestinationElement.SetAttribute("Value", "$queuePath/FinalTX")
$prepareQueueDestinationElement = [Xml.XmlElement](Select-Xml -Xml $config -XPath "/Deployer/Queues/Queue[@Id='PrepareQueue']/Property[@Name='Destination']").Node
$prepareQueueDestinationElement.SetAttribute("Value", "$queuePath/Prepare")

(Select-Xml -Xml $stateStorageElement -XPath "Property[@Name='host']").Node.SetAttribute('Value',$dbHost)
(Select-Xml -Xml $stateStorageElement -XPath "Property[@Name='port']").Node.SetAttribute('Value',$dbPort)
(Select-Xml -Xml $stateStorageElement -XPath "Property[@Name='database']").Node.SetAttribute('Value',$dbName)
(Select-Xml -Xml $stateStorageElement -XPath "Property[@Name='user']").Node.SetAttribute('Value',$dbUser)
(Select-Xml -Xml $stateStorageElement -XPath "Property[@Name='password']").Node.SetAttribute('Value',$dbPassword)



if ($stripComments) {
    Select-Xml -Xml $config -XPath '//comment()' | % {$_.Node.ParentNode.removeChild($_.Node)} | Out-Null
}

#avoid writing a BOM which might upset the service
$encoding = new-object System.Text.UTF8Encoding $false
$writer = new-object System.IO.StreamWriter($deployerConfig,$false,$encoding)
$config.Save($writer)
$writer.Close()