<#

DISCLAIMER: This application is a sample application. The sample is provided "as is" without 
warranty of any kind. 

************
Created by: Luiz Tavares
email: luiz.tavares@inato.co.uk

************

************************
Pre-requisites
************************

1. This script will perform a search using SSH module for powershell to connect from a windows to a linux machine and 
	perform some operations to retrive data from a database in the host. You will require to install ssh modules. To
	do so you can use the find-modules ps command and import-it to your enviromment. 
2.	Also counting the fact that you already have some rights on the db and ssh enabled on your host.
	Refer to my other articles how to setup a ssh permissions and install database on linux machines. 
3. You will also require a wincsp modules to transfer files from linux to windows.
4. I will save all credentials on a xml, so create a xml file with the right tags its also important.

You will require AD priveliged access to perfom this task.Please refer to this article for more information:
https://docs.microsoft.com/en-us/windows-server/identity/ad-ds/plan/security-best-practices/appendix-b--privileged-accounts-and-groups-in-active-directory



Purpose of Script: 

Had to extract data from tsql database on a linux host, and trought the data perfom some operations on our ActiveDirectory
                                                            ^
Feel free to contact me if you need some assistance.Email: / \
                                                            |
#>

Import-Module -Name ActiveDirectory #import tha ad module.

#@Function helper

#function to load the ssh connection
function SshConnection {
    param (
        [string]$DestHost,
        [string]$key_path,
        [string]$key_pwd,
        [System.Management.Automation.PSCredential]$useradm_user_creds
    )
    
     New-SshSession -ComputerName $DestHost -KeyFile $key_path -KeyPass $key_pwd -Credential $useradm_user_creds # creates a new ssh session
     $SshSession = Get-SshSession -ComputerName $DestHost

        if($SshSession.Connected -eq $true){
            return $true
        }

        return $false
}

#function to invoke ssh commands on my host 
function InvokeSSh {
    param (
        [string]$DestHost,
        [string]$sQuery
    )
    

    Invoke-SshCommand -ComputerName $DestHost -Command $sQuery #invoking the command
    
    $sshResult = Invoke-SshCommand -ComputerName $DestHost -Command "[ -f /tmp/[filename].csv ] && echo 'file exists'" # the command will output to a file. checking the condition. name your file accordingly

    if ($sshResult.Result -eq "file exists"){
        return $true
    }else{
        return $false
    }
    
    return $false

}

#function to verify if user matches the requirements. on our DB its a repo of all users. 
#for this exercise we want to check a couple things more such as enabled or disabled state. 
function GetAdUser {
    param (
        [string]$user
    )
    $userStat = Get-ADUser -Identity $user

    if($userStat.Enabled -eq $true){

        return $true
    }
    return $false
}

#function to loop throw members of group 
function GetMembers {
    param (
        [string]$name,
        [string]$members

    )
    foreach($uid in $members){
    
        if ($name -notin $uid){
            if ((GetAdUser $name) -eq $true){
             return $true
            } 
        return $false
        }

    }
    
}

function GetWinSCPsession {
    param (
        [string]$DestHost,
        [string]$key_fingerprint,
        [System.Management.Automation.PSCredential]$winSCP_cred,
        [System.Security.SecureString]$skey_pwd,
        [string]$sskKeyFile               
    )

    $winScp_session = New-WinSCPSession -SessionOption (New-WinSCPSessionOption -HostName $DestHost -Protocol Sftp -SshHostKeyFingerprint $key_fingerprint `
    -Credential $winSCP_cred -SecurePrivateKeyPassphrase $skey_pwd -SshPrivateKeyPath $sskKeyFile) #create a wincsp session to copy file to a windows host.

    if($winScp_session.Opened -eq $true){
            return $winScp_session
    }

    return $false
    
}

#cleanup files on windows.
function PathExists {
    param (
        [string]$filepath
    )
    
    $path = $filepath
    if((Test-Path $path) -eq $true){
            return $true
    }
    return $false
}

#remove sessions
function ExitSession {
    param (
        [string]$DestHost,
        [int]$count
        
    )

    $rmQuery = 'rm /tmp/pgtstudents.csv'

    Invoke-SshCommand -ComputerName $DestHost -Command $rmQuery

    $rmResult = Invoke-SshCommand -ComputerName $DestHost -Command "[ -f /tmp/[filename].csv ] && echo 'file exists'" #attention to the file name. 

    if($rmResult.Result -ne "file exists"){
        Remove-WinSCPSession #remove winscp session
        Remove-Item C:\temp\[filename].csv -Recurse #delete file
        Remove-SshSession -ComputerName $DestHost #remove ssh session
        $datetime = Get-Date -Format yyyy-MM-dd
        $ResultOP = 'Report_' + $datetime + '.csv'

        ('Number of Users sucessfully added on to the PGT group' + $count).ToString() | Add-Content C:\temp\$ResultOP
        exit;
    }  

    
}

#@var
$DestHost = ''
$xmlObject = New-Object XML #create a xml object to get creds information.
$count = 0
$varMembers = [adsi]"LDAP://[DistinguinshedName]" #ldap query on all users in container.
$members = $varMembers.Invoke("Members") | ForEach-Object {$_.GetType().invokeMember("name",'GetProperty',$null,$_,$null)} | ForEach-Object {$_.Replace("CN=","")}

#@ keypass properties 
$xmlObject.Load('"[pathToFile]".xml') #looad the files and set properties
    $key_pwd = $xmlObject.KeyPass.pwd_key
    $user_ID = $xmlObject.KeyPass.Name_ID
    $winSCP = $xmlObject.KeyPass.lg_key
    $key_path = $xmlObject.KeyPass.path
    $key_fingerprint = $xmlObject.KeyPass.fingerprint
    $sskKeyFile = $xmlObject.KeyPass.path_key
    $skey_pwd = ConvertTo-SecureString -String $key_pwd.ToString() -AsPlainText -Force

#@ creds to login ssh connection
$useradm_user_creds = New-Object System.Management.Automation.PSCredential ("SshUserName]",(New-Object System.Security.SecureString))
$winSCP_pwd = ConvertTo-SecureString -String $winSCP.ToString() -AsPlainText -Force
$winSCP_cred = New-Object System.Management.Automation.PSCredential -ArgumentList $user_ID,$winSCP_pwd

#build query 
#since its a long query,  im using here string builder class to create the psql command.

$query = [System.Text.StringBuilder]::new()
    [void]$query.Append('first string')
    [void]$query.Append('second string')
    [void]$query.Append("third string")
    [void]$query.Append('forth string')
    [void]$query.Append('fifth stirng')
$sQuery = $query.ToString()
#invoke method to run a query.

#@begin script
if((SshConnection $DestHost $key_path $key_pwd $useradm_user_creds) -eq $true){ #validation to check if ssh connection is active 
    
    if((InvokeSSh  $DestHost $sQuery) -eq $true){ #invoke the query if active

       if((GetWinSCPsession -DestHost $DestHost -key_fingerprint $key_fingerprint -winSCP_cred `
       $winSCP_cred -skey_pwd $skey_pwd -sskKeyFile $sskKeyFile) -ne $false){
                $winSessionSCP = GetWinSCPsession $DestHost $key_fingerprint $winSCP_cred $skey_pwd $sskKeyFile #create a winscp connection

                Receive-WinSCPItem -WinSCPSession $winSessionSCP -LocalPath "[localpath]" -RemotePath ['remoteHostPath].csv'] #if query is successfull copy the file accross the systems
                $filepath = "[pathtofile].csv"
                Start-Sleep -Seconds 5

                    if((PathExists -filepath $filepath) -eq $true){ #condition to verify if file exists
                                #Write-Host "file received"
                                $sourcePGT = Import-Csv -LiteralPath '"[pathtofile].csv"'
                                $year = Get-Date -Format yyyy-MM-dd
                                $yearC = $year.Replace("-","")
                                foreach ($usernameID in $sourcePGT) {
                                    if ($usernameID.completiondate -ge $yearC){ #condition from file 
                                            $name = $usernameID.username
                                            if((GetMembers $name) -eq $true){ #call functions 
                                                Write-Host "adding new user"
                                               
                                            Add-ADGroupMember -Identity '[groupIdentity' -Members $usernameID.username -ErrorAction Continue -Verbose
                                             $count++; # keep a count of numbers of user added 
                                     }else{
                                         Write-Host "user not added"
                                         $ErrorActionPreference = 'silentlycontinue'
                                        } 
                                    } 
                                }
                    }else{
                        #comment here if path dont exist
                    }
                
       }else{
           Write-Host "WinScp session could not be initiated"
       }

    }else{
        Write-Host "command could not be executed"
    }

}else{
    Write-Host "No connection has been estabilished"
}

ExitSession $DestHost $count 

#end of script 

