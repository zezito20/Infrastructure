<#

DISCLAIMER: This application is a sample application. The sample is provided "as is" without 
warranty of any kind. The entire risk arising out of the use or performance of the samples remains with you. 


************************************
Created by: Jose Luiz Tavares
email: luiz.tavares@inato.uk
************************************

************************************
Prerequisites
************************************

1. The script will attempt to connect to your domain enviroment and perfom searches on 
	the active directory. You will require AD priveliged access to perfom this task.Please refer 
	to this article for more information:
	https://docs.microsoft.com/en-us/windows-server/identity/ad-ds/plan/security-best-practices/appendix-b--privileged-accounts-and-groups-in-active-directory

	The script will requires user credentials with office365 admin role assigned. This in order to get the configuration of the mailboxes. 
	Please refer to this article for more information:

	https://docs.microsoft.com/en-us/powershell/module/exchange/mailboxes/get-mailboxfolderpermission?view=exchange-ps
	https://docs.microsoft.com/en-us/powershell/module/exchange/mailboxes/set-mailboxfolderpermission?view=exchange-ps
	https://docs.microsoft.com/en-us/powershell/module/exchange/client-access/get-mailboxcalendarconfiguration?view=exchange-ps
	https://docs.microsoft.com/en-us/powershell/module/exchange/client-access/set-mailboxcalendarconfiguration?view=exchange-ps

	Use of the script:

	CopyCalendarPermission.ps1 -identity newcalendar@contoso.com -from oldcalendar@contoso.com -username admin -password ********
#>


#defining parameters for the use of the script.
param (
		[Parameter(Position=0,Mandatory=$true,HelpMessage="")]
		[ValidateNotNullOrEmpty()]
		[string]$Identity,
		
		
		[Parameter(Position=1,Mandatory=$true,HelpMessage="Convert mailbox type")]
		[string]$From,

		[Parameter(Position=2,Mandatory=$false,HelpMessage="Admin Username")]
		[ValidateNotNullOrEmpty()]
		[string]$username,

		
		[Parameter(Position=3,Mandatory=$false,HelpMessage="Admin Password")]
		[ValidateNotNullOrEmpty()]
		[string]$password
		
);

#if username or password are empty, ask for both

if([string]::IsNullOrEmpty($username) -or [string]::IsNullOrEmpty($password)){
	$cred = Get-Credential -Message "Please enter Office365 admin creds"
		if($cred){
			$username = $cred.UserName
			$password = $cred.Password

			<#
			#decript the string
			$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cred.Password)
			$password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)#>
		}else{
			Write-Error "Admin credential needed"
			exit;
		}
}else{
	$upwd = ConvertTo-SecureString -String $password -AsPlainText -Force
	$password = $upwd
	Continue;
}
ipmo ActiveDirectory

#create a new credential object
$credAdmin = New-Object System.Management.Automation.PSCredential ($username,$password)

#starts a new office365 session with the admin creds. !this does not support modern auth. For issues please email me on the contact above.
$PSsession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Authentication Basic -AllowRedirection -Credential $credAdmin

$IdentityList = ($Identity); #if user enter one or more calendars set it as list.

#get the calendar permissions
try{
	$fromID = $From + ":\calendar"
	$cal = Get-MailboxFolderPermission -Identity $fromID | select AccessRights, User
}catch{
	Write-Host "Mailbox calendar could not be found or email address typed wrong."
	Exit;
}

$permissionsSet = foreach($id in $cal){
	$id | select -ExpandProperty User | select -ExpandProperty ADrecipient | `
	select Name,DisplayName,@{Name="AccessRights";Expression={[string]::Join(";",($id | select -ExpandProperty AccessRights))}}
}

$IdentityList | ForEach-Object {
	$str1 = Get-Mailbox -id $_ 
		if($str1.RecipientTypeDetails -ne 'UserMailbox') #Condition to apply only on mailboxes that are not type users mailbox. For this exercise I wanted to target only shared and room type.
		{
			$folder = $_ + "calendar";
			foreach ($id in $permissionsSet)
			{
				Set-MailboxFolderPermission -Identity $folder -User $id.Name -AccessRights $id.AccessRights -Confirm:$true #here you can see which permission are being set. You are free to chnage this.

				#Here you can expand the script workload to apply other settings such as calendar configuration
				<#
				$calConfig = Get-MailboxCalendarConfiguration -Identity $From
				Set-MailboxCalendarConfiguration -Identity $_ -WorkingHoursEndTime $calConfig.WorkingHoursEndTime -WorkingHoursStartTime $calConfig.WorkingHoursStartTime -WorkingHoursTimeZone $calConfig.WorkingHoursTimeZone

				#>
			}
		}
}
#end of script