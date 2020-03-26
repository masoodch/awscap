function Get-EC2InstanceStats {
	<#
	.SYNOPSIS
	Provides user with the statistics for an EC2 Instance
	.DESCRIPTION
	Provides user with the statistics for an EC2 Instance such as Instance Name and EBS information
	.EXAMPLE
    Get-EC2InstanceStats -instance (Get-EC2Instance -InstanceId i-0750352b3edc7225f)    
    .PARAMETER instance
    The instance name we need the stats for
	#>
	[CmdletBinding()]
	param
	(	
		[Parameter(
			Mandatory=$True,
			ValueFromPipeline = $true,
            HelpMessage='Provide the instance'
		)]
        [Amazon.EC2.Model.Reservation]$instance
    )

    $volumes = $instance.instances.blockdevicemappings

    foreach ($ec2volume in ($volumes))
    {
        $ec2disk = Get-EC2Volume -VolumeId $ec2volume.ebs.volumeid

        [PSCustomObject]@{
            InstanceID = $instance.instances.instanceID
            InstanceName = ($instance.instances.tags | Where-Object {$_.Key -eq "Name"}).value
            InstanceType = $instance.instances.instancetype.value
            AdditionalEBSVolumes = $volumes.count - 1
            VolumeID = $ec2disk.VolumeId
            BlockDeviceMapping = $ec2volume.devicename
            Encrypted = $ec2disk.Encrypted
            State = $ec2disk.State
            Size = $ec2disk.Size
        }
    }

}

function Get-CECostAndUsageMonthly {
	<#
	.SYNOPSIS
	Returns the cost of One Month of ever AWS Resource
	.DESCRIPTION
	Running this script provides the cost of all tagged Amazon Resources
	.EXAMPLE
    Get-CECostAndUsageMonthly    
    #>
	
    #Print cost details for the Account for current month
    $currDate = Get-Date
    $firstDay = Get-Date $currDate -Day 1 -Hour 0 -Minute 0 -Second 0
    $lastDay = Get-Date $firstDay.AddMonths(1).AddSeconds(-1)
    $firstDayFormat = Get-Date $firstDay -Format 'yyyy-MM-dd'
    $lastDayFormat = Get-Date $lastDay -Format 'yyyy-MM-dd'
    
    $interval = New-Object Amazon.CostExplorer.Model.DateInterval
    $interval.Start = $firstDayFormat
    $interval.End = $lastDayFormat

    #https://arindamhazra.com/amazon-ec2-cost-and-usage-report/
    $groupInfo = New-Object Amazon.CostExplorer.Model.GroupDefinition
    $groupInfo.Type = "TAG"
    $groupInfo.Key = "Name"
    
    $costUsage = Get-CECostAndUsage -TimePeriod $interval -Granularity MONTHLY -GroupBy $groupInfo -Metric BlendedCost
    
    #$costUsage.ResultsByTime.Total["BlendedCost"]
    
    foreach ($item in $costUsage.ResultsByTime.groups)
    {
        [PSCustomObject]@{
            Name = if ($item.keys) {($item.keys).split("$")[-1]} else {"empty"}
            MonthlyCost = [math]::Round($item.metrics["BlendedCost"].Amount, 2)
        }
    }
}