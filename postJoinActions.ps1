#---------------------------------------------------------[Initialisations]--------------------------------------------------------
# Init PowerShell Gui
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

## Set the script execution policy for this process
Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}




#---------------------------------------------------------[Change Area Below]-------------------------------------------------
## Add path to the clienthealth script for SCCM-agent installation (we are domain joined at this point and will be running with your admin credentials. We can access servers on the domain)
## Example path below
$global:sCCMClientHealthPath = "\\servername\clienthealth\install.cmd"

## AD-Groups that the computer object should be members of
$global:computerAdGroup = "AD_GROUP_Office365"

## Add the domain names (same names as in the GUIDomainJoin.ps1. It will check the registry value what domain was joined 
## Since we dont have the AD-module it's a quick way to check
$global:domain1 = ""
$global:domain2 = ""

## Add the OU-Path where the computer-object should be moved to for each domain
## Example: "OU=DeployedComputers,OU=Corporate,DC=Contoso,DC=com"
$global:domain1ComputerOuPath1 = ""
$global:domain1ComputerOuPath2 = ""

#---------------------------------------------------------[Change Area Above]-------------------------------------------------







#---------------------------------------------------------[Variables]--------------------------------------------------------------
$global:registryPath = "HKLM:\Software\SigmaIT\DomainJoiner"
$global:name = "DomainJoined"
$global:sccmInstallFile = Split-Path -Path $global:sCCMClientHealthPath -leaf

#---------------------------------------------------------[Form]--------------------------------------------------------
[System.Windows.Forms.Application]::EnableVisualStyles()

## Progress Window
$progressForm = New-Object System.Windows.Forms.Form
$progressForm.ClientSize = '350,100'
$progressForm.Text = "Sigma Domain Joiner"
$progressForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$progressForm.Visible = $false
$progressForm.TopMost = $true

## Progress Window Description
$progressFormDescription = New-Object System.Windows.Forms.Label
$progressFormDescription.Text = ""
$progressFormDescription.Width = 350
$progressFormDescription.Height = 100
$progressFormDescription.AutoSize = $false
$progressFormDescription.TextAlign = 'MiddleCenter'

## Progress Window Bind
$progressForm.controls.AddRange(@($progressFormDescription))

[void]$progressForm.Show()

#-----------------------------------------------------------[Functions]------------------------------------------------------------

## ADSI function to add AD groups to users/computers
function addToADGroup([string]$groupName,[string]$account){
    $progressFormDescription.Text = 'Adding computer to AD Group'
    Start-Sleep -Seconds 2

    $accountDn = $null
    $addtogroupDn = $null
    ## computer requires $
        if(!($accountDn = ([ADSISEARCHER]"sAMAccountName=$($account)").FindOne().Path)){$accountDn = ([ADSISEARCHER]"sAMAccountName=$($account)$").FindOne().Path}
        $addtogroupDn = ([ADSISEARCHER]"sAMAccountName=$($groupName)").FindOne().Path
        $group = [ADSI]"$addtogroupDn"
            if(!($group.IsMember($accountDn))) {
                # add to group
                $group.Add($accountDn)
                $progressFormDescription.Text = "$account added to $groupName"
                Start-Sleep -Seconds 2
                }
                else{
                    # already member of group
                    $progressFormDescription.Text = 'Already a member of group'
                    Start-Sleep -Seconds 2
                }
}

## Installs the CCM client through the ClientHealth script. Path needs to be set in the variable change area.
function installSCCMClient{
    $progressFormDescription.Text = 'Installing SCCM Client. This might take up to 10 minutes'
    Copy-Item $global:sCCMClientHealthPath 'c:\it'
    Start-Sleep -Seconds 2
    Start-Process -Verb RunAs -Wait cmd.exe -Args '/c', "c:\it\$global:sccmInstallFile"
    $progressFormDescription.Text = "SCCM Client installation complete"
    Start-Sleep -Seconds 2

    ## Remove default login user
    $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    Set-ItemProperty $RegPath "DefaultUsername" -Value "" -type String 
}

## moveComputerOU - moves the computer the script is being run on to the target ou
## enter a new OU with the following syntax: "OU=Users,OU=Ship Info Screen,OU=Test,OU=Offshore,OU=ISOLATION,OU=Corporate,DC=line,DC=stenanet, DC=com"
## If you get referral errors please double check the OU path.
function moveComputerOU([string]$newOU){
    # Retrieve DN of local computer.
    $SysInfo = New-Object -ComObject "ADSystemInfo"
    $ComputerDN = $SysInfo.GetType().InvokeMember("ComputerName", "GetProperty", $Null, $SysInfo, $Null)

    # Bind to computer object in AD.
    $Computer = [ADSI]"LDAP://$ComputerDN"

    # Bind to target OU.
    $OU = [ADSI]"LDAP://$newOU"

    # Move computer to target OU.
    $Computer.psbase.MoveTo($OU)
    $progressFormDescription.Text = "Moved Computer to DeployedComputers successfully"
}
#-----------------------------------------------------------[Actions]------------------------------------------------------------
$progressFormDescription.Text = "Checking Trust/Relationship"

## Wait for network connection before testing trust/relationship
Start-Sleep -Seconds 60

if((Test-ComputerSecureChannel) -eq $false){
    $progressFormDescription.Text = "Issue with Trust found. Attempting to repair"
    Test-ComputerSecureChannel -Repair
}

## Dekstop add
Start-Sleep -Seconds 2
$progressFormDescription.Text = "Adding computer to NoApplication AD-Group"
addToADGroup -groupName $global:computerAdGroup -account $env:COMPUTERNAME

## Installs the SCCM Client
installSCCMClient

Start-Sleep -Seconds 2
## Attempting to move the computer AD object to deployed computers
$progressFormDescription.Text = "Moving Computer to DeployedComputers"

##Check what domain is joined
if(((Get-ItemProperty -Path $global:registryPath -Name $global:name)).DomainJoined -eq $global:domain1){
    $progressFormDescription.Text = "Moving Computer to DeployedComputers in $global:domain1"
    moveComputerOU -newOU $global:domain1ComputerOuPath1
    Start-Sleep -Seconds 2
}
elseif(((Get-ItemProperty -Path $global:registryPath -Name $global:name)).DomainJoined -eq $global:domain2){
    $progressFormDescription.Text = "Moving Computer to DeployedComputers in $global:domain2"
    moveComputerOU -newOU $global:domain1ComputerOuPath2
    Start-Sleep -Seconds 2
}
else{
        $progressFormDescription.Text = "Unable to find registry value at HKLM:\Software\SigmaIT\DomainJoiner
        Client will not be moved"
        Start-Sleep -Seconds 5
}

## Restart computer
$progressFormDescription.Text = "Install complete. The computer will restart in 10 seconds"
Start-Sleep -Seconds 10
Restart-Computer