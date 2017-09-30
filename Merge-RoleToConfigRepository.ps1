param (
    [ValidateScript({Test-Path -PathType Leaf -Path $_})]
    [Parameter(Mandatory=$true, HelpMessage='The location of the storage config.')]
    $storageConfig, 
    $roleName,
    $rolePlaceHolder, 
    $roleUrl,
    [hashtable]$roleProperties,
    [switch]$usePlaceholders=$false
)


$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path

$config = [xml](gc $storageConfig)

if ($roleUrl) {
    if ($usePlaceHolders -and $rolePlaceHolder) {
        $roleUrl = "`$`{$rolePlaceHolder`:-$roleUrl`}"      
    } else {
        $roleUrl = $roleUrl    
    }
}

# <Role Name="ContentServiceCapability" Url="${contenturl:-http://localhost:8081/content.svc}"/>

$roles = (Select-Xml -Xml $config.DocumentElement -XPath '/Configuration/ConfigRepository/Roles').Node
$role = (Select-Xml -Xml $roles -XPath "Role[@Name='$roleName']").Node
if ($role) {
    if ($roleUrl) { #We may only be setting properties
        $role.setAttribute("Url", $roleUrl)
    }
} else {
    $role = $roles.OwnerDocument.CreateElement('Role')
    $roles.AppendChild($role)
    $role.SetAttribute("Name", $roleName)
    if ($roleUrl) {
        $role.SetAttribute("Url", $roleUrl)
    }
}

#      <Role Name="DeployerCapability" Url="${deployerurl:-http://localhost:8084/httpupload}">
#        <Property Name="encoding" Value="UTF-8" />
#      </Role>
#REVIEW: This could be more robust in the scenario where the specified property already exists
if ($roleProperties) {
    $roleProperties.Keys | % {
        $property = $role.OwnerDocument.CreateElement('Property') 
        $role.AppendChild($property)
        $property.SetAttribute("Name", $_)
        $property.SetAttribute("Value", $roleProperties.Item($_))
    }
}

$config.Save($storageConfig) 