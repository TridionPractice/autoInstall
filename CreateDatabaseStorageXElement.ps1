    param(
        [parameter(Mandatory=$True)]   
        [string]$ServerName , 

        [parameter(Mandatory=$True)]   
        [string]$DatabaseName,

        [parameter(Mandatory=$True)]   
        [string]$DatabaseUserName,

        [parameter(Mandatory=$True)]   
        [string]$DatabasePassword,

        [parameter(Mandatory=$True)]
        [int]$DatabasePortNumber,
	
	    [parameter(Mandatory=$false)]
	    [string]$storageElementId="defaultdb", 

        [parameter(Mandatory=$false)]
        [ValidateSet('MSSQL','ORACLESQL')]
        [string]$DatabaseType='MSSQL'
    )

	$template = @"
	<Storage Type="persistence" Id="" dialect="MSSQL" Class="com.tridion.storage.persistence.JPADAOFactory">
		<Pool Type="jdbc" Size="5" MonitorInterval="60" IdleTimeout="120" CheckoutTimeout="120"/>
		<DataSource Class="com.microsoft.sqlserver.jdbc.SQLServerDataSource">
			<Property Name="serverName"/>
			<Property Name="databaseName" />
			<Property Name="user" />
			<Property Name="password" /> 
            <Property Name="portNumber" /> 
		</DataSource>
	</Storage>
"@
	$storageXElement = [Xml.Linq.XElement]::Parse($template)
	$storageXElement.SetAttributeValue("Id", $storageElementId)
    switch ($DatabaseType) {
        'MSSQL' {
            $storageXElement.Element("DataSource").setAttributeValue('Class', 'com.microsoft.sqlserver.jdbc.SQLServerDataSource')
        }
        'ORACLESQL' {
            $storageXElement.Element("DataSource").setAttributeValue('Class', 'oracle.jdbc.pool.OracleDataSource')
        }
    }
	$storageXElement.Element("DataSource").Elements("Property") | ? {$_.Attribute("Name").Value -eq "serverName"} | % {$_.SetAttributeValue("Value", $ServerName)}
	$storageXElement.Element("DataSource").Elements("Property") | ? {$_.Attribute("Name").Value -eq "databaseName"} | % {$_.SetAttributeValue("Value", $DatabaseName)}
	$storageXElement.Element("DataSource").Elements("Property") | ? {$_.Attribute("Name").Value -eq "user"} | % {$_.SetAttributeValue("Value", $DatabaseUserName)}
	$storageXElement.Element("DataSource").Elements("Property") | ? {$_.Attribute("Name").Value -eq "password"} | % {$_.SetAttributeValue("Value", $DatabasePassword)}
    $storageXElement.Element("DataSource").Elements("Property") | ? {$_.Attribute("Name").Value -eq "portNumber"} | % {$_.SetAttributeValue("Value", $DatabasePortNumber)}
    $storageXElement