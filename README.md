# "Get Disk Details" PowerShell script
---

## General purpose 

This script shows the specific details of the local physical and virtual disks mounted to the Windows OS. It lists local disks and allows to see the parameters of the disk, partition and volume objects like ID, serial number, partition style, partition type, path and others from the disk, partition and volume OS objects, which usually not displayed in the Windows Disk Management. Those details are usefull analizing the event logs/logs of the OS or third party applications, where disks, partitions or volumes mentioned by some not user friendly properties like path or ID.
Also allows to recognize some non-Windows GPT partition types if the attached media was created in the different OS. This ability may help if you connected some unknown disk to Windows and just can't remember or guess what is there actually.

## Technologies

Created on the PowerShell 5.1 using the Windows WPF assembly.

## Requiremets

Will require the administrative privilegies to run propperly. Will work on the Windows versions 8/2012R2 and higher with the Windows Management Framework 5.1 installed.

## Usage

Run the script, wait for UI to open and click the disk listed in the disk list to see the list of partitions and volumes with it's details and parameters.

Note: volume details and the file system information currently not available for the non-Windows volumes.