<#	
	.NOTES
	===========================================================================
	 Created on:   	13/01/2018 01:02 PM
	 Created by:   	Mohammed Zubair Bhojani
	 Organization:  Synectiks
	 Filename:Vmcreation.ps1    	
	===========================================================================
	.DESCRIPTION
		A description of the file.
	It will take the VM's information from CSV file and will provision the VM's 
#>
#Just take input as full path of the CSV file
PARAM (
	[Parameter(Mandatory = $true, HelpMessage = "You must specify the full path of the INI file")]
	[ValidateScript({ Test-Path -Path $_ })]
	$iniPath,
	[Parameter(Mandatory = $true, HelpMessage = "You must specify the full path of the CSV file")]
	[ValidateScript({ Test-Path -Path $_ })]
	$csvPath)
$iniContent = ConvertFrom-StringData((Get-Content $iniPath) -join "`n")
#Write-Host ($iniContent | Out-String) -ForegroundColor Red
$Records = Import-CSV $csvPath
$Records | foreach {
	Write-Output $_  `n 
}
cd -Path "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts"
.\Initialize-PowerCLIEnvironment.ps1
Add-PSSnapin "VMware.VimAutomation.Core" | Out-Null
Connect-VIServer -Server $iniContent.vcenter_host -Protocol https -User $iniContent.vcenter_user -Password $iniContent.vcenter_password
$Records | foreach { 
	Write-Output $_.ipAddress $_.vmname $_.templateName $_.physicalHost $_.dataStore $_.vmnetwork $_.  
	New-VM -Name $_.vmname -Template $_.templateName -VMHost  $_.physicalHost -Datastore $_.dataStore   -RunAsync
}
#guest password initialized - simple string dont work
$guestUser = $iniContent.vm_user
$guestPassword = $iniContent.vm_password

#Lets start and wait
$Records | foreach {
	#lets wait untill the vm is created
	#changes for https://medfusion.atlassian.net/browse/DEVOPS-190 - keep pinging the hosts unless start 
	While  (!(Get-VM $_.vmname).NumCpu) 
	{
        
		Write-Host “Waiting to start .....” $_.vmname -ForegroundColor Red
		Start-Sleep -milliseconds 10000
	}
	#$vm = Get-View -ViewType VirtualMachine -Filter @{ "Name" = $_.vmname }
	#set the memory -- in NewVM call it should have worked , but it does not
	get-vm $_.vmname | Set-VM -MemoryMB $_.MemoryMB -Confirm:$false
    get-vm $_.vmname  | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $_.NetworkAdapters -Confirm:$false
	#lets pause a bit
	Sleep 5
	#start the vm
	Start-VM $_.vmname
	Sleep 10
	#lets check whether vmware tools is running
	while (((get-vm $_.vmname).ExtensionData.Guest.ToolsRunningStatus) -ne "guestToolsRunning")
	{
		Write-Host "....." -ForegroundColor Yellow
		Sleep 5
	}
    $myHostName = $_.vmname
	$myip = $_.ipAddress
	$myNetmask = $_.netmask
	$myGateway = $_.gateway
	$myDns1 = $_.dns1
    $myDns2 = $_.dns2
	$script = "/root/changescript.sh   $myHostName $myip  $myNetmask  $myGateway  $myDns1 $mydns2"
	Write-Host $script
	Invoke-VMScript -ScriptText $script -VM $_.vmname -GuestUser $guestUser  -GuestPassword $guestPassword
	#sometime this call to Invoke-VMScript failing - lets repeatedly attempt unless it pass
	while ($? -eq $false)
	{
		sleep 2
		Invoke-VMScript -ScriptText $script -VM $_.vmname -GuestUser $guestUser -GuestPassword $guestPassword
	}
}
