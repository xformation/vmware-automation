PARAM (
	[Parameter(Mandatory = $true, HelpMessage = "You must specify the full path of the INI file")]
	[ValidateScript({ Test-Path -Path $_ })]
	$iniPath)

$iniContent = ConvertFrom-StringData((Get-Content $iniPath) -join "`n")
#Write-Host ($iniContent | Out-String) -ForegroundColor Red
#$Records = Import-CSV $csvPath
$Records | foreach {
	Write-Output $_  `n 
}
cd -Path "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts"
.\Initialize-PowerCLIEnvironment.ps1
Add-PSSnapin "VMware.VimAutomation.Core" | Out-Null
Connect-VIServer -Server $iniContent.vcenter_host -Protocol https -User $iniContent.vcenter_user -Password $iniContent.vcenter_password
$Datastores = "Datastore*"
$VMXFile = "*.vmx"
$ESXHost = "10.10.10.8"
foreach($Datastore in Get-Datastore $Datastores) {
   # Set up Search for .VMX Files in Datastore
   $ds = Get-Datastore -Name $Datastore | %{Get-View $_.Id}
   $SearchSpec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
   $SearchSpec.matchpattern = "*.vmx"
   $dsBrowser = Get-View $ds.browser
   $DatastorePath = "[" + $ds.Summary.Name + "]"
 
   # Find all .VMX file paths in Datastore, filtering out ones with .snapshot (Useful for NetApp NFS)
   $SearchResult = $dsBrowser.SearchDatastoreSubFolders($DatastorePath, $SearchSpec) | where {$_.FolderPath -notmatch ".snapshot"} | %{$_.FolderPath + ($_.File | select Path).Path}
 
   #Register all .vmx Files as VMs on the datastore
   foreach($VMXFile in $SearchResult) {
      New-VM -VMFilePath $VMXFile -VMHost $ESXHost  -RunAsync
   }
}