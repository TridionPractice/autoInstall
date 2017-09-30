$originalConfirmPreference = $ConfirmPreference
$ConfirmPreference = "None"

Get-TtmCdTopology | % {Remove-TtmCdTopology -Id $_.Id}

Get-TtmCdTopologyType | % {Remove-TtmCdTopologyType -Id $_.Id}

Get-TtmCdEnvironment | % {Remove-TtmCdEnvironment $_.Id }

$ConfirmPreference = $originalConfirmPreference