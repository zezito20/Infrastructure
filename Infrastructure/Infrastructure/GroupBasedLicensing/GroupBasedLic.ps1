<#

DISCLAIMER: This application is a sample application. The sample is provided "as is" without 
warranty of any kind. 

************
Created by: Luiz Tavares
Date: 02/01/2018
email: luiz.tavares@inato.co.uk

************

************************
Pre-requisites
************************

1. The script will attempt to connect to your domain enviroment and perfom searches on 
	your tenant. You will require priveliged access to perfom this task.
	The script will requires user credentials with office365 admin role assigned. 
	
	O365:
	https://docs.microsoft.com/en-us/office365/admin/add-users/about-admin-roles?view=o365-worldwide
	https://docs.microsoft.com/en-us/exchange/recipients/room-mailboxes?view=exchserver-2019

Purpose of Script: 

IF you are now on a migration from direct assignemnt licesing to group based licensing you may find this usefull. 
This script will find on your tentant users with specific plans ID and groups ID and check if any other plans have been assigned to user.
if not, the script will remove direct assigned licenses. Please be aware of this of you may want to ensure the group assignement rules have already taken place.
                                                            .
Feel free to contact me if you need some assistance.Email: / \
                                                            |
#>


Connect-MsolService

#@var 

$skuID = '' 
$groupSkuID = ''
$ExtaPlans =@('')
$count = 0

#@begin script
#verify if has extra plans
Function HasNoAdditionalPlans{

	Param([Microsoft.Online.Administration.User]$user, [array]$ExtraPlans)
	
	$license = $user.Licenses | Select -ExpandProperty ServiceStatus | where {$_.ProvisioningStatus -ieq "Success"} | select -ExpandProperty `
	ServicePlan | Select -ExpandProperty ServiceName

	foreach($plan in $license){
		$plans = Compare-Object $license $ExtraPlans -IncludeEqual -ExcludeDifferent #compare both objects and returns only same plans

		if($plans.Count -eq 0){
			return $true
		}
		return $false
	}

}
#verify if its group licensed 
Function IsGroupLicensed{

		Param([Microsoft.Online.Administration.User]$user,[string]$skuID, [string]$groupID)

		$accountSkuID = $user.Licenses | where AccountSkuID -EQ $skuID 

			foreach ($groupLicense in $accountSkuID){
				if($groupLicense.GroupAssingningLicense -ccontains $groupSkuID){
					return $true
				}

				return $false
			}
	return $false

}


#verify if there's license errors
Function HasLicenseError{
		
		Param([Microsoft.Online.Administration.User]$user)

		$assignementError = Get-MsolUser -ObjectId $user.ObjectID | where {$_.IndirectLicenseErrors}

		if($assignementError.IndirectLicenseErrors -eq $null){
			return $true
			#do something
		}
			return $false
		
}



Get-MsolUser -All | Where-Object{$_.isLicensed -eq $true  -and $_.licenses.AccountSkuID -eq $skuID } | `
	foreach{
		$user = $_;

		
		#@output 
		$result = '';
		$plans = '';

		
		#first condition
		if(HasLicenseError $user){

			if(IsGroupLicensed $user $skuID $groupSkuID){

				if(HasNoAdditionalPlans $user $ExtaPlans){
						
					$result = 'License has been removed'
						
						#$count++
							
							Set-MsolUserLicense -ObjectId $user.ObjectId -RemoveLicenses $skuID #hard removal!

				}else{
					#add statement
					$AddOnPlans = $user.Licenses | Select -ExpandProperty ServiceStatus | where {$_.ProvisioningStatus -ieq "Success"} | select -ExpandProperty `
	ServicePlan | Select -ExpandProperty ServiceName

					foreach($addOn in $AddOnPlans){         #in case your company select license according to user functions 
						if($addOn -contains 'Onedrive'){     #this will create a report with add-ons the user contains. Feel free to add more.
							$plans = $plans + "OneDrive"
						}
					}
				}


			}else{
				#add something 
				$result = 'No part right group'
			}


		}else{
			#add something here
			$result = 'User contain License Errors'

		}

		New-Object -TypeName Object | 

		Add-Member -NotePropertyName Name -NotePropertyValue $user.FirstName -PassThru |
		Add-Member -NotePropertyName OperationResult -NotePropertyValue $result -PassThru|
		Add-Member -NotePropertyName HasAddOnPlans -NotePropertyValue $plans 


} | Format-Table



#end script