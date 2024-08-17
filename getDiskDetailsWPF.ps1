if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}
function addTextToPanel ($text, $panel, $bold = $false) {
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

Add-Type -AssemblyName PresentationFramework -ErrorAction Stop

$transitionStates = @("State reserved for OS", "The partition is stable. No configuration activity is currently in progress.", "The partition is being extended.", "The partition is being shrunk.", "The partition is being automagically reconfigured.", "", "", "", "The partition is being restriped.")
$gptTypes = @{}
$gptTypes.Add("c12a7328-f81f-11d2-ba4b-00a0c93ec93b", "An EFI system partition.") | Out-Null
$gptTypes.Add("e3c9e316-0b5c-4db8-817d-f92df00215ae", "A Microsoft reserved partition.") | Out-Null
$gptTypes.Add("ebd0a0a2-b9e5-4433-87c0-68b6b72699c7", "A basic data partition.") | Out-Null
$gptTypes.Add("5808c8aa-7e8f-42e0-85d2-e1e90434cfb3", "A Logical Disk Manager (LDM) metadata partition on a dynamic disk.") | Out-Null
$gptTypes.Add("af9b60a0-1431-4f62-bc68-3311714a69ad", "The partition is an LDM data partition on a dynamic disk.") | Out-Null
$gptTypes.Add("de94bba4-06d1-4d40-a16a-bfd50179d6ac", "Microsoft recovery partition.") | Out-Null
$gptTypes.Add("0fc63daf-8483-4772-8e79-3d69d8477de4", "Generic Linux Data Partition.") | Out-Null
$gptTypes.Add("e75caf8f-f680-4cee-afa3-b001e56efc2d", "Microsoft Storage Spaces.") | Out-Null
$gptTypes.Add("0657fd6d-a4ab-43c4-84e5-0933c84b4f4f", "Linux swap.") | Out-Null
$gptTypes.Add("e6d6d379-f507-44c2-a23c-238f2a3df928", "Linux Local Volume Manager.") | Out-Null
$gptTypes.Add("933ac7e1-2eb4-4f13-b844-0e14e2aef915", "Linux home.") | Out-Null
$mbrTypes = @("", "DOS FAT 12-bit", "XENIX root", "XENIX /usr", "DOS FAT 16-bit up to 32M", "Extended MS-DOS Partition", "DOS FAT 16-bit over 32M", "Integrated File System (IFS)", "", "", "", "OS/2 Boot Mgr", "DOS FAT 32-bit", "DOS FAT 32-bit with INT13h", "DOS FAT 16-bit with INT13h", "Extended MS-DOS Partition with INT13h")


$errormessage = ""
try {
    $localDisks = Get-Disk -ErrorAction Stop
    foreach ($disk in $localDisks) {
        $disk | Add-Member -MemberType NoteProperty -Name "ForList" -Value ("" + $disk.Number + " '" + $disk.FriendlyName + "', capacity " + [int]($disk.Size / 1024 / 1024 / 1024) + " GB, partition style '" + $disk.PartitionStyle + "', GUID (GPT only) "+$disk.Guid) -ErrorAction Stop
        $addMemberSplat = @{
            MemberType  = 'ScriptProperty'
            Name        = 'DisplayName'
            Value       = { $this.ForList }                  # getter
            SecondValue = { $this.ForList = $args[0] } # setter
        }
        $disk | Add-Member @addMemberSplat
    }
}
catch {
    $errormessage = $_.Exception.Message
}

[xml]$xamldisks = @"
<Window 
xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
x:Name="Window"
Title="Local disks - detailed information"
Height="700"
Width="800">
<StackPanel x:Name = "All" Margin="10">
<ListBox x:Name="DiskList" Height = "Auto" DisplayMemberPath = "DisplayName" Margin="5" />
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

    $DiskList = $windowdisks.FindName("DiskList")
    $DiskList.itemsSource = $localDisks
    $DiskList.Add_SelectionChanged({
            Clear-Host
            $StatusBox.Text = ""
            $DetailsPannel.Children.Clear()

            try {
                $disk = $DiskList.SelectedItem
                addTextToPanel -text "Disk details" -panel $DetailsPannel -bold $true
                addTextToPanel -text ("Friendly name: '" + $disk.FriendlyName + "'") -panel $DetailsPannel
                addTextToPanel -text ("Model: '" + $disk.Model + "'") -panel $DetailsPannel
                addTextToPanel -text ("Manufacturer: '" + $disk.Manufacturer + "'") -panel $DetailsPannel
                addTextToPanel -text ("Number: " + $disk.Number) -panel $DetailsPannel
                addTextToPanel -text ("Serial number: " + $disk.SerialNumber) -panel $DetailsPannel
                addTextToPanel -text ("Partition style: " + $disk.PartitionStyle) -panel $DetailsPannel
                addTextToPanel -text ("GUID (GPT partition style only): " + $disk.Guid) -panel $DetailsPannel
                addTextToPanel -text ("Unique Id: " + $disk.UniqueId) -panel $DetailsPannel
                addTextToPanel -text ("Health status: " + $disk.HealthStatus) -panel $DetailsPannel
                addTextToPanel -text ("Is boot: " + $disk.IsBoot) -panel $DetailsPannel
                addTextToPanel -text ("Number of partitions on disk: " + $disk.NumberOfPartitions) -panel $DetailsPannel
                addTextToPanel -text "" -panel $DetailsPannel

                foreach ($partition in (Get-Partition -DiskNumber $disk.Number -ErrorAction Stop)) {
                    addTextToPanel -text ("Partition " + $partition.PartitionNumber) -panel $DetailsPannel -bold $true
                    addTextToPanel -text ("GUID: " + $partition.Guid) -panel $DetailsPannel
                    addTextToPanel -text ("Is active: " + $partition.IsActive + ", is boot: " + $partition.IsBoot + ", is system " + $partition.IsSystem) -panel $DetailsPannel
                    addTextToPanel -text ("Size: " + $partition.Size) -panel $DetailsPannel
                    addTextToPanel -text ("Access paths: " + $partition.AccessPaths) -panel $DetailsPannel
                    if ($disk.PartitionStyle -eq "GPT") {
                        addTextToPanel -text ("GPT type: " + $gptTypes[$partition.GptType.Replace("{", "").Replace("}", "")] + " " + $partition.GptType) -panel $DetailsPannel
                    }
                    if ($disk.PartitionStyle -eq "MBR") {
                        addTextToPanel -text ("MBR type: " + $mbrTypes[$partition.MbrType] + " (" + $partition.MbrType + ")") -panel $DetailsPannel

                    }
                    addTextToPanel -text ("Operational status: " + $partition.OperationalStatus) -panel $DetailsPannel
                    addTextToPanel -text ("Transitional state: " + $transitionStates[$partition.TransitionState]) -panel $DetailsPannel
                    addTextToPanel -text ("Drive letter: " + $partition.DriveLetter) -panel $DetailsPannel
                    addTextToPanel -text "" -panel $DetailsPannel
                    addTextToPanel -text "Volumes" -panel $DetailsPannel -bold $true
                    foreach ($volume in (Get-Volume -Partition $partition -ErrorAction Stop)) {
                        addTextToPanel -text ("Drive letter: " + $volume.DriveLetter) -panel $DetailsPannel
                        addTextToPanel -text ("File system: " + $volume.FileSystem) -panel $DetailsPannel
                        addTextToPanel -text ("Label: '" + $volume.FileSystemLabel + "'") -panel $DetailsPannel
                        addTextToPanel -text ("Size: " + $volume.Size) -panel $DetailsPannel
                        addTextToPanel -text ("Object ID: " + $volume.ObjectId) -panel $DetailsPannel
                        addTextToPanel -text ("Path: " + $volume.Path) -panel $DetailsPannel
                        addTextToPanel -text ("Health status: " + $volume.HealthStatus) -panel $DetailsPannel
                        addTextToPanel -text ("Operational status: " + $volume.OperationalStatus) -panel $DetailsPannel
                        addTextToPanel -text "" -panel $DetailsPannel
                    }
                    addTextToPanel -text "" -panel $DetailsPannel
                }
            }
            catch {
                $StatusBox.Text = $_.Exception.Message
            }
        })

    $StatusBox = $windowdisks.FindName("Status")
    $StatusBox.Text = $errormessage

    $DetailsPannel = $windowdisks.FindName("ItemDetails")

    $windowdisks.ShowDialog() | Out-Null
    $windowdisks.Activate() | Out-Null

}
catch {
    Write-Host ($_.Exception.Message + " " + $_.ScriptStackTrace)
}