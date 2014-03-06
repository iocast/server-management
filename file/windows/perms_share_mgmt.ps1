param (
    [string]$config = $(throw "-config is required"),
    [switch]$force = $false
)


function Get-UNCPath {param([string]$HostName, [string]$LocalPath)
	$NewPath = $LocalPath -replace(":","$")
	#delete the trailing \, if found
	if ($NewPath.EndsWith("\")) {
		$NewPath = [Text.RegularExpressions.Regex]::Replace($NewPath, "\\$", "")
	}
	"\\$HostName\$NewPath"
}

$policy = Get-ExecutionPolicy
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force

$configuration = (Get-Content $config) -join "`n" | ConvertFrom-Json
$servername = (Get-Content env:computername)

$InheritanceFlags=[System.Security.AccessControl.InheritanceFlags]”ContainerInherit, ObjectInherit”
$PropagationFlags=[System.Security.AccessControl.PropagationFlags]”None”
$AccessControl=[System.Security.AccessControl.AccessControlType]”Allow”

foreach ($share in $configuration.shares) {
    $folder =  $configuration.general.local + "\" + $share.folder
    $uncFolder = Get-UNCPath $servername $folder

    if(!(Test-Path $folder)) {
        Write-Host "WARNING: '$folder' does not exists (continue doing my stuff)"
        continue;
    }

    $filePerm = Get-Acl $uncFolder
    $filePerm.Access | %{$filePerm.RemoveAccessRuleAll($_)}
    
    
    Write-Host "INFO: set protected and preserver inheritance on '$folder'"
    $filePerm.SetAccessRuleProtection($true, $false)
    

    if ($share.ownership) {
        Write-Host "INFO: setting ownership for '$folder'"
        
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($configuration.general.user, [System.Security.AccessControl.FileSystemRights]"FullControl", $InheritanceFlags, $PropagationFlags, $AccessControl)
        $filePerm.AddAccessRule($rule)
        $rule = New-Object System.Security.Principal.NTAccount($configuration.general.user)
        $filePerm.SetOwner($rule)

        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($configuration.general.group, [System.Security.AccessControl.FileSystemRights]"FullControl", $InheritanceFlags, $PropagationFlags, $AccessControl)
        $filePerm.AddAccessRule($rule)
        $rule = New-Object System.Security.Principal.NTAccount($configuration.general.group)
        $filePerm.SetGroup($rule)
        

        Write-Host "INFO: setting default acl for '$folder'"
        
        foreach ($perm in $configuration.general.permissions) {
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($perm, [System.Security.AccessControl.FileSystemRights]"FullControl", $InheritanceFlags, $PropagationFlags, $AccessControl)
            $filePerm.AddAccessRule($rule)
        }
    }


    if ($share.acl) {
        Write-Host "INFO: setting acl for '$folder'"

        foreach ($acl in $share.acls) {
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($acl.owner, $acl.acl, $InheritanceFlags, $PropagationFlags, $acl.access)
            $filePerm.AddAccessRule($rule)
        }
    }
    
    if ($share.ownership -or $share.acl) {
        Write-Host "INFO: writing permissons to '$folder'"
        Set-Acl $uncFolder $filePerm
    }
    
    if ($share.smb) {
        $shareName = $share.name
        Write-Host "INFO: setting share '$shareName' on '$folder'"

        if (Get-SmbShare -name $shareName -ErrorAction SilentlyContinue) {
            Write-Host "WARNGIN: Share exists. going to remove it"
            if($force) {
                Remove-SmbShare -name $shareName -Force
            } else {
                Remove-SmbShare -name $shareName
            }
        }
        
        New-SmbShare -Name $shareName -Path $folder -FolderEnumerationMode AccessBased

        # set share permissons
        Write-Host "INFO: Removing 'Everyone' on smb share '$shareName'"
        Revoke-SmbShareAccess -name $share.name -AccountName Everyone -Force

        Write-Host "INFO: Setting smb share permissions"
        foreach ($acl in $share.acls) {
            Grant-SmbShareAccess -name $shareName -AccountName $acl.owner -AccessRight $acl.share –Force
        }

    }

# apply the smb share acl to the file system acl
#Set-SmbPathAcl -ShareName "My Test 1"

}


Set-ExecutionPolicy -ExecutionPolicy $policy -Force

