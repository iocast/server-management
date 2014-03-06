# File Server Management Tool

It is a clone of [the iocast's GitHub repository](https://github.com/iocast/file-server-management) with own configuration files.

## Installation

First you need to install at least **Windows Server 2012 R2 Standard**. Afterwards do the standard configurations such as

* defining a fix IP address,
* installing needed Applications,
* installing RAID specific drivers and software.


## Configuration

Before we register the Windows Server, as it is described in the IDES mail, we need to propagate the server to  the Active Directory and define a computer name. For that run the PowerShell script ```preperation.ps1``` as **Administrator**.

The script will ask you the following things:

* **Enter domain**: which is the domain name of your active directory service (e.g. d.ethz.ch)
* **Enter organization unit path**: which is the path inside the active directory to which the server need to be added (e.g. OU=servers,OU=plus,OU=computers,OU=BAUG-IRL,OU=Hosting,DC=d,DC=ethz,DC=ch)
* **Enter servername**: is the new name of the server (e.g. irl-plus-s-001)
* **Enter your ad user name**: is the active directory user, who has the right to add and change objects (e.g. irlit)

After you have provided all the informations above, you should get a **prompt** where you need to enter the **password** of the provided user. In addition, this scripts install a needed Windows features automatically such as file server, resource manager, active directory services, etc. Once the script has done its job, it will **automatically restart** your system. After the restart your system should be registered in the active directroy and your server name should be changed.

## Share Managment

Sharing has two different flavours. On the one hand you could create new shares based on a configuration file, and on the other hand you could create shares based on a active directory group. The latter is used for creating user shares, that means it creates for each member of a group a new folder inside a defined folder and sets the configured permissions whereas the member becomes full controll rights.

Now lets first take a look on the "simple" sharing script.

### Share Point

You need to run the script as administrator

	perms_share_mgmt.ps1 -config .\configs\shares_irl-plus-s-001.json -force
	perms_share_mgmt.ps1 -config .\configs\shares_irl-plus-s-001-projects.json -force
	perms_share_mgmt.ps1 -config .\configs\shares_irl-plus-s-001-masrp.json -force


### User Shares

You need to run the script as administrator

	user_network_share.ps1 config .\configs\network_share.json -force


## Copying files

**mirror**

	robocopy <source> <destination> /MIR /XD "<source>/<path>/<to>/<folder>"

	XD
		exluding directories


