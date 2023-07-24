﻿param($SCPath, $Sub, $Resources, $Task ,$File, $SmaResources, $TableStyle, $Metrics)

If ($Task -eq 'Processing')
{
    $virtualMachines =  $Resources | Where-Object { $_.TYPE -eq 'microsoft.compute/virtualmachines' } 
    $virtualMachineMetrics = $Metrics | Where-Object { $_.Service -eq 'Virtual Machines' }

    $vmsizemap = @{}

    foreach($location in ($virtualMachines | Select-Object -ExpandProperty location -Unique))
    {
        foreach ($vmsize in ( az vm list-sizes -l $location | ConvertFrom-Json))
        {
            $vmsizemap[$vmsize.name] = @{
                CPU = $vmSize.numberOfCores
                RAM = [math]::Round($vmSize.memoryInMB / 1024, 0) 
            }
        }
    }

    if($virtualMachines)
    {    
        $tmp = @()

        foreach ($vm in $virtualMachines) 
        {
            $sub1 = $SUB | Where-Object { $_.id -eq $vm.subscriptionId }
            $data = $vm.PROPERTIES 
            $timecreated = $data.timeCreated
            $timecreated = [datetime]$timecreated
            $timecreated = $timecreated.ToString("yyyy-MM-dd HH:mm")

            switch ($data.licenseType) 
            {
                'Windows_Server' { $Lic = 'AHUB for Windows' }
                'Windows_Client' { $Lic = 'Windows Client Multi-Tenant' }
                'RHEL_BYOS'      { $Lic = 'AHUB for Redhat' }
                'SLES_BYOS'      { $Lic = 'AHUB for SUSE' }
            }

            $Lic = if($Lic) { $Lic } else { 'License Included' }

            $vmMetrics = $virtualMachineMetrics | Where-Object { $_.Id -eq $vm.id }
            $cpuUtilisationMetric = $vmMetrics | Where-Object { $_.Metric -eq 'Percentage CPU' }
            $memoryAvilableMetric = $vmMetrics | Where-Object { $_.Metric -eq 'Available Memory Bytes' }
            $memoryTotalGb = $vmsizemap[$data.hardwareProfile.vmSize].RAM

            $obj = @{
                'ID'                            = $vm.id;
                'Subscription'                  = $sub1.Name;
                'ResourceGroup'                 = $vm.RESOURCEGROUP;
                'Name'                          = $vm.NAME;
                'Location'                      = $vm.LOCATION;
                'AvailabilitySet'               = if ($null -ne $data.availabilitySet) { 'true' } else { 'false' }    
                'Size'                          = $data.hardwareProfile.vmSize;
                'CPU'                           = $vmsizemap[$data.hardwareProfile.vmSize].CPU;
                'Memory'                        = $vmsizemap[$data.hardwareProfile.vmSize].RAM;
                'ImageReference'                = $data.storageProfile.imageReference.publisher;
                'ImageVersion'                  = $data.storageProfile.imageReference.exactVersion;
                'HybridBenefit'                 = $Lic;
                'OS'                            = $data.storageProfile.osDisk.osType;
                'OSName'                        = $data.extended.instanceView.osname;
                'OSVersion'                     = $data.extended.instanceView.osversion;
                'PowerState'                    = $data.extended.instanceView.powerState.displayStatus;
                'CPUAvgPercent'                 = if ($null -ne $cpuUtilisationMetric.MetricValue) { $cpuUtilisationMetric.MetricValue } else { '0' }
                'MemoryAvgPercent'              = if ($null -ne $memoryAvilableMetric.MetricValue) { $memoryTotalGb - ($memoryAvilableMetric.MetricValue / (1024 * 1024 * 1024)) } else { '0' }
                'CreatedTime'                   = $timecreated;
            }

            $tmp += $obj
        }
              
        $tmp
    }            
}
else
{
    If($SmaResources.VirtualMachines)
    {
        $TableName = ('VMTable_'+($SmaResources.VirtualMachines.id | Select-Object -Unique).count)
        $Style = New-ExcelStyle -HorizontalAlignment Center -AutoSize -NumberFormat '0' -VerticalAlignment Center

        $Exc = New-Object System.Collections.Generic.List[System.Object]
        $Exc.Add('Subscription')
        $Exc.Add('ResourceGroup')
        $Exc.Add('Name')
        $Exc.Add('Size')
        $Exc.Add('CPU')
        $Exc.Add('Memory')
        $Exc.Add('Location')
        $Exc.Add('OS')
        $Exc.Add('OSName')
        $Exc.Add('OSVersion')
        $Exc.Add('ImageReference')
        $Exc.Add('ImageVersion')
        $Exc.Add('HybridBenefit')
        $Exc.Add('PowerState')
        $Exc.Add('AvailabilitySet')
        $Exc.Add('CPUAvgPercent')
        $Exc.Add('MemoryAvgPercent')
        $Exc.Add('CreatedTime')     

        $ExcelVar = $SmaResources.VirtualMachines
                    
        $ExcelVar | 
        ForEach-Object { [PSCustomObject]$_ } | Select-Object -Unique $Exc | 
        Export-Excel -Path $File -WorksheetName 'Virtual Machines' -TableName $TableName -MaxAutoSizeRows 100 -TableStyle $tableStyle -Style $Style
    }             
}
