param (
    [ValidateScript({Test-Path -PathType Leaf -Path $_})]
    [Parameter(Mandatory=$true, HelpMessage='The location of the storage config.')]
    $storageConfig, 
    $discoveryHost,
    $discoveryPort=8082, 
    [switch]$usePlaceholders=$false
)

Add-Type -Assembly System.Xml.Linq

$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path

$config = [Xml.Linq.XDocument]::Load($storageConfig)

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

$config.Save($storageConfig) 