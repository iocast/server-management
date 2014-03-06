
Write-Host 'This script will automatically restart you computer.'

$policy = Get-ExecutionPolicy
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force


Write-Host 'Going to install needed feature'
# installes Server Manager module
Dism.exe /Online /Enable-Feature /FeatureName:ServerManager-PSH-Cmdlets

Import-Module ServerManager
Install-WindowsFeature -name FS-FileServer
Install-WindowsFeature -name FS-Resource-Manager
Install-WindowsFeature -name RSAT-AD-AdminCenter
# Server for NFS enables this computer to share files with UNIX-based computers and other computers that use the network file system (NFS) protocol.
#Install-WindowsFeature -name FS-NFS-Service


[string]$domain = Read-Host 'Enter domain'
[string]$oupath = Read-Host 'Enter organization unit path'
[string]$server = Read-Host 'Enter servername'
[string]$user = Read-Host 'Enter your ad user name'

Add-Computer -Credential $user -DomainName $domain -NewName $server -OUPath $oupath


Set-ExecutionPolicy -ExecutionPolicy $policy -Force

Restart-Computer -Force
