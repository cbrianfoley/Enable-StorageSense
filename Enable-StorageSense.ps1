# Enables StorageSense for ALL USERS

# Regex pattern for SIDs
$PatternSID = 'S-1-5-21-\d+-\d+\-\d+\-\d+$'
 
# Get Username, SID, and location of ntuser.dat for all users
$ProfileList = gp 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*' | Where-Object {$_.PSChildName -match $PatternSID} | 
    Select  @{name="SID";expression={$_.PSChildName}}, 
            @{name="UserHive";expression={"$($_.ProfileImagePath)\ntuser.dat"}}, 
            @{name="Username";expression={$_.ProfileImagePath -replace '^(.*[\\\/])', ''}}
 
# Get all user SIDs found in HKEY_USERS (ntuder.dat files that are loaded)
$LoadedHives = gci Registry::HKEY_USERS | ? {$_.PSChildname -match $PatternSID} | Select @{name="SID";expression={$_.PSChildName}}
 
# Get all users that are not currently logged
$UnloadedHives = Compare-Object $ProfileList.SID $LoadedHives.SID | Select @{name="SID";expression={$_.InputObject}}, UserHive, Username
 
# Loop through each profile on the machine
Foreach ($item in $ProfileList) {
    Write-Host "`nLoading hive. $($item.SID) $($Item.UserHive)"
    # Load User ntuser.dat if it's not already loaded
    IF ($item.SID -in $UnloadedHives.SID) {
        reg load HKU\$($Item.SID) $($Item.UserHive)
    }
 
    #####################################################################
    # This is where you can read/modify a users portion of the registry 
 
        # Enables Storage Sense

        # Ensure the StorageSense key exists
        $key = "Microsoft.PowerShell.Core\Registry::HKEY_USERS\$($item.SID)\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense"
        If (!(Test-Path "$key")) {
            Write-Host "Creating StorageSense key"
            New-Item -Path "$key" | Out-Null
        }
        If (!(Test-Path "$key\Parameters")) {
            Write-Host "Creating Parameters key"
            New-Item -Path "$key\Parameters" | Out-Null
        }
        If (!(Test-Path "$key\Parameters\StoragePolicy")) {
            Write-Host "Creating StoragePolicy key"
            New-Item -Path "$key\Parameters\StoragePolicy" | Out-Null
        }

        # Set Storage Sense settings
        Write-Host "Enabling Storage Sense"
        Set-ItemProperty -Path "$key\Parameters\StoragePolicy" -Name "01" -Type DWord -Value 1

        Write-Host "Set 'Run Storage Sense' to Every Week"
        Set-ItemProperty -Path "$key\Parameters\StoragePolicy" -Name "2048" -Type DWord -Value 7

        Write-Host "Enable 'Delete temporary files that my apps aren't using'"
        Set-ItemProperty -Path "$key\Parameters\StoragePolicy" -Name "04" -Type DWord -Value 1

        Write-Host "Set 'Delete files in my recycle bin if they have been there for over' to 14 days"
        Set-ItemProperty -Path "$key\Parameters\StoragePolicy" -Name "08" -Type DWord -Value 1
        Set-ItemProperty -Path "$key\Parameters\StoragePolicy" -Name "256" -Type DWord -Value 14

        Write-Host "Set 'Delete files in my Downloads folder if they have been there for over' to 60 days"
        Set-ItemProperty -Path "$key\Parameters\StoragePolicy" -Name "32" -Type DWord -Value 1
        Set-ItemProperty -Path "$key\Parameters\StoragePolicy" -Name "512" -Type DWord -Value 60

        Write-Host "Set value that Storage Sense has already notified the user"
        Set-ItemProperty -Path "$key\Parameters\StoragePolicy" -Name "StoragePoliciesNotified" -Type DWord -Value 1
    #####################################################################
 
    # Unload ntuser.dat        
    IF ($item.SID -in $UnloadedHives.SID) {
        ### Garbage collection and closing of ntuser.dat ###
        [gc]::Collect()
        reg unload HKU\$($Item.SID)
    }
}