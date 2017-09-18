param (
    [ValidateScript({Test-Path -PathType Leaf -Path $_})]
    [Parameter(Mandatory=$true, HelpMessage='The location of the storage config.')]
    $storageConfig, 
    $roleName,
    $rolePlaceHolder, 
    $roleUrl,
    [switch]$usePlaceholders=$false
)


$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path

$config = [xml](gc $storageConfig)

if ($usePlaceHolders -and $rolePlaceHolder) {
    $roleUrl = "`$`{$rolePlaceHolder`:-$roleUrl`}"      
} else {
    $roleUrl = $roleUrlParam    
}

# <Role Name="ContentServiceCapability" Url="${contenturl:-http://localhost:8081/content.svc}"/>

$roles = (Select-Xml -Xml $config.DocumentElement -XPath '/Configuration/ConfigRepository/Roles').Node
$role = (Select-Xml -Xml $roles -XPath "Role[@Name='$roleName']").Node
if ($role) {
    $role.setAttribute("Url", $roleUrl)
} else {
    $role = $roles.OwnerDocument.CreateElement('Role')
    $role.SetAttribute("Name", $roleName)
    $role.SetAttribute("Url", $roleUrl)
}

$config.Save($storageConfig) 