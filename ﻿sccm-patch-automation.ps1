
function GetEvaluationState {
   param (
       [int]$evalState
    )

   Switch ($evalState)
   {
    8 {"Pending Reboot ($evalState)"; break}
    9 {"Pending Reboot ($evalState)"; break}
    10 {"Pending Reboot ($evalState)"; break}
    6 {"Waiting To Install ($evalState)"; break}
    5 {"Downloading ($evalState)"; break}
    7 {"Installing ($evalState)"; break}
    11 {"Verifying ($evalState)"; break}
    12 {"Install Complete ($evalState)"; break}
    13 {"Error ($evalState)"; break}
    Default {$evalState}
   } 

}

function SCCMUpdateList{
   param (
       [string]$Namespace 
   )
   $availableUpdates=Get-WmiObject -ComputerName "localhost" -Namespace "root\CCM\ClientSDK" -ClassName CCM_SoftwareUpdate -ErrorAction Stop -Filter ComplianceState=0

   foreach ($update in $availableUpdates)
   {
       Write-Host $update.Name
   }
   
}



function InstallAllUpdates {
   param (
       [string]$Namespace
    )

   #1. get the update 
   $updates=@(Get-WmiObject -ComputerName "localhost" -Namespace $Namespace -ClassName CCM_SoftwareUpdate -ErrorAction Stop -Filter ComplianceState=0)

   #1.1 if there are no updates exit
   if ($updates.Length -eq 0)
     {
       write-host "No more updates available on server"
       return $null
     }

   #2. format updates
   $UpdatesReformatted = @($updates | ForEach-Object {
       if ($_.ComplianceState -eq 0) {[WMI]$_.__PATH}
     })

   #3. invoke updates
   Invoke-WmiMethod -ComputerName "localhost" -Class CCM_SoftwareUpdatesManager -Name InstallUpdates -ArgumentList (, $UpdatesReformatted) -Namespace $Namespace

   #4. show status
   $finishStates = @(8, 9, 10, 12, 19)
   $availableCounts=$updates.Length

   $appliedPatches= [System.Collections.Generic.List[string]]::new() # holds completed patches

   do {

     Start-Sleep -Seconds 120
     $updatesAvailable=@(Get-WmiObject -ComputerName "localhost" -Namespace $Namespace -ClassName CCM_SoftwareUpdate -ErrorAction Stop -Filter ComplianceState=0)
     # only include updates to be installed and not the completed ones
     $updates=$updatesAvailable | Where-object -FilterScript { (8,9,10,12,19) -notcontains $_.EvaluationState }

     # if the update is aloready complete it will not return a value and will be null.
     if ($updates.Length -eq 0)
     {
       write-host "All Updates are complete"
       break;
     }
     
      foreach($update in $updates)
     {
       $state= GetEvaluationState ($($update.EvaluationState))
       $text = "$($update.Name) - $($update.PercentComplete)% Complete - $state "

       
       #Write-Host $text

       # add update to the list if being patched.
                if (!($appliedPatches.contains($($update.Name))))
                {
                        $appliedPatches.Add($($update.Name))
                }

       Write-Progress -Activity "Update Progress: $($update.Name)" -Status "$($update.PercentComplete)% Complete" -PercentComplete $($update.PercentComplete)
      # Write-Host "--------------------------------------"

     }
   
    
     # yup, $updates.PercentComplete is an array, but "-ne" will acts as a filter function
   } while ($($updates.Count) -gt 0)


    return $appliedPatches
   
}


$appliedPatches = InstallAllUpdates -Namespace "root\CCM\ClientSDK"

Write-Host "Patch count:$appliedPatches.count"
 
if ($($appliedPatches.Count) -gt 0)
{
   Write-Host "Installed patches on server: $env:COMPUTERNAME"
   Write-Host "--------------------------------------"
   # show completed patches
   for ($i=0; $i -lt $($appliedPatches.Count); $i++)
   {
       Write-Host $($appliedPatches[$i])
   }
   

   # reboot server
   Write-Host "--------------------------------------"
   write-host "Restarting server..."
   Start-Sleep 30
   Restart-Computer localhost
}
else
{
   write-host "No patches found."
}

#SCCMUpdateList -Namespace "root\CCM\ClientSDK"

<#
     https://docs.microsoft.com/en-us/sccm/develop/reference/core/clients/sdk/ccm_softwareupdate-client-wmi-class
     EvaulationState:
       0        ciJobStateNone
       1        ciJobStateAvailable
       2        ciJobStateSubmitted
       3        ciJobStateDetecting
       4        ciJobStatePreDownload
       5        ciJobStateDownloading
       6        ciJobStateWaitInstall
       7        ciJobStateInstalling
       8        ciJobStatePendingSoftReboot
       9        ciJobStatePendingHardReboot
       10        ciJobStateWaitReboot
       11        ciJobStateVerifying
       12        ciJobStateInstallComplete
       13        ciJobStateError
       14        ciJobStateWaitServiceWindow
       15        ciJobStateWaitUserLogon
       16        ciJobStateWaitUserLogoff
       17        ciJobStateWaitJobUserLogon
       18        ciJobStateWaitUserReconnect
       19        ciJobStatePendingUserLogoff
       20        ciJobStatePendingUpdate
       21        ciJobStateWaitingRetry
       22        ciJobStateWaitPresModeOff
       23        ciJobStateWaitForOrchestration
   #>

	

sccm-patch-count.ps1
$updates=@(Get-WmiObject -ComputerName "localhost" -Namespace "root\CCM\ClientSDK" -ClassName CCM_SoftwareUpdate -ErrorAction Stop -Filter ComplianceState=0)
$patcheNames=""
foreach ($update in $updates)
{
   Write-Host $update.name
    
}
if ($updates.length -eq 0)
{
   Write-Host "No patches available to install on server "
}
	





SCCM_VS4.ps1
<#
 .SYNOPSIS
   Install all updates available via SCCM and WAIT for the installation to finish.
 .PARAMETER Computer
   the computer to install updates on
 .OUTPUTS
   a object containing information about the installed updates and the reboot state (if a reboot is required or not)
   Name                           Value
   ----                           -----
   result                         System.Management.ManagementBaseObject
   updateInfo                     {ApprovedUpdates, PendingPatches, RebootPending}
   rebootPending                  Boolean
 .EXAMPLE
 . .\Install-SCCMUpdates.ps1; Install-SCCMUpdates
 dot-source the script to load the function "Install-SCCMUpdates", directly call the function afterwards
 .NOTES
   the target computer needs to have SCCM enabled
   (this is implicitly checked by accessing the root\CCM\ClientSDK WMI namespace)
 .LINK
   CCM_SoftwareUpdate: https://docs.microsoft.com/en-us/sccm/develop/reference/core/clients/sdk/ccm_softwareupdate-client-wmi-class
   CCM_SoftwareUpdatesManager: https://docs.microsoft.com/en-us/sccm/develop/reference/core/clients/sdk/ccm_softwareupdatesmanager-client-wmi-class
   install all missing SCCM Updates (client side): https://gallery.technet.microsoft.com/scriptcenter/Install-All-Missing-8ffbd525
   check for pending reboots: https://github.com/bcwilhite/PendingReboot/blob/master/Public/Test-PendingReboot.ps1
#>
function Install-SCCMUpdates {
 [cmdletbinding()]
 param(
   $Computer = "localhost"
 )


 Set-StrictMode -Version 2
 $ErrorActionPreference = "Stop"

 $wmiCCMSDK = "root\CCM\ClientSDK"
 $scriptName = $MyInvocation.MyCommand.Name
 Write-Verbose "$scriptName ..."

   function Test-WMIAccess {

   param (
       $ComputerName
   )

   $wmicheck = Get-WmiObject -ComputerName $ComputerName -namespace root\cimv2 -Class Win32_BIOS -ErrorAction SilentlyContinue
   if ($wmicheck) {
     Write-Verbose "Test-WMIAccess - success"
     return $true
   }
   else {
     Write-Verbose "Test-WMIAccess - failure"
     return $false
   }
 } # End of Function Test-WMIAccess

if (-Not (Test-WMIAccess -ComputerName $Computer)) {
   throw "unable to contact WMI provider"
}

function Get-CCMUpdates {
   [cmdletbinding()]
   param (
     $ComputerName,
     $Namespace
   )
   # Get list of all instances of CCM_SoftwareUpdate from root\CCM\ClientSDK for missing updates
   Get-WmiObject -ComputerName $ComputerName -Namespace $Namespace -Class CCM_SoftwareUpdate -Filter ComplianceState=0 -ErrorAction Stop
 }

   function Install-CCMUpdates {
   [cmdletbinding()]
   param (
     $ComputerName,
     $UpdateElements,
     $Namespace
   )
   $UpdatesReformatted = @($UpdateElements | ForEach-Object {
       if ($_.ComplianceState -eq 0) {[WMI]$_.__PATH}
     })
   # The following is the invoke of the CCM_SoftwareUpdatesManager.InstallUpdates with our found updates
   # NOTE: the command in the ArgumentList is intentional, as it flattens the Object into a System.Array for us
   # The WMI method requires it in this format. (https://gallery.technet.microsoft.com/scriptcenter/Install-All-Missing-8ffbd525)
   Invoke-WmiMethod -ComputerName $ComputerName -Class CCM_SoftwareUpdatesManager -Name InstallUpdates -ArgumentList (, $UpdatesReformatted) -Namespace $Namespace
 }

 function Wait-ForCCMUpdatesToFinish {
   [cmdletbinding()]
   param(
     $ComputerName,
     $Namespace
   )
   <#
     https://docs.microsoft.com/en-us/sccm/develop/reference/core/clients/sdk/ccm_softwareupdate-client-wmi-class
     EvaulationState:
       0 ciJobStateNone
       1 ciJobStateAvailable
       2 ciJobStateSubmitted
       3 ciJobStateDetecting
       4 ciJobStatePreDownload
       5 ciJobStateDownloading
       6 ciJobStateWaitInstall
       7 ciJobStateInstalling
       8 ciJobStatePendingSoftReboot
       9 ciJobStatePendingHardReboot
       10  ciJobStateWaitReboot
       11  ciJobStateVerifying
       12  ciJobStateInstallComplete
       13  ciJobStateError
       14  ciJobStateWaitServiceWindow
       15  ciJobStateWaitUserLogon
       16  ciJobStateWaitUserLogoff
       17  ciJobStateWaitJobUserLogon
       18  ciJobStateWaitUserReconnect
       19  ciJobStatePendingUserLogoff
       20  ciJobStatePendingUpdate
       21  ciJobStateWaitingRetry
       22  ciJobStateWaitPresModeOff
       23  ciJobStateWaitForOrchestration
   #>
   $finishStates = @(8, 9, 10, 12, 13, 19)
   do {
     $updates = Get-WmiObject -ComputerName $ComputerName -Class CCM_SoftwareUpdate -Namespace $Namespace -Filter ComplianceState=0
     $updates | Foreach-Object {
       Write-Progress -Activity $_.Name -PercentComplete $_.PercentComplete
       Start-Sleep -Seconds 1
     }
     Start-Sleep -Seconds 1
     Write-Host "[$($updates.PercentComplete)]% - EvaluationState [$($updates.EvaluationState)]"
     $stateFinished = $true
     foreach ($state in $updates.EvaluationState) {
       if (-Not ($finishStates -contains $state)) {
         $stateFinished = $false
         break;
       }
     }
     # yup, $updates.PercentComplete is an array, but "-ne" will acts as a filter function
   } while (($updates.PercentComplete -ne 100) -And (-Not $stateFinished))
 } #End Function Wait-ForCCMUpdatesToFinish

 $updates = Get-CCMUpdates -ComputerName $Computer -Namespace $wmiCCMSDK

  
 $updatesState =@()
 $updatesName =@()

  ForEach ($update in $updates) {
   #Write-Verbose $_
   $updatesName += $update.Name
   $updatesState += $update.EvaluationState
 }

 $updateProps = @{
   ApprovedUpdates = ($updates | Measure-Object).Count
   PendingPatches  = ($updates | Where-Object { $updates.EvaluationState -ne 8 } | Measure-Object).Count
   RebootPending   = ($updates | Where-Object { $updates.EvaluationState -eq 8 } | Measure-Object).Count
 }
 Write-Host " ApprovedUpdates: $($updateProps.ApprovedUpdates) "
 Write-Host "  PendingPatches: $($updateProps.PendingPatches) "
 Write-Host "   RebootPending: $($updateProps.RebootPending) "

 $res = @{
   updateInfo    = $updateProps
   result        = $null
   rebootPending = $false
 }

 if ($updateProps.PendingPatches -gt 0) {
   try {
     $res.result = Install-CCMUpdates -ComputerName $Computer -UpdateElements $updates -Namespace $wmiCCMSDK
     Wait-ForCCMUpdatesToFinish -ComputerName $Computer -Namespace $wmiCCMSDK
   }
   catch {
     throw "failed to install updates."
   }
 }
 else {
   Write-Host " > no updates pending < " -ForegroundColor Green
 }
 if ($res.result) {
   Write-Verbose $res.result
 }

 <#
 Test-PendingReboot https://github.com/bcwilhite/PendingReboot/blob/master/Public/Test-PendingReboot.ps1
   .SYNOPSIS
     Test the pending reboot status on a local and/or remote computer.
   .NOTES
     Author:  Brian Wilhite
     Email:   bcwilhite (at) live.com
 #>
 function Test-PendingReboot {
   [CmdletBinding()]
   param(
     [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
     [Alias("CN", "Computer")]
     [String[]]
     $ComputerName = $env:COMPUTERNAME,

     [Parameter()]
     [System.Management.Automation.PSCredential]
     [System.Management.Automation.CredentialAttribute()]
     $Credential,

     [Parameter()]
     [Switch]
     $Detailed,

     [Parameter()]
     [Switch]
     $SkipConfigurationManagerClientCheck,

     [Parameter()]
     [Switch]
     $SkipPendingFileRenameOperationsCheck
   )

   process {
     foreach ($computer in $ComputerName) {
       try {
         $invokeWmiMethodParameters = @{
           Namespace    = 'root/default'
           Class        = 'StdRegProv'
           Name         = 'EnumKey'
           ComputerName = $computer
           ErrorAction  = 'Stop'
         }

         $hklm = [UInt32] "0x80000002"

         if ($PSBoundParameters.ContainsKey('Credential')) {
           $invokeWmiMethodParameters.Credential = $Credential
         }

         ## Query the Component Based Servicing Reg Key
         $invokeWmiMethodParameters.ArgumentList = @($hklm, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\')
         $registryComponentBasedServicing = (Invoke-WmiMethod @invokeWmiMethodParameters).sNames -contains 'RebootPending'

         ## Query WUAU from the registry
         $invokeWmiMethodParameters.ArgumentList = @($hklm, 'SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\')
         $registryWindowsUpdateAutoUpdate = (Invoke-WmiMethod @invokeWmiMethodParameters).sNames -contains 'RebootRequired'

         ## Query JoinDomain key from the registry - These keys are present if pending a reboot from a domain join operation
         $invokeWmiMethodParameters.ArgumentList = @($hklm, 'SYSTEM\CurrentControlSet\Services\Netlogon')
         $registryNetlogon = (Invoke-WmiMethod @invokeWmiMethodParameters).sNames
         $pendingDomainJoin = ($registryNetlogon -contains 'JoinDomain') -or ($registryNetlogon -contains 'AvoidSpnSet')

         ## Query ComputerName and ActiveComputerName from the registry and setting the MethodName to GetMultiStringValue
         $invokeWmiMethodParameters.Name = 'GetMultiStringValue'
         $invokeWmiMethodParameters.ArgumentList = @($hklm, 'SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName\', 'ComputerName')
         $registryActiveComputerName = Invoke-WmiMethod @invokeWmiMethodParameters

         $invokeWmiMethodParameters.ArgumentList = @($hklm, 'SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName\', 'ComputerName')
         $registryComputerName = Invoke-WmiMethod @invokeWmiMethodParameters

         $pendingComputerRename = $registryActiveComputerName -ne $registryComputerName -or $pendingDomainJoin

         ## Query PendingFileRenameOperations from the registry
         if (-not $PSBoundParameters.ContainsKey('SkipPendingFileRenameOperationsCheck')) {
           $invokeWmiMethodParameters.ArgumentList = @($hklm, 'SYSTEM\CurrentControlSet\Control\Session Manager\', 'PendingFileRenameOperations')
           $registryPendingFileRenameOperations = (Invoke-WmiMethod @invokeWmiMethodParameters).sValue
           $registryPendingFileRenameOperationsBool = [bool]$registryPendingFileRenameOperations
         }

         ## Query ClientSDK for pending reboot status, unless SkipConfigurationManagerClientCheck is present
         if (-not $PSBoundParameters.ContainsKey('SkipConfigurationManagerClientCheck')) {
           $invokeWmiMethodParameters.NameSpace = 'ROOT\ccm\ClientSDK'
           $invokeWmiMethodParameters.Class = 'CCM_ClientUtilities'
           $invokeWmiMethodParameters.Name = 'DetermineifRebootPending'
           $invokeWmiMethodParameters.Remove('ArgumentList')

           try {
             $sccmClientSDK = Invoke-WmiMethod @invokeWmiMethodParameters
             $systemCenterConfigManager = $sccmClientSDK.ReturnValue -eq 0 -and ($sccmClientSDK.IsHardRebootPending -or $sccmClientSDK.RebootPending)
           }
           catch {
             $systemCenterConfigManager = $null
             Write-Verbose -Message ($script:localizedData.invokeWmiClientSDKError -f $computer)
           }
         }

         $isRebootPending = $registryComponentBasedServicing -or `
           $pendingComputerRename -or `
           $pendingDomainJoin -or `
           $registryPendingFileRenameOperationsBool -or `
           $systemCenterConfigManager -or `
           $registryWindowsUpdateAutoUpdate

         if ($PSBoundParameters.ContainsKey('Detailed')) {
           [PSCustomObject]@{
             ComputerName                     = $computer
             ComponentBasedServicing          = $registryComponentBasedServicing
             PendingComputerRenameDomainJoin  = $pendingComputerRename
             PendingFileRenameOperations      = $registryPendingFileRenameOperationsBool
             PendingFileRenameOperationsValue = $registryPendingFileRenameOperations
             SystemCenterConfigManager        = $systemCenterConfigManager
             WindowsUpdateAutoUpdate          = $registryWindowsUpdateAutoUpdate
             IsRebootPending                  = $isRebootPending
           }
         }
         else {
           [PSCustomObject]@{
             ComputerName    = $computer
             IsRebootPending = $isRebootPending
           }
         }
       }

       catch {
         Write-Verbose "$Computer`: $_"
       }
     }
   }
 }

 $res.rebootPending = (Test-PendingReboot -ComputerName $Computer).IsRebootPending
 if ($res.rebootPending) {
   Write-Host " > REBOOT PENDING < " -ForegroundColor Yellow
 }
 Write-Output $res

 #Make a lookup table to convert number to word state
 $lookupState = @{

   "0" = "ciJobStateNone"
   "8" = "ciJobStatePendingSoftReboot"
   "9" = "ciJobStatePendingHardReboot"
   "10" = "ciJobStateWaitReboot"
   "12" = "ciJobStateInstallComplete"
   "13" = "ciJobStateError"
   "19" = "ciJobStatePendingUserLogoff"

   }
   $updatesStateLabel =@()

   #Converting numbers to word state
   foreach ($state in $updatesState) {

   $updatesStateLabel += $lookupState["$state"]

   }

 $returndata = @{
   computerName = $env:computername
   updatesName = $updatesName
   updatesCount = $updatesName.count
   updatesState = $updatesStatelabel
   RebootPending = $res.rebootPending
 }

 #Return Value
 return $returndata

}

Function write-applog {

 param(
     [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    
     $Source = 'PatchAutomation',

     [Parameter()]
    
     $EventID = 3001,

     [Parameter()]
    
     $LogName = 'Application',

    
     [Parameter()]
    
     $EntryType = 'Information',

     [Parameter()]
    
     $Message

   )

    # add event source if it doesn't exist
  if(!([System.Diagnostics.EventLog]::SourceExists("$Source"))){New-EventLog -LogName "$LogName" -Source "$Source"}
  # write events to the log  
  Write-EventLog -LogName $LogName -Source $Source -EventID $EventID -EntryType $EntryType -Message $Message

}

#Calling Function
$resultData = Install-SCCMUpdates -Computer localhost

$Outpath = "c:\UpdatesInstallTest"
if (!(test-path $Outpath)) {

new-item -Path $Outpath -ItemType "directory"
} else {

     # remove old patching log file if is exists
     if(Get-ChildItem -Path $Outpath\*ResultData.txt){Get-ChildItem -Path $Outpath\*ResultData.txt | Remove-Item}


}



$timestamp = get-date -Format yyyyMMddhhmmss

$Filename = "$timestamp`_ResultData.txt"

$Outpathfile = join-path -Path $Outpath -ChildPath $Filename

$resultData | Out-File -FilePath $Outpathfile

write-applog -Message $resultData
