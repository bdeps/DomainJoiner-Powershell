# DomainJoiner-Powershell
Joins a domain with the client it's being run on. If you enter a new computername it will also change the name before joining.

After joining the domain there will be an automatic restart.
It will then automatically log in using your admin credentials and perform the post-join actions (installing sccm-client, adding the computer to AD-Groups and moving it to the correct ou)


<# Usage

I edited this down from a more hardcoded script and have not done a testrun of it yet. Please let me know if there are any bugs.

Currently supports 2 domains in different forests out of the box. I can make a single domain joiner aswell to reduce complexity and need for editing.


1. Open GUIDomainJoin.ps1
2. Edit the Change area (noted close to the top)
3. Open postJoinActions.ps1
4. Edit the change area (noted close to the top)
5. Compile both files to .exe (make sure admin priliveges are required to launch)
    I suggest using PS2EXE-GUI (https://gallery.technet.microsoft.com/scriptcenter/PS2EXE-GUI-Convert-e7cb69d5)
6. Run on the desired computer



#>