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

$domain = Get-ADDomainController -Credential $configuration.datasource.user

$members = Get-ADGroupMember -Identity $configuration.datasource.group -Credential $configuration.datasource.user

$groupMember = @{}

foreach ($member in $members) {
    $folder =  $configuration.datasource.home + "\" + $member.name
    $user = $domain.Domain + "\" + $member.name

    $new = $false
    
    $groupMember.Add($member.name, $false)

    if(!(Test-Path $folder)) {
        Write-Host "INFO: '$folder' does not exists. going to create it."
        
        New-Item -ItemType directory -Path $folder
        $new = $true
    }

    $groupMember.Set_Item($member.name, $true)

    if($new -or $configuration.rights.acl) {
        $uncFolder = Get-UNCPath $servername $folder

        $filePerm = Get-Acl $uncFolder
        $filePerm.Access | %{$filePerm.RemoveAccessRuleAll($_)}


        Write-Host "INFO: setting acl permissions to '$folder'"
        
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($configuration.rights.user, [System.Security.AccessControl.FileSystemRights]"FullControl", $InheritanceFlags, $PropagationFlags, $AccessControl)
        $filePerm.AddAccessRule($rule)
        $rule = New-Object System.Security.Principal.NTAccount($configuration.rights.user)
        $filePerm.SetOwner($rule)

        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($configuration.rights.group, [System.Security.AccessControl.FileSystemRights]"FullControl", $InheritanceFlags, $PropagationFlags, $AccessControl)
        $filePerm.AddAccessRule($rule)
        $rule = New-Object System.Security.Principal.NTAccount($configuration.rights.group)
        $filePerm.SetGroup($rule)
        
        
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($user, [System.Security.AccessControl.FileSystemRights]"FullControl", $InheritanceFlags, $PropagationFlags, $AccessControl)
        $filePerm.AddAccessRule($rule)

        foreach ($acl in $configuration.rights.acls) {
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($acl.owner, $acl.acl, $InheritanceFlags, $PropagationFlags, $acl.access)
            $filePerm.AddAccessRule($rule)
        }

        
        Write-Host "INFO: writing permissons to '$folder'"
        Set-Acl $uncFolder $filePerm
    }
}


$currentFolders = @{}
foreach ($current in (Get-ChildItem $configuration.datasource.home -Name -attributes D)) {
    $currentFolders.Add($current, $true)
}


foreach($key in $groupMember.Keys) {
    $currentFolders.Remove($key)
}


foreach($key in $currentFolders.Keys) {
    $folder =  $configuration.datasource.home + "\" + $key
    $archive = $configuration.datasource.archive + "\" + $key
    
    Write-Host "INFO: moving folder '$folder' to '$configuration.datasource.archive'"
    Move-Item $folder $configuration.datasource.archive

    Write-Host "INFO: changing acls on '$archive'"

    $uncArchive = Get-UNCPath $servername $archive

    $archivePerm = Get-Acl $uncArchive
    $archivePerm.Access | %{$archivePerm.RemoveAccessRuleAll($_)}

    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($configuration.rights.user, [System.Security.AccessControl.FileSystemRights]"FullControl", $InheritanceFlags, $PropagationFlags, $AccessControl)
    $archivePerm.AddAccessRule($rule)
    $rule = New-Object System.Security.Principal.NTAccount($configuration.rights.user)
    $archivePerm.SetOwner($rule)

    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($configuration.rights.group, [System.Security.AccessControl.FileSystemRights]"FullControl", $InheritanceFlags, $PropagationFlags, $AccessControl)
    $archivePerm.AddAccessRule($rule)
    $rule = New-Object System.Security.Principal.NTAccount($configuration.rights.group)
    $archivePerm.SetGroup($rule)
 
    foreach ($acl in $configuration.rights.acls) {
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($acl.owner, $acl.acl, $InheritanceFlags, $PropagationFlags, $acl.access)
        $archivePerm.AddAccessRule($rule)
    }


    Write-Host "INFO: writing permissons to '$archive'"
    Set-Acl $uncArchive $archivePerm
    
}

Set-ExecutionPolicy -ExecutionPolicy $policy -Force
