param(

[string]$ServicesDirectoryPath='C:\SDLServices'

)

gci -Recurse $ServicesDirectoryPath -Include uninstallService.ps1 | % {
    pushd (split-path $_)
    & $_
    popd
}

gci $ServicesDirectoryPath | rm -r