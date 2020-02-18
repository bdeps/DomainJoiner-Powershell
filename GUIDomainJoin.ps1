#---------------------------------------------------------[Initialisations]--------------------------------------------------------
# Init PowerShell Gui
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

## Set the script execution policy for this process
Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

#---------------------------------------------------------[Variables]--------------------------------------------------------
$global:domainName = ""
$global:newComputerName = ""
$global:ouPath = ""
$global:domainCredentials = ""
## Laptop/Desktop - Used for AD Groups
$global:computerType = ""
$regInstallation = "SigmaIT\DomainJoiner"





#---------------------------------------------------------[Change Area Below]-------------------------------------------------
## Edit this to change what domains you can join
$availableDomains = 'contoso.com','contoso2.com'
$domain1 = 'contoso.com'
$domain2 = 'contoso2.com'

## Edit the name of the corporation here (Example, Volvo)
$corporateName = 'Sigma IT'

## Enter the local admin domain group used
$domainLocalAdmins = 'LINE\LIAL_G_PC_ADMIN'
#---------------------------------------------------------[Change Area Above]-------------------------------------------------





#---------------------------------------------------------[Form]--------------------------------------------------------

[System.Windows.Forms.Application]::EnableVisualStyles()

## Main Window
$DomainJoinerForm = New-Object System.Windows.Forms.Form
$DomainJoinerForm.ClientSize = '350,200'
$DomainJoinerForm.Text = $corporateName
$DomainJoinerForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$DomainJoinerForm.TopMost = $true

# main Window Description
$domainJoinerDescription = New-Object System.Windows.Forms.Label
$domainJoinerDescription.Text = "Please fill the fields"
$domainJoinerDescription.AutoSize = $false
$domainJoinerDescription.Width = 220
$domainJoinerDescription.Height = 20
$domainJoinerDescription.Location = New-Object System.Drawing.Point(100,30)
$domainJoinerDescription.Font = 'Microsoft Sans Serif,8'

## Domain dropdown
$domainPicker = New-Object System.Windows.Forms.ComboBox
$domainPicker.Text = ""
$domainPicker.Width = 180
$domainPicker.Height = 20
@($availableDomains) | ForEach-Object{[void] $domainPicker.Items.Add($_)}
$domainPicker.SelectedIndex = 0
$domainPicker.Location = New-Object System.Drawing.Point(100,50)
$domainPicker.Visible = $true
$domainPicker.DropDownStyle = 'DropDownList'

## Domain Dropdown Description
$domainPickerDescription = New-Object System.Windows.Forms.Label
$domainPickerDescription.Text = "Domain:"
$domainPickerDescription.AutoSize = $false
$domainPickerDescription.Width = 50
$domainPickerDescription.Height = 20
$domainPickerDescription.Location = New-Object System.Drawing.Point(50,54)

## Computer name input
$computerNameBox = New-Object System.Windows.Forms.TextBox
$computerNameBox.Text = "Enter new computer name"
$computerNameBox.Width = 180
$computerNameBox.Height = 20
$computerNameBox.Location = New-Object System.Drawing.Point(100,80)

## Computer name input description
$computerNameBoxDescription = New-Object System.Windows.Forms.Label
$computerNameBoxDescription.Text = "Computer Name:"
$computerNameBoxDescription.AutoSize = $false
$computerNameBoxDescription.Width = 150
$computerNameBoxDescription.Height = 20
$computerNameBoxDescription.Location = New-Object System.Drawing.Point(10,84)

## Validate Button
$validateInputBtn = New-Object System.Windows.Forms.Button
$validateInputBtn.Text = "Validate"
$validateInputBtn.AutoSize = $false
$validateInputBtn.Width = 90
$validateInputBtn.Height = 20
$validateInputBtn.Location = New-Object System.Drawing.Point(100,150)

## Domain Join Button
$domainJoinBtn = New-Object System.Windows.Forms.Button
$domainJoinBtn.Text = "Join"
$domainJoinBtn.Width = 90
$domainJoinBtn.Height = 20
$domainJoinBtn.Location = New-Object System.Drawing.Point(200,150)
$domainJoinBtn.Visible = $false

## Activate all set objects
$DomainJoinerForm.controls.AddRange(@($domainJoinerDescription,$domainPicker,$domainPickerDescription,$computerNameBox,$computerNameBoxDescription,$validateInputBtn,$domainJoinBtn))

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

#-----------------------------------------------------------[Functions]------------------------------------------------------------
Function postJoinActionsPreparation{
    ## Actions after the domain was Successfully Joined
    $progressFormDescription.Text = "Creating Directories for postJoinActions"
    Start-Sleep -Seconds 2

    ## Creating folders and copying in the follow up script that will install the CM-client 
    $postJoinScriptPath = "C:\IT"
    
    if(!(Test-Path $postJoinScriptPath)){
        New-Item -Path "C:\" -Name "IT" -ItemType "Directory"
    }
    Start-Sleep -Seconds 3

    ## Gets Path if the file is compiled to an EXE
    $scriptPath = ".\postJoinActions.exe"
    Copy-Item -Path $scriptPath -Destination $postJoinScriptPath -Force

    $progressFormDescription.Text = "Directory and Script copy succeded"
    Start-Sleep -Seconds 2

    ## Setting up a single autologon. Password is immediately discarded and removed from registry after a restart
    $progressFormDescription.Text = "Setting up one autologin"
    $tempPass = $global:domainCredentials.GetNetworkCredential().Password
    Set-AutoLogon -DefaultUsername $global:domainCredentials.UserName -DefaultPassword $tempPass -AutoLogonCount 1 -Script "c:\it\postJoinActions.exe"
    $tempPass = ""
    Start-Sleep -Seconds 2

    $progressFormDescription.Text = "Setting up local Admin"
    ## Adding $domainCredentials account to local admin group
    $adminGroupName = gwmi win32_group -filter "LocalAccount = $TRUE And SID = 'S-1-5-32-544'" | select -expand name
    
    ## Adding LIAL_G_PC_ADMIN as a local admin group 
    net localgroup $adminGroupName $domainLocalAdmins /add
    Start-Sleep -Seconds 2
    $progressFormDescription.Text = "Local Admin Setup Complete"
    Start-Sleep -Seconds 2

    $progressFormDescription.Text = "First phase complete. 
    The computer will now restart in 10 sconds and commence the second phase"
    Start-Sleep -Seconds 10
    
    ## Closing the progression Form
    $progressForm.Close()
    Restart-Computer
}



Function Set-AutoLogon{
<#
.Synopsis
Here is the PowerShell CmdLet that would enable AutoLogon next time when the server reboots.We could trigger a specific Script to execute after the server is back online after Auto Logon.
The CmdLet has the follwing parameter(s) and function(s).
-DefaultUsername : Provide the username that the system would use to login.
-DefaultPassword : Provide the Password for the DefaultUser provided.
-AutoLogonCount : Sets the number of times the system would reboot without asking for credentials.Default is 1.
-Script : Provide Full path of the script for execution after server reboot. Example : c:\test\run.bat

Mandatory Parameters 
-DefaultUsername 
-DefaultPassword 


.Description
Here is the PowerShell CmdLet that would enable AutoLogon next time when the server reboots.We could trigger a specific Script to execute after the server is back online after Auto Logon.

.Example
Set-AutoLogon -DefaultUsername "win\admin" -DefaultPassword "password123"

.Example
Set-AutoLogon -DefaultUsername "win\admin" -DefaultPassword "password123" -AutoLogonCount "3"


.EXAMPLE
Set-AutoLogon -DefaultUsername "win\admin" -DefaultPassword "password123" -Script "c:\test.bat"

#>
    [CmdletBinding()]
    Param(
        
        [Parameter(Mandatory=$True,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [String[]]$DefaultUsername,

        [Parameter(Mandatory=$True,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [String[]]$DefaultPassword,

        [Parameter(Mandatory=$False,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [AllowEmptyString()]
        [String[]]$AutoLogonCount,

        [Parameter(Mandatory=$False,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [AllowEmptyString()]
        [String[]]$Script
                
    )

    Begin
    {
        #Registry path declaration
        $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        $RegROPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    
    }
    
    Process
    {

        try
        {
            #setting registry values
            Set-ItemProperty $RegPath "AutoAdminLogon" -Value "1" -type String  
            Set-ItemProperty $RegPath "DefaultUsername" -Value "$DefaultUsername" -type String  
            Set-ItemProperty $RegPath "DefaultPassword" -Value "$DefaultPassword" -type String
            if($AutoLogonCount)
            {
                
                Set-ItemProperty $RegPath "AutoLogonCount" -Value "$AutoLogonCount" -type DWord
            
            }
            else
            {

                Set-ItemProperty $RegPath "AutoLogonCount" -Value "1" -type DWord

            }
            if($Script)
            {
                
                Set-ItemProperty $RegROPath "(Default)" -Value "$Script" -type String
            
            }
            else
            {
            
                Set-ItemProperty $RegROPath "(Default)" -Value "" -type String
            
            }        
        }

        catch
        {

            Write-Output "An error had occured $Error"
            
        }
    }
    
    End
    {
        
        #End

    }

}

## Validates all form entries
function validateInputFunction{

    ## Set Variables
    $global:domainName = $domainPicker.SelectedItem.ToString()
    $global:newComputerName = $computerNameBox.Text
    $global:credHelper = ""
    $global:ouPath = ""
    $global:computerType = ""
    $progressFormDescription.Text = "Initializing Settings"
    $domainJoinBtn.Visible = $false

    ## Check if a computer name has been entered
    if($global:newComputerName -eq "" -Or $global:newComputerName -eq "Enter new computer name"){
        [System.Windows.Forms.MessageBox]::Show('Please enter a computer name')
    }

    ## Checks and creates registry keys to keep track of domain during restart
    $registryPath = "HKLM:\Software\$regInstallation"
    $name = "DomainJoined"
    $value = ""
    if(!(Test-Path $registryPath)){
        New-Item -Path $registryPath -Force | Out-Null
    }

    ## Checks Domain and Initializes variables
    if($global:domainName -eq $domain1){
        ## Setting a registry value to check what domain was joined after restart
        New-ItemProperty -Path $registryPath -Name $name -Value $domain1 -PropertyType String -Force | Out-Null
    }
    elseif($global:domainName -eq $domain2){
        ## Setting a registry value to check what domain was joined after restart
        New-ItemProperty -Path $registryPath -Name $name -Value $domain2 -PropertyType String -Force | Out-Null
    }
    if(!($global:computerType -eq "")){
        ## If we were able to find a valid computer type, show domainJoinBtn
        $domainJoinBtn.Visible = $true
    }
}

## Removes the template text if the computerNameBox is selected
function focusComputerNameBox{
    if($computerNameBox.Text -eq 'Enter new computer name'){
        $computerNameBox.Text = ''
    }
}

## Adds the template text if computerNameBox was left empty
function lostFocusComputerNameBox{
    if($computerNameBox.Text -eq ''){
        $computerNameBox.Text = 'Enter new computer name'
    }
}

function joinDomain{

    ## Hiding main window and showing Progress Window
    $domainJoinerForm.Visible = $false

    $global:domainCredentials = Get-Credential -UserName "" -Message "Please enter your ActiveDirectory Admin Account"
    $progressForm.Visible = $true

    Start-Sleep -Seconds 2

    if($global:newComputerName -eq $env:COMPUTERNAME){
        try{
            $progressFormDescription.Text = "Attempting to join the Domain"
            ## Crashes if you specify OU Path
            Add-Computer -DomainName $global:domainName -Credential $global:domainCredentials -Options JoinWithNewName,accountcreate -WarningAction SilentlyContinue -ErrorAction Stop
        }
        catch{
            $string_Err = $_ | Out-String
            [System.Windows.Forms.MessageBox]::Show($string_Err)
            Start-Sleep -Seconds 20
            Exit
        }
    }
    else{
        try{
            $progressFormDescription.Text = "Attempting to rename Computer"
            Rename-Computer -NewName $global:newComputerName -Force -WarningAction SilentlyContinue
            Start-Sleep -Seconds 8

            ## There is a bug in Windows Servers 2012 R2 DC causing the renaming to fail. Uncomment this line when you have 2016 DCs
            ## https://support.microsoft.com/sv-se/help/3152220/directory-service-is-busy-error-when-you-rename-a-domain-joined-comput
            ## Add-Computer -NewName $global:newComputerName -DomainName $global:domainName -Credential $global:credHelper -OUPath $global:ouPath -Options JoinWithNewName,accountcreate -ErrorAction Stop

            $progressFormDescription.Text = "Attempting to join the Domain"
            Start-Sleep -Seconds 5
            ## Crashes if you specify OU Path
            Add-Computer -Credential $global:domainCredentials -DomainName $global:domainName -Options AccountCreate, JoinWithNewName -WarningAction SilentlyContinue -ErrorAction Stop
            Start-Sleep -Seconds 5

        }
        catch{
            $string_Err = $_ | Out-String
            [System.Windows.Forms.MessageBox]::Show($string_Err)
            Start-Sleep -Seconds 20
            Exit
        }
    }
    
    ## Domain successfully joined
    $progressFormDescription.Text = "Domain joined Successfully"
    Start-Sleep -Seconds 2
    ## Initiates preparation for restart och CM-client install
    postJoinActionsPreparation
}

#-----------------------------------------------------------[Bindings]------------------------------------------------------------
## Binds click event to validateInputBtn
$validateInputBtn.Add_Click({ validateInputFunction })

## Binds OnFocus event to computerNameBox
$computerNameBox.Add_GotFocus({ focusComputerNameBox })

## Binds LostFocus event to computerNameBox
$computerNameBox.Add_LostFocus({ lostFocusComputerNameBox })

## Bind the joinDomain event to joinDomainBtn
$domainJoinBtn.Add_Click({ joinDomain })

[void]$DomainJoinerForm.ShowDialog()
