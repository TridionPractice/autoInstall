param(

[string]$ServicesDirectoryPath='C:\SDLServices',
[string]$LoggingOutputPath='C:\SDLServiceLogs'

)

gci -Recurse $ServicesDirectoryPath -Include uninstallService.ps1 | % {
    pushd (split-path $_)
    & $_
    popd
}

gci $ServicesDirectoryPath | rm -r
gci $LoggingOutputPath | rm -r