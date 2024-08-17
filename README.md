# "Get Disk Details" PowerShell script
---

## General purpose 

This script shows the specific details of the local physical and virtual disks mounted to the Windows OS. It lists local disks and allows to see the parameters of the partition and volume objects like ID, partition style, type and others from the disk, partition and volume OS objects, which usually not displayed in the Windows Disk Management. Those details are usefull analizing the event logs/logs of the OS or third party applications, where disks, partitions or volumes mentioned by some not user friendly properties like path or ID.

## Technologies

Created on the PowerShell 5.1 using the Windows WPF assembly.

## Requiremets

Will require the administrative privilegies to run propperly.

## Usage

Run the script, wait for UI to open and click the disk listed in the upper disk list to see the list of partitions and volumes with it's details and parameters.