    #This is now redundant
    
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

	$storageElement = [xml]@"
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
	
	$storageElement.Storage.SetAttribute("Id", $storageElementId)
    switch ($DatabaseType) {
        'MSSQL' {
            $storageElement.Storage.DataSource.SetAttribute('Class', 'com.microsoft.sqlserver.jdbc.SQLServerDataSource')
        }
        'ORACLESQL' {
            $storageElement.Storage.DataSource.SetAttribute('Class', 'oracle.jdbc.pool.OracleDataSource')
        }
    }

    ($storageElement.Storage.DataSource.Property | ? {$_.Name -eq "serverName"}).SetAttribute("Value", $ServerName)
    ($storageElement.Storage.DataSource.Property | ? {$_.Name -eq "databaseName"}).SetAttribute("Value", $DatabaseName)
    ($storageElement.Storage.DataSource.Property | ? {$_.Name -eq "user"}).SetAttribute("Value", $DatabaseUserName)
    ($storageElement.Storage.DataSource.Property | ? {$_.Name -eq "password"}).SetAttribute("Value", $DatabasePassword)
    ($storageElement.Storage.DataSource.Property | ? {$_.Name -eq "portNumber"}).SetAttribute("Value", $DatabasePortNumber)
    $storageElement.DocumentElement