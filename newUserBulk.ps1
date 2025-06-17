#Script needs RSAT:Active Directory Domain Services and Lightweight Directory Services Tools to function
$secpass = Read-Host "Password" -AsSecureString
Import-Csv newAccounts.csv |
ForEach-Object {
    try{
        $name = "$($_.LastName) $($_.FirstName)"
        $firstName = $_.FirstName
        $lastName = $_.LastName
        $ouPath = "OU=Staff,OU=$($_.Site),OU=Client Users,OU=User Accounts,dc=bsin,dc=k12,dc=nm,dc=us"
        $remoteServer = $($_.Server)
        

        #Generate samAccountName
        $baseSamAccountName = "$($_.Firstname.Substring(0,1))$($_.LastName)"
        $samAccountName = $baseSamAccountName
        $counter = 2

        #Check to see if the SAM account name already exists and modify if needed
        While (Get-AdUser -Filter "SamAccountName -eq '$samAccountName'" -ErrorAction SilentlyContinue){
            if ($counter -le $firstName.Length) {
                # Use more characters from first name (jdoe -> jodoe -> johdoe, etc.)
                $samAccountName = "$($firstName.Substring(0,$counter))$lastName"
                $counter++
            } else {
                    # If we've used all first name characters, start adding numbers
                    $samAccountName = "$baseSamAccountName$($counter - $firstName.Length)"
                    $counter++
            }

        }
        Write-Host "Creating a new account for $($_.FirstName) $($_.LastName) with the account name $samAcocuntName." -ForegroundColor Green
        
        New-ADUser -GivenName $($_.FirstName) -Surname $($_.LastName) `
            -Name $name -SamAccountName $samAccountName `
            -UserPrincipalName "$samAccountName@bsin.k12.nm.us" `
            -AccountPassword $secpass -Path $ouPath  `
            -Enabled:$true
        
        #Create a new folder in the Userdocs directory on the appropriate site server
        $newDirectoryPath = "E:\Userdocs\$samAccountName"
        Invoke-Command -ComputerName $remoteServer -ScriptBlock {
            param($dirPath, $userName)

            if (-not (Test-Path $dirPath)){
                New-Item -ItemType Directory -Path $dirPath -Force
                Write-Host "Successfully created directory: $dirPath"
            } else {
                Write-Host "Directory already exists: $dirPath"
            }
            
            #Set permissions for each newly created directory
            try{
                $acl= Get-Acl $dirPath
                $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($userName, "Modify,ReadAndExecute,Write", "ContainerInherit,ObjectInherit", "None", "Allow")
                $acl.SetAccessRule($accessRule)
                Set-Acl -Path $dirPath -AclObject $acl
                Write-Host "Successfully set permissions for $userName on $dirPath" -ForegroundColor Green
            } catch {
                Write-Host "Failed to set permissions for $userName on $dirPath' : $($_.Exception.Message)" -ForegroundColor Red
            }
        } -ArgumentList $newDirectoryPath, $samAccountName

    } catch {
        Write-Host "Failed to create user $($_.FirstName) $($_.LastName): $($_.Exception.Message)" -ForegroundColor Red
    }
    


}