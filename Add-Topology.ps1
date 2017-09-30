Add-TtmCdEnvironment -Id liveEnvironment -DiscoveryEndpointUrl http://localhost:8082/discovery.svc -EnvironmentPurpose "Live" -AuthenticationType OAuth -ClientId cmuser -ClientSecret 'CMUserP@ssw0rd'
Add-TtmCdEnvironment -Id stagingEnvironment -DiscoveryEndpointUrl http://localhost:9082/discovery.svc -EnvironmentPurpose "Staging" -AuthenticationType OAuth -ClientId cmuser -ClientSecret 'CMUserP@ssw0rd'

Add-TtmWebsite -Id liveWebSite -CdEnvironmentId liveEnvironment -BaseUrls @("http://www.visitorsweb.local/") 
Add-TtmWebsite -Id stagingWebSite -CdEnvironmentId stagingEnvironment -BaseUrls @("http://staging.visitorsweb.local/")

Add-TtmCdTopologyType -Id stagingAndLiveTopologyType -EnvironmentPurposes 'Staging','Live' -Name "StagingAndLive"

Add-TtmCdTopology -Id stagingAndLiveTopology -CdTopologyTypeId stagingAndLiveTopologyType -Name "StagingAndLive" -CdEnvironmentIds stagingEnvironment,liveEnvironment


#Add-TtmMapping