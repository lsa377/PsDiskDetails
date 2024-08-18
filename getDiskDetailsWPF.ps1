if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}
function addTextToPanel ($text, $panel, $bold = $false) {
    try {
        $NewBox = New-Object System.Windows.Controls.TextBox
        $NewBox.IsReadOnly = $true
        $NewBox.Text = $text
        $NewBox.Margin = 2
        $NewBox.BorderThickness = "0"
        if ($bold) {
            $NewBox.FontWeight = "Bold"
        }
        $panel.AddChild($NewBox) | Out-Null
    }
    catch {
        Write-Host ($_.Exception.Message + " " + $_.ScriptStackTrace)
    }
}

function createDiskList () {
    try {
        $Script:localDisks = Get-Disk -ErrorAction Stop
        foreach ($diskGot in $Script:localDisks) {
            $diskString = "" + $diskGot.Number + " '" + $diskGot.FriendlyName + "', capacity " + [int]($diskGot.Size / 1024 / 1024 / 1024) + " GB, partition style '" + $diskGot.PartitionStyle + "'"
            if ($diskGot.PartitionStyle -eq "GPT") {
                $diskString += ", GUID " + $diskGot.Guid
            }        
            $diskGot | Add-Member -MemberType NoteProperty -Name "ForList" -Value $diskString -ErrorAction Stop
            $addMemberSplat = @{
                MemberType  = 'ScriptProperty'
                Name        = 'DisplayName'
                Value       = { $this.ForList }                  # getter
                SecondValue = { $this.ForList = $args[0] } # setter
            }
            $diskGot | Add-Member @addMemberSplat
        }
    }
    catch {
        Write-Host ($_.Exception.Message + " " + $_.ScriptStackTrace)
    }
}

Add-Type -AssemblyName PresentationFramework -ErrorAction Stop

$transitionStates = @("State reserved for OS", "The partition is stable. No configuration activity is currently in progress.", "The partition is being extended.", "The partition is being shrunk.", "The partition is being automagically reconfigured.", "", "", "", "The partition is being restriped.")
$gptTypes = @{}

# Common

$gptTypes.Add("c12a7328-f81f-11d2-ba4b-00a0c93ec93b", "EFI system partition.") | Out-Null
$gptTypes.Add("21686148-6449-6e6f-744e-656564454649", "BIOS boot partition.") | Out-Null
$gptTypes.Add("024dee41-33e7-11d3-9d69-0008c781f39f", "MBR partition scheme.") | Out-Null

# Windows
$gptTypes.Add("e3c9e316-0b5c-4db8-817d-f92df00215ae", "Microsoft Reserved partition.") | Out-Null
$gptTypes.Add("ebd0a0a2-b9e5-4433-87c0-68b6b72699c7", "Windows basic data partition.") | Out-Null
$gptTypes.Add("5808c8aa-7e8f-42e0-85d2-e1e90434cfb3", "Windows Logical Disk Manager (LDM) metadata partition on a dynamic disk.") | Out-Null
$gptTypes.Add("af9b60a0-1431-4f62-bc68-3311714a69ad", "Windows LDM data partition on a dynamic disk.") | Out-Null
$gptTypes.Add("de94bba4-06d1-4d40-a16a-bfd50179d6ac", "Microsoft Recovery partition.") | Out-Null
$gptTypes.Add("e75caf8f-f680-4cee-afa3-b001e56efc2d", "Microsoft Storage Spaces Partition.") | Out-Null
$gptTypes.Add("558d43c5-a1ac-43c0-aac8-d1472b2923d1", "Microsoft Storage Spaces Replica Partition.") | Out-Null

# Linux
$gptTypes.Add("0fc63daf-8483-4772-8e79-3d69d8477de4", "Generic Linux Data Partition.") | Out-Null
$gptTypes.Add("0657fd6d-a4ab-43c4-84e5-0933c84b4f4f", "Linux swap.") | Out-Null
$gptTypes.Add("e6d6d379-f507-44c2-a23c-238f2a3df928", "Linux Local Volume Manager.") | Out-Null
$gptTypes.Add("933ac7e1-2eb4-4f13-b844-0e14e2aef915", "Linux home.") | Out-Null
$gptTypes.Add("ca7d7ccb-63ed-4c53-861c-1742536059cc", "Linux encrypted partition (LUKS).") | Out-Null
$gptTypes.Add("8da63339-0007-60c0-c436-083ac8230908", "Linux Reserved partition.") | Out-Null
$gptTypes.Add("a19d880f-05fc-4d3b-a006-743f0f84911e", "Linux RAID partition.") | Out-Null

# FreeBSD
$gptTypes.Add("83bd6b9d-7f41-11dc-be0b-001560b84f0f", "FreeBSD boot partition.") | Out-Null
$gptTypes.Add("516e7cb4-6ecf-11d6-8ff8-00022d09712b", "FreeBSD BSD disklabel partition.") | Out-Null
$gptTypes.Add("516e7cb5-6ecf-11d6-8ff8-00022d09712b", "FreeBSD Swap partition.") | Out-Null
$gptTypes.Add("516e7cb6-6ecf-11d6-8ff8-00022d09712b", "Unix File System (UFS) partition.") | Out-Null
$gptTypes.Add("516e7cb8-6ecf-11d6-8ff8-00022d09712b", "FreeBSD Vinum volume manager partition.") | Out-Null
$gptTypes.Add("516e7cba-6ecf-11d6-8ff8-00022d09712b", "FreeBSD ZFS partition.") | Out-Null
$gptTypes.Add("74ba7dd9-a689-11e1-bd04-00e081286acf", "FreeBSD nandfs partition.") | Out-Null

# MacOS
$gptTypes.Add("48465300-0000-11aa-aa11-00306543ecac", "MacOS Hierarchical File System Plus (HFS+) partition.") | Out-Null
$gptTypes.Add("7c3457ef-0000-11aa-aa11-00306543ecac", "Apple APFS container.") | Out-Null
$gptTypes.Add("55465300-0000-11aa-aa11-00306543ecac", "Apple UFS container.") | Out-Null
$gptTypes.Add("6a898cc3-1dd2-11b2-99a6-080020736631", "MacOS ZFS.") | Out-Null
$gptTypes.Add("52414944-0000-11aa-aa11-00306543ecac", "Apple RAID partition.") | Out-Null
$gptTypes.Add("426f6f74-0000-11aa-aa11-00306543ecac", "Apple Boot partition (Recovery HD).") | Out-Null
$gptTypes.Add("4c616265-6c00-11aa-aa11-00306543ecac", "Apple Label.") | Out-Null
$gptTypes.Add("53746f72-6167-11aa-aa11-00306543ecac", "MacOS HFS+ FileVault volume container.") | Out-Null
$gptTypes.Add("69646961-6700-11aa-aa11-00306543ecac", "Apple APFS Preboot partition.") | Out-Null
$gptTypes.Add("52637672-7900-11aa-aa11-00306543ecac", "Apple APFS Recovery partition.") | Out-Null

# Chrome OS

# VMware
$gptTypes.Add("9d275380-40ad-11db-bf97-000c2911d1b8", "VMware core dump Partition (vmkcore).") | Out-Null
$gptTypes.Add("aa31e02a-400f-11db-9590-000c2911d1b8", "VMware VMFS filesystem partition.") | Out-Null
$gptTypes.Add("9198effc-31c0-11db-8f78-000c2911d1b8", "VMware Reserved.") | Out-Null

# Others
$gptTypes.Add("f4019732-066e-4e12-8273-346c5641494f", "Sony boot partition.") | Out-Null
$gptTypes.Add("bfbfafe7-a34f-448a-9a5b-6213eb736c22", "Lenovo boot partition.") | Out-Null


$mbrTypes = @("", "DOS FAT 12-bit", "XENIX root", "XENIX /usr", "DOS FAT 16-bit up to 32M", "Extended MS-DOS Partition", "DOS FAT 16-bit over 32M", "Integrated File System (IFS)", "", "", "", "OS/2 Boot Mgr", "DOS FAT 32-bit", "DOS FAT 32-bit with INT13h", "DOS FAT 16-bit with INT13h", "Extended MS-DOS Partition with INT13h")

[xml]$xamldisks = @"
<Window 
xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
x:Name="Window"
Title="Local disks - detailed information"
Height="700"
Width="800">
    <StackPanel x:Name = "All" Margin="10" Width = "750">
        <TextBox x:Name="Legend" Height = "20" BorderThickness = "0" FontWeight="Bold" FontSize="12" Margin = "5">DISKS - click for details</TextBox>
        <ScrollViewer x:Name = "DiskListScroll" VerticalScrollBarVisibility="Auto" Height = "85">
            <ListBox x:Name="DiskList" Height = "Auto" DisplayMemberPath = "DisplayName" Margin="5" />
        </ScrollViewer>
        <Button x:Name = "Refresh" Margin="5" Content="Update disk list" Height = "20" Width = "100" HorizontalAlignment = "Right"/>
        <TextBox x:Name="Status" Height = "Auto" BorderThickness = "0" TextWrapping="Wrap" Margin = "5" />
        <ScrollViewer x:Name = "DiskInfoScroll" VerticalScrollBarVisibility="Auto" Height = "450">
            <StackPanel x:Name = "ItemDetails" Height = "Auto" Margin="10" />
        </ScrollViewer>
    </StackPanel>
</Window>
"@

try {
    $readerdisks = (New-Object System.Xml.XmlNodeReader $xamldisks)
    $windowdisks = [Windows.Markup.XamlReader]::Load($readerdisks)

    $StatusBox = $windowdisks.FindName("Status")
    $DiskList = $windowdisks.FindName("DiskList")
    $DetailsPannel = $windowdisks.FindName("ItemDetails")
    $RefreshButton = $windowdisks.FindName("Refresh")

    createDiskList

    $DiskList.itemsSource = $Script:localDisks
    
    $DiskList.Add_SelectionChanged({
            $StatusBox.Text = ""
            try {
                if ($null -eq $DiskList.SelectedItem) {
                    $DetailsPannel.Children.Clear()
                }
                else {
                    $disk = $DiskList.SelectedItem
                    $DetailsPannel.Children.Clear()
                    addTextToPanel -text ("Disk '" + $disk.FriendlyName + "'") -panel $DetailsPannel -bold $true
                    addTextToPanel -text ("Manufacturer: '" + $disk.Manufacturer + "',  model: '" + $disk.Model + "', serial number:  " + $disk.SerialNumber) -panel $DetailsPannel
                    addTextToPanel -text ("Number: " + $disk.Number + ", unique Id: " + $disk.UniqueId) -panel $DetailsPannel
                    if ($disk.PartitionStyle -eq "GPT") {
                        addTextToPanel -text ("GUID: " + $disk.Guid) -panel $DetailsPannel
                    }
                    addTextToPanel -text ("Health status: " + $disk.HealthStatus) -panel $DetailsPannel
                    addTextToPanel -text ("Is boot: " + $disk.IsBoot) -panel $DetailsPannel
                    addTextToPanel -text ("Partition style: " + $disk.PartitionStyle + ", number of partitions on disk: " + $disk.NumberOfPartitions) -panel $DetailsPannel
                    addTextToPanel -text "" -panel $DetailsPannel

                    foreach ($partition in (Get-Partition -DiskNumber $disk.Number -ErrorAction Stop)) {
                        addTextToPanel -text ("Partition " + $partition.PartitionNumber) -panel $DetailsPannel -bold $true
                        if ($disk.PartitionStyle -eq "GPT") {
                            addTextToPanel -text ("GPT type: " + $gptTypes[$partition.GptType.Replace("{", "").Replace("}", "")] + " " + $partition.GptType) -panel $DetailsPannel
                        }
                        if ($disk.PartitionStyle -eq "MBR") {
                            addTextToPanel -text ("MBR type: " + $mbrTypes[$partition.MbrType] + " (" + $partition.MbrType + ")") -panel $DetailsPannel

                        }
                        addTextToPanel -text ("GUID: " + $partition.Guid) -panel $DetailsPannel
                        addTextToPanel -text ("Is active: " + $partition.IsActive + ", is boot: " + $partition.IsBoot + ", is system " + $partition.IsSystem) -panel $DetailsPannel
                        addTextToPanel -text ("Size: " + $partition.Size + " bytes | " + [math]::Round(($partition.Size / 1024 / 1024), 2) + " MB | " + [math]::Round(($partition.Size / 1024 / 1024 / 1024), 2) + " GB") -panel $DetailsPannel
                        addTextToPanel -text ("Access paths: " + $partition.AccessPaths) -panel $DetailsPannel
                        addTextToPanel -text ("Operational status: " + $partition.OperationalStatus) -panel $DetailsPannel
                        addTextToPanel -text ("Transitional state: " + $transitionStates[$partition.TransitionState]) -panel $DetailsPannel
                        addTextToPanel -text ("Drive letter: " + $partition.DriveLetter) -panel $DetailsPannel
                        addTextToPanel -text "" -panel $DetailsPannel
                        addTextToPanel -text "Volumes" -panel $DetailsPannel -bold $true
                        foreach ($volume in (Get-Volume -Partition $partition -ErrorAction Stop)) {
                            addTextToPanel -text ("Drive letter: " + $volume.DriveLetter + ", label: '" + $volume.FileSystemLabel + "'") -panel $DetailsPannel
                            addTextToPanel -text ("File system: " + $volume.FileSystem) -panel $DetailsPannel
                            addTextToPanel -text ("Size: " + $volume.Size + " bytes | " + [math]::Round(($volume.Size / 1024 / 1024), 2) + " MB | " + [math]::Round(($volume.Size / 1024 / 1024 / 1024), 2) + " GB") -panel $DetailsPannel
                            addTextToPanel -text ("Object ID: " + $volume.ObjectId) -panel $DetailsPannel
                            addTextToPanel -text ("Path: " + $volume.Path) -panel $DetailsPannel
                            addTextToPanel -text ("Health status: " + $volume.HealthStatus) -panel $DetailsPannel
                            addTextToPanel -text ("Operational status: " + $volume.OperationalStatus) -panel $DetailsPannel
                            addTextToPanel -text "" -panel $DetailsPannel
                        }
                        addTextToPanel -text "" -panel $DetailsPannel
                    }
                }
            }
            catch {
                Write-Host ($_.Exception.Message + " " + $_.ScriptStackTrace)
            }
        })

    $RefreshButton.Add_Click({
            $StatusBox.Text = ""
            createDiskList
            $DiskList.itemsSource = $Script:localDisks
        })

    $windowdisks.ShowDialog() | Out-Null
    $windowdisks.Activate() | Out-Null

}
catch {
    Write-Host ($_.Exception.Message + " " + $_.ScriptStackTrace)
}