Param(
[Parameter(Mandatory=$false)]
[String]$firstDay,
[Parameter(Mandatory=$false)]
[String]$lastDay
)

#Print cost details for the Account for previous month if no dates provided
if([String]::IsNullOrEmpty($firstDay)){
    $firstDay = Get-Date -Year (Get-Date).Year -Month (Get-Date).AddMonths(-1).Month -Day 1 -UFormat "%Y-%m-%d"
}
if([String]::IsNullOrEmpty($lastDay)){
    $lastDay = Get-Date -Year (Get-Date).Year -Month (Get-Date).AddMonths(-1).Month -Day ([DateTime]::DaysInMonth((Get-Date).Year, (Get-Date).Month)) -UFormat "%Y-%m-%d"
}
$currentDir = $(Get-Location).Path
$oFile = "$($currentDir)\aws_ec2_billing_usage_data.csv"
$tFile = "$($currentDir)\aws_ec2_billing_usage_data_temp.csv"
if(Test-Path $oFile){
    Remove-Item $oFile -Force
}
if(Test-Path $tFile){
    Remove-Item $tFile -Force
}
"Name,Date,UsageHours,Cost" | Out-File $tFile -Append -Encoding ASCII
$interval = New-Object Amazon.CostExplorer.Model.DateInterval
$interval.Start = $firstDay
$interval.End = $lastDay

$dimension = New-Object Amazon.CostExplorer.Model.DimensionValues
$dimension.Key = "SERVICE"
$dimension.Values ="Amazon Elastic Compute Cloud - Compute"
$Filter = New-Object Amazon.CostExplorer.Model.Expression
$Filter.Dimensions = $dimension
$groupInfo = New-Object Amazon.CostExplorer.Model.GroupDefinition
$groupInfo.Type = "TAG"
$groupInfo.Key = "Name"

$metric = @("BlendedCost","UsageQuantity")

$costUsage = Get-CECostAndUsage -TimePeriod $interval -Granularity MONTHLY -Metric $metric -Filter $Filter -GroupBy $groupInfo
ForEach($c in $costUsage.ResultsByTime){
    $sTime = $cost = $instanceName = ""
    $sTime = $c.TimePeriod.Start
    ForEach($grp in $c.Groups){
        $instanceName = $grp.Keys.Split("$")[1]
        if([String]::IsNullOrEmpty($instanceName)){$instanceName = "No Name Tag"}
        $cost = $grp.Metrics["BlendedCost"].Amount
        $usageHours = $grp.Metrics["UsageQuantity"].Amount
        "$instanceName,$sTime,$usageHours,$cost" | Out-File $tFile -Append -Encoding ASCII
    }
}

Import-Csv $tFile | Sort-Object 'Name','Date' | Export-Csv -Path $oFile -NoTypeInformation
if(Test-Path $tFile){
    Remove-Item $tFile -Force
}