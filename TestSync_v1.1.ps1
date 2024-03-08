#==================================================================================
# Description:  The script that synchronizes two folders source and replica, one way.
# Author:       Kadlcek Vaclav
# Created date: 08.03.2024
# Edited date:  x 
# Edited by:    x
# Version:      1.1
#==================================================================================
# READ ME - How to run the script
# Open PowerShell and navigate to the folder where is the script located. Run the script with all parameters:
# .\TestSync_v1.1.ps1 -SourceFolder "XXX" -ReplicaFolder "XXX" -ConsoleLog "XXX" -OperationLog "XXX"
# Example: .\TestSync_v1.1.ps1 -SourceFolder "C:\TestSync\Source" -ReplicaFolder "C:\TestSync\Replica" -ConsoleLog "C:\TestSync\Logs\ConsoleLogs.txt" -OperationLog "C:\TestSync\Logs\OperationLogs.txt"
#----------------------------------------------------------------------------------

param (
    [string]$SourceFolder,
    [string]$ReplicaFolder,
    [string]$ConsoleLog,
    [string]$OperationLog
)

#-----------------------------

$Date = get-date -Format "yyyy-MM-dd HH:mm:ss"

#-----------------------------
#--- START Function block ----
#-----------------------------


# Function template
Function CompareObjects
{
    Write-Host "Function CompareObjects started"
    Try
        {            
            $CompareObjects = Compare-Object -ReferenceObject $SourceContent -DifferenceObject $ReplicaContent -IncludeEqual | Select-Object | Sort-Object SideIndicator -Descending 
            # SideIndicator <= source folder
            # SideIndicator => replica folder

            Write-Host "--------------------------------"
            Write-Host "--- List of compared objects ---"
            Write-Host "--------------------------------"
            $CompareObjects | ft
            Write-Host "--------------------------------"
            $SourceContentCount = $SourceContent.Count
            $ReplicaContentCount = $ReplicaContent.Count

            Write-Host "Number of objects in the source folder : $SourceContentCount"
            Write-Host "Number of objects in the replica folder: $ReplicaContentCount"
            Write-Host "--------------------------------"

            foreach($object in $CompareObjects)
            {
                $o = $object.InputObject.FullName
                Write-Host "---"
                Write-Host "Working on object: $o" -ForegroundColor Cyan  # Example: $o = C:\TestSync\Source\_Ford\Focus\Focus_benzin.txt

                # Replica - SideIndicator => replica folder
                if ($object.SideIndicator -eq "=>")
                {                                      
                    If ($object -like "*DifferenceObject is empty.*") 
                    {} # Temp variable
                    Else
                    {                                        
                        # Remove objects from replica folder                        
                        #$SourceObjectPath = $object.InputObject.FullName
                        #$ReplicaObjectPath = $SourceObjectPath -replace [regex]::Escape($SourceFolder),$ReplicaFolder
                        $ReplicaObjectPath = $o
                                                                   
                        Write-Host "Remove object: $ReplicaObjectPath"
                        Remove-Item -Path $ReplicaObjectPath -Force -Recurse -Verbose -ErrorAction SilentlyContinue
                        # Write log to file
                        "$date | Operation: Remove | Destination: $ReplicaObjectPath" | Add-Content $OperationLog
                        
                        #Write-Host "Copy object: $SourceObjectPath" 
                        #Copy-Item -Path $SourceObjectPath -Destination $DestObjectPath -Force -Verbose
                        # Write log to file
                        #"$date | Operation: Copy | Source: $SourceObjectPath | Destination: $DestObjectPath" | Add-Content $OperationLog
                    }
                }

                elseif ($object.SideIndicator -eq "<=")
                {
                    # Copy objects from source to replica folder
                    $SourceObjectPath = $object.InputObject.FullName       # C:\TestSync\Source\_VW\Passat\Passat_nafta.txt
                    $DestObjectPath = $SourceObjectPath -replace [regex]::Escape($SourceFolder),$ReplicaFolder
                    Write-Host "Copy object: $SourceObjectPath" 
                    Copy-Item -Path $SourceObjectPath -Destination $DestObjectPath -Force -Verbose
                    # Write log to file
                    "$date | Operation: Copy | Source: $SourceObjectPath | Destination: $DestObjectPath" | Add-Content $OperationLog
                }
                Elseif ($object.SideIndicator -eq "==")    # C:\TestSync\Source\_VW\Passat\Passat_nafta.txt
                {
                    # Check last write time
                    $SourceLastWriteTime = $object.InputObject.LastWriteTime
                    
                    $SourceObjectPath = $object.InputObject.FullName
                    $DestObjectPath = $SourceObjectPath -replace [regex]::Escape($SourceFolder),$ReplicaFolder
                    #$DestObjectPath = $SourceObjectPath -replace $SourceFolder.Replace('\','\\'),$ReplicaFolder

                    Write-Host "Source file path      : $SourceObjectPath"
                    Write-Host "Replica file path     : $DestObjectPath"
                    Write-Host "Source last write time: $SourceLastWriteTime"

                    $SourceHash = (Get-FileHash $SourceObjectPath -Algorithm MD5).Hash
                    # Files with the same name in different folder
                    if ((Test-Path -Path $DestObjectPath))
                    {
                        $ReplicaHash = (Get-FileHash $DestObjectPath -Algorithm MD5).Hash    
                    }
                    Else
                    {
                        Write-Host "File in Replica folder does not exist"
                    }
                    

                    Write-host "Source hash     : $SourceHash"
                    Write-host "Replication hash: $ReplicaHash"

                    If (!$SourceHash -and !$ReplicaHash)
                    {
                        Write-Host "Hashs are empty - FOLDERS"
                    }
                    Elseif ($SourceHash -eq $ReplicaHash)
                    {
                        Write-Host "Hashs are the same"
                    }
                    else
                    {
                        Write-Host "Hashs are not the same"
                                                
                            # Remove objects                        
                            Write-Host "Remove object (hash is not the same): $DestObjectPath"
                            Remove-Item -Path $DestObjectPath -Force -Recurse -Verbose -ErrorAction SilentlyContinue
                            # Write log to file
                            "$date | Operation: Remove | Destination: $DestObjectPath" | Add-Content $OperationLog

                            # Replace - Copy same object name from source to replica folder                        
                            Write-Host "Replace object from source: $SourceObjectPath"                     
                            Write-Host "Replace object to replica : $DestObjectPath"  

                            Copy-Item -Path $SourceObjectPath -Destination $DestObjectPath -Force -Verbose
                            # Write log to file
                            "$date | Operation: Replace | Source: $SourceObjectPath | Destination: $DestObjectPath" | Add-Content $OperationLog                        
                        
                    }
                                                                              
                }
                
            }
            
            #--- Final Check if all objects are up to date
            $SourceContentCheck = Get-ChildItem -Recurse -Path $SourceFolder
            $ReplicaContentCheck = Get-ChildItem -Recurse -Path $ReplicaFolder
            
            $CompareObjectsCheck = Compare-Object -ReferenceObject $SourceContentCheck -DifferenceObject $ReplicaContentCheck -IncludeEqual
            # SideIndicator <= source folder
            # SideIndicator => replica folder
            
            Write-Host "-----------------------------------------------"
            Write-Host "--- Check that all objects are synchronized ---"
            Write-Host "-----------------------------------------------"

            foreach($ob in $CompareObjectsCheck)
            {
                $o = $ob.InputObject.FullName
                
                if ($ob.SideIndicator -ne "==")
                {
                    Write-Host "- Object is not the same: $o" -ForegroundColor Red   # Note: Object is not same: C:\TestSync\Replica\_Ford\Focus\F_Benzin\Focus_benzin16.txt
                    
                    If ($o -like "$SourceFolder*")
                    {
                        Write-Host "- Object is from Source folder" -ForegroundColor Yellow
                    }
                    Else
                    {
                        # Files with the same name in Replica folder
                        $SourceFile = Get-ChildItem -Path $SourceFolder -Name $ob.InputObject.Name -File -Recurse     # _Skoda\Octavia\Octavia_nafta.txt
                        $ReplicaFiles = Get-ChildItem -Path $ReplicaFolder -Name $ob.InputObject.Name -File -Recurse

                        foreach ($rf in $ReplicaFiles)
                        {
                            If ($SourceFile -like $rf)    
                            {
                                # ok, do nothing
                            }
                            Else
                            {
                                $DelFile = $ReplicaFolder+"\"+$rf  # $rf = _Skoda\Octavia_nafta.txt OR _Skoda\Octavia\Octavia_nafta.txt

                                Write-Host "Remove object: $DelFile"
                                Remove-Item -Path $DelFile -Force -Verbose -ErrorAction SilentlyContinue
                                # Write log to file
                                "$date | Operation: Remove | Destination: $DelFile" | Add-Content $OperationLog
                            }
                        }
                      
                    }

                }
                Else
                {
                    Write-Host "- OK, object is synchronized ($o)" -ForegroundColor Green
                }
                
            }
            
            #--- Number of objects
            $SourceContentCheck02 = Get-ChildItem -Recurse -Path $SourceFolder
            $ReplicaContentCheck02 = Get-ChildItem -Recurse -Path $ReplicaFolder
                       
            $SourceContentCheckCount = $SourceContentCheck02.Count
            $ReplicaContentCheckCount = $ReplicaContentCheck02.Count

            Write-Host "--------------------------------"
            Write-Host "Number of objects in the source folder : $SourceContentCheckCount"
            Write-Host "Number of objects in the replica folder: $ReplicaContentCheckCount"
            Write-Host "--------------------------------"

            If($SourceContentCheckCount -eq $ReplicaContentCheckCount)
            {
                Write-Host "- OK, the same number of objects" -ForegroundColor Green
            }
            else
            {
                Write-host "- Error, the number of objects is not the same" -ForegroundColor Red
            }
            Write-host "--------------------------------"
            #---
           

        }
    Catch
        {
            Write-Output "ERROR - function failed with error: $_.Exception.Messag"
        }
    
}

Function CompareFolders
{
    Write-Host "Function CompareFolders started"
 Try
 {
    # Compare folders
    $FoldersInSource = (Get-ChildItem -Path $SourceFolder -Recurse -Directory).FullName
    $FoldersInReplica = (Get-ChildItem -Path $ReplicaFolder -Recurse -Directory).FullName

    foreach ($folder in $FoldersInSource)
    {
        $SourceFoldertPath = $folder
        $ReplicaFolderPath = $SourceFoldertPath -replace [regex]::Escape($SourceFolder),$ReplicaFolder

        If (Test-Path $ReplicaFolderPath)
        {
            Write-Host "- Folder exists in replica folder - $ReplicaFolderPath"
        }
        Else
        {
            Write-Host "- Folder does not exist in replica folder - $ReplicaFolderPath"
            New-Item -Path "$ReplicaFolderPath"-ItemType "directory" -Verbose            
            # Write log to file
            "$date | Operation: Create | Destination: $ReplicaFolderPath" | Add-Content $OperationLog

        }
    }
 }
 Catch
 {
    Write-Output "ERROR - function failed with error: $_.Exception.Messag"
 }

}   

Function FirstCheck
{
    Write-Host "Function FirstCheck started"
    Try
    {
        
        #--- Check that all paramers are filled
        If (!$SourceFolder)
        {
            Write-Host "SourceFolder parametr is empty." -ForegroundColor Red
            Write-Host "Correct syntax is: -SourceFolder XXX -ReplicaFolder XXX -ConsoleLog XXX -OperationLog XXX"
            Exit
        }
        Elseif(!$ReplicaFolder)
        {
            Write-Host "ReplicaFolder parametr is empty." -ForegroundColor Red
            Write-Host "Correct syntax is: -SourceFolder XXX -ReplicaFolder XXX -ConsoleLog XXX -OperationLog XXX"
            Exit
        }
        Elseif(!$ConsoleLog)
        {
            Write-Host "ConsoleLog parametr is empty." -ForegroundColor Red
            Write-Host "Correct syntax is: -SourceFolder XXX -ReplicaFolder XXX -ConsoleLog XXX -OperationLog XXX"
            Exit
        }
        Elseif(!$OperationLog)
        {
            Write-Host "OperationLog parametr is empty." -ForegroundColor Red
            Write-Host "Correct syntax is: -SourceFolder XXX -ReplicaFolder XXX -ConsoleLog XXX -OperationLog XXX"
            Exit
        }
        Else
        {
            Write-Host "- OK, all parametrs are filled" -ForegroundColor Green
        }


        # --- Check if FOLDERS exist  ---
        $TestPathSource = Test-Path -Path $SourceFolder
        $TestPathReplica = Test-Path -Path $ReplicaFolder

        If ($TestPathSource -like "True" -and $TestPathReplica -like "True")
        {
            Write-Host "- OK, source and replica folder exists" -ForegroundColor Green
        }
        Elseif ($TestPathSource -like "False")
        {
            Write-Host "- Error, source folder does not exist. Please write correct path." -ForegroundColor Red
            exit
        }
        Elseif ($TestPathReplica -like "False")
        {
            Write-Host "- Error, replica folder does not exist. Please write correct path." -ForegroundColor Red    
            exit
        }
        Elseif (!$TestPathSource)
        {
            Write-Host "- Error, source folder does not exist. Please create folder." -ForegroundColor Red    
            Exit    
        }        

    }
    Catch
    {
        Write-Output "ERROR - function failed with error: $_.Exception.Messag"
    }
}                    

#-----------------------------
#--- END Function block ------
#-----------------------------

#-----------------------------
#--- START Main Code block ---
#-----------------------------

#  Redirect PS console to a text file
Start-Transcript -path $ConsoleLog

Write-Host "----------------------------------------------"
Write-Host "--- Start script code ------------------------"
Write-Host "----------------------------------------------"

Write-host "Source folder : $SourceFolder"
Write-host "Replica folder: $ReplicaFolder"
Write-Host "----------------------------------------------"

# Function
FirstCheck

Write-Host "---"

# --- Delete log file
If (Test-Path -Path $OperationLog)
{
    Write-Host "...removing operation log file..."
    Remove-Item -Path $OperationLog -Verbose
}


Write-Host "--------------------------------"

# Function - compare folders in source/replica folder and then create the same folder tree in the Replica folder
CompareFolders

Write-Host "--------------------------------"

# Get list of objects from Source and Replica folders
$SourceContent = Get-ChildItem -Recurse -Path $SourceFolder
$ReplicaContent = Get-ChildItem -Recurse -Path $ReplicaFolder

# There are objects in Source folder
If ($SourceContent)
{
    # Replica folder is empty, add temp value
    If(!$ReplicaContent)
    {
        # Cannot bind argument to parameter 'DifferenceObject' because it is null..Exception.Messag
        $ReplicaContent = "DifferenceObject is empty."   
    }

    # Function
    CompareObjects  

}
Elseif (!$SourceContent -and !$ReplicaContent)
{
    Write-Host "- The source and replica folders are empty. No files for sync." -ForegroundColor Cyan
}
Else
{
    #--- Delete objects in Replica folder if Source folder is empty---
    Write-Host "--------------------------------"
    Write-host "List of files in replica folder:"
    Write-Host "--------------------------------"
    $ReplicaContent.Name
    Write-Host "--------------------------------"
    Write-Host "- The source folder is empty. No files for sync."
    Write-Host "Do you want to delete all files in replica folder?" -ForegroundColor Yellow
    Read-Host "Press enter to continue or Ctrl - C to stop" 

    $ReplicaContent | Remove-Item -Force -Recurse -Verbose -ErrorAction SilentlyContinue

    # Double check
    $CheckReplicaContent = Get-ChildItem -Recurse -Path $ReplicaFolder

    If ($CheckReplicaContent)
    {
        Write-Host "- Error, objects were not deleted" -ForegroundColor Red
    }
    Else
    {
        Write-Host "- OK, successfully deleted. Folder is empty." -ForegroundColor Green
    }
}

# --- Log files info ---
Write-Host "----------------------------------------------"
Write-Host "Location of the console log file  : $ConsoleLog"
Write-Host "Location of the operation log file: $OperationLog"
Write-Host "----------------------------------------------"

Write-Host "----------------------------------------------"
Write-Host "--- END script code --------------------------"
Write-Host "----------------------------------------------"

# Redirect PS console to a text file
Stop-Transcript

#-----------------------------
#--- END Main Code block -----
#-----------------------------