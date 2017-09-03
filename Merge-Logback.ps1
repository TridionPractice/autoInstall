param (
    [ValidateScript({Test-Path -PathType Leaf -Path $_})]
    [Parameter(Mandatory=$true, HelpMessage='The location of the logback.xml file')]
    $logbackFile, 
    [ValidateSet('OFF','ERROR','WARN','INFO','DEBUG','TRACE','ALL')]
    $logLevel, 
    $logFolder,
    $logPattern,
    $logHistory
)

Add-Type -Assembly System.Xml.Linq

$config = [Xml.Linq.XDocument]::Load($logbackFile)

if ($logLevel) {
    $level = $config.Element('configuration').Elements('property') | ? {$_.Attribute('name').Value -eq 'log.level'}
    $level.Attribute('value').Value = $logLevel
}

if ($logFolder) {
    $folder = $config.Element('configuration').Elements('property') | ? {$_.Attribute('name').Value -eq 'log.folder'}
    $folder.Attribute('value').Value = $logFolder -replace '\\','/' 
}

if ($logPattern) {
    $pattern = $config.Element('configuration').Elements('property') | ? {$_.Attribute('name').Value -eq 'log.pattern'}
    $pattern.Attribute('value').Value = $logPattern
}

if ($logHistory) {
    $history = $config.Element('configuration').Elements('property') | ? {$_.Attribute('name').Value -eq 'log.history'}
    $history.Attribute('value').Value = $logHistory
}


$config.Save($logbackFile) 