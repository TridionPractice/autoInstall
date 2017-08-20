#Parking this effort for now while I look at the quickinstall script

param(
[ValidateScript({Test-Path $_ -PathType 'Container'})] 
[string]$InstallerDirectoryPath='C:\Users\NetAdmin\Downloads\SDL Web 8.5',

[string]$ServicesDirectoryPath='C:\SDLServices',

[string[]]$SitePrefixes=("Staging","Live")

)

# ValidateScript won't check the default value, so do it here
if (-not (Test-Path ($InstallerDirectoryPath + '\Content Delivery'))) {
    throw "That doesn't look like the installation directory: bailing...."
}

if (-not (Test-path $ServicesDirectoryPath) ){
    $ServicesDirectory = New-Item -ItemType Directory -Path $ServicesDirectoryPath
}
else {
    $ServicesDirectory = Get-Item $ServicesDirectoryPath
}
set-location $ServicesDirectory

#Disco
$SitePrefixes | % {Copy-Item -Recurse "C:\Users\NetAdmin\Downloads\SDL Web 8.5\Content Delivery\roles\discovery\standalone" ($_ + "Discovery")}  







