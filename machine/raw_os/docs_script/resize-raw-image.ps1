[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ImagePath,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[1-9][0-9]*([KMGTP]i?B?|[KMGTP])$')]
    [string]$NewSize,

    [switch]$ResizeBtrfs,

    [switch]$SkipBtrfsResize
)

$ErrorActionPreference = 'Stop'
$SectorSize = 512L
$GptEntryCount = 128L
$GptEntrySize = 128L
$GptHeaderSize = 92
$BtrfsSuperblockSize = 4096

if ($ResizeBtrfs -and $SkipBtrfsResize) {
    throw 'ResizeBtrfs and SkipBtrfsResize cannot be used together.'
}

function Read-Bytes([System.IO.FileStream]$Stream, [long]$Offset, [int]$Count) {
    $data = New-Object byte[] $Count
    $Stream.Seek($Offset, [System.IO.SeekOrigin]::Begin) | Out-Null
    $read = 0
    while ($read -lt $Count) {
        $n = $Stream.Read($data, $read, $Count - $read)
        if ($n -le 0) {
            throw "Unexpected end of file at offset $Offset."
        }
        $read += $n
    }
    return ,$data
}

function Write-Bytes([System.IO.FileStream]$Stream, [long]$Offset, [byte[]]$Data) {
    $Stream.Seek($Offset, [System.IO.SeekOrigin]::Begin) | Out-Null
    $Stream.Write($Data, 0, $Data.Length)
}

function Get-U32([byte[]]$Data, [int]$Offset) {
    return [BitConverter]::ToUInt32($Data, $Offset)
}

function Get-U64([byte[]]$Data, [int]$Offset) {
    return [BitConverter]::ToUInt64($Data, $Offset)
}

function Set-U32([byte[]]$Data, [int]$Offset, [uint32]$Value) {
    $bytes = [BitConverter]::GetBytes($Value)
    [Array]::Copy($bytes, 0, $Data, $Offset, 4)
}

function Set-U64([byte[]]$Data, [int]$Offset, [uint64]$Value) {
    $bytes = [BitConverter]::GetBytes($Value)
    [Array]::Copy($bytes, 0, $Data, $Offset, 8)
}

function Get-Crc32([byte[]]$Data, [int]$Offset, [int]$Count) {
    [uint32]$crc = [uint32]::MaxValue
    [uint32]$polynomial = [Convert]::ToUInt32('edb88320', 16)
    for ($i = $Offset; $i -lt ($Offset + $Count); $i++) {
        $crc = $crc -bxor [uint32]$Data[$i]
        for ($bit = 0; $bit -lt 8; $bit++) {
            if (($crc -band 1) -ne 0) {
                $crc = ($crc -shr 1) -bxor $polynomial
            } else {
                $crc = $crc -shr 1
            }
        }
    }
    return [uint32](-bnot $crc)
}

function Get-Crc32C([byte[]]$Data, [int]$Offset, [int]$Count) {
    [uint32]$crc = [uint32]::MaxValue
    [uint32]$polynomial = [Convert]::ToUInt32('82f63b78', 16)
    for ($i = $Offset; $i -lt ($Offset + $Count); $i++) {
        $crc = $crc -bxor [uint32]$Data[$i]
        for ($bit = 0; $bit -lt 8; $bit++) {
            if (($crc -band 1) -ne 0) {
                $crc = ($crc -shr 1) -bxor $polynomial
            } else {
                $crc = $crc -shr 1
            }
        }
    }
    return [uint32](-bnot $crc)
}

function Get-TargetBytes([string]$Size) {
    $match = [regex]::Match($Size, '^([1-9][0-9]*)([KMGTP]i?B?|[KMGTP])$')
    if (-not $match.Success) {
        throw "Invalid image size: $Size"
    }
    [long]$number = 0
    if (-not [long]::TryParse($match.Groups[1].Value, [Globalization.NumberStyles]::None, [Globalization.CultureInfo]::InvariantCulture, [ref]$number)) {
        throw "Invalid image size: $Size"
    }
    $multipliers = @{
        K = 1024L
        M = 1048576L
        G = 1073741824L
        T = 1099511627776L
        P = 1125899906842624L
    }
    $unit = $match.Groups[2].Value.Substring(0, 1).ToUpperInvariant()
    [long]$multiplier = $multipliers[$unit]
    if ($number -gt ([long]::MaxValue / $multiplier)) {
        throw "Image size is too large: $Size"
    }
    [long]$bytes = $number * $multiplier
    if (($bytes % $SectorSize) -ne 0) {
        throw "Image size must be a multiple of 512 bytes: $Size"
    }
    return [long]$bytes
}

if (-not (Test-Path -LiteralPath $ImagePath -PathType Leaf)) {
    throw "Image is not a regular file: $ImagePath"
}

$newBytes = Get-TargetBytes $NewSize
$stream = $null
$oldLength = 0L
$oldPrimaryHeader = $null
$oldPrimaryEntries = $null
$oldBackupHeader = $null
$oldBackupEntries = $null
$primaryEntriesOffset = 0L
$oldBackupEntriesLba = 0L
$oldBackupLba = 0L
$btrfsUpdates = @()
$canRollback = $false
$committed = $false

try {
    $stream = New-Object System.IO.FileStream(
        $ImagePath,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::ReadWrite,
        [System.IO.FileShare]::None
    )
    $oldLength = $stream.Length
    if (($oldLength % $SectorSize) -ne 0 -or $newBytes -le $oldLength) {
        throw "New size must be larger than the current sector-aligned image size."
    }

    $primaryHeader = Read-Bytes $stream $SectorSize $SectorSize
    $signature = [Text.Encoding]::ASCII.GetString($primaryHeader, 0, 8)
    if ($signature -ne 'EFI PART') {
        throw 'Image does not contain a GPT header.'
    }
    $headerSize = [int](Get-U32 $primaryHeader 12)
    if ($headerSize -lt $GptHeaderSize -or $headerSize -gt $SectorSize) {
        throw "Unsupported GPT header size: $headerSize"
    }
    if ((Get-U64 $primaryHeader 24) -ne 1L) {
        throw 'GPT primary header is not at LBA 1.'
    }

    $oldBackupLba = [long](Get-U64 $primaryHeader 32)
    $firstUsableLba = [long](Get-U64 $primaryHeader 40)
    $oldLastUsableLba = [long](Get-U64 $primaryHeader 48)
    $entryLba = [long](Get-U64 $primaryHeader 72)
    $entryCount = [long](Get-U32 $primaryHeader 80)
    $entrySize = [long](Get-U32 $primaryHeader 84)
    if ($entryCount -ne $GptEntryCount -or $entrySize -ne $GptEntrySize) {
        throw "Unsupported GPT partition entry layout: $entryCount x $entrySize."
    }
    $entryArrayBytes = $entryCount * $entrySize
    $entrySectors = [long](($entryArrayBytes + $SectorSize - 1) / $SectorSize)
    $primaryEntriesOffset = $entryLba * $SectorSize
    if ($primaryEntriesOffset -lt $SectorSize -or ($primaryEntriesOffset + $entryArrayBytes) -gt $oldLength) {
        throw 'GPT primary partition array is outside the image.'
    }
    $oldBackupEntriesLba = $oldBackupLba - $entrySectors
    if ($oldBackupLba -le 0 -or (($oldBackupEntriesLba * $SectorSize) + $entryArrayBytes) -gt $oldLength) {
        throw 'GPT backup partition array is outside the image.'
    }

    $oldPrimaryHeader = Read-Bytes $stream $SectorSize $SectorSize
    $oldPrimaryEntries = Read-Bytes $stream $primaryEntriesOffset $entryArrayBytes
    $oldBackupHeader = Read-Bytes $stream ($oldBackupLba * $SectorSize) $SectorSize
    $oldBackupEntries = Read-Bytes $stream ($oldBackupEntriesLba * $SectorSize) $entryArrayBytes

    $partition2Offset = $entrySize
    $partition2TypePresent = $false
    for ($i = 0; $i -lt 16; $i++) {
        if ($oldPrimaryEntries[$partition2Offset + $i] -ne 0) {
            $partition2TypePresent = $true
            break
        }
    }
    $partition2Start = [long](Get-U64 $oldPrimaryEntries ($partition2Offset + 32))
    $oldPartition2End = [long](Get-U64 $oldPrimaryEntries ($partition2Offset + 40))
    if (-not $partition2TypePresent -or $partition2Start -le 0 -or $oldPartition2End -lt $partition2Start) {
        throw 'GPT partition 2 is missing or invalid.'
    }

    $oldPartitionBytes = ($oldPartition2End - $partition2Start + 1L) * $SectorSize
    $newLastLba = ($newBytes / $SectorSize) - 1L
    $newBackupEntriesLba = $newLastLba - $entrySectors
    $newLastUsableLba = $newBackupEntriesLba - 1L
    if ($newLastUsableLba -le $oldLastUsableLba) {
        throw 'New image size does not provide a larger usable GPT area.'
    }
    $newPartitionBytes = ($newLastUsableLba - $partition2Start + 1L) * $SectorSize

    $btrfsUpdates = @()
    if ($ResizeBtrfs) {
        $btrfsOffsets = @(65536L, 67108864L, 274877906944L, 1125899906842624L)
        foreach ($relativeOffset in $btrfsOffsets) {
            if (($relativeOffset + $BtrfsSuperblockSize) -gt $oldPartitionBytes) {
                continue
            }
            $absoluteOffset = ($partition2Start * $SectorSize) + $relativeOffset
            $super = Read-Bytes $stream $absoluteOffset $BtrfsSuperblockSize
            $magic = [Text.Encoding]::ASCII.GetString($super, 64, 8)
            if ($magic -ne '_BHRfS_M' -or [long](Get-U64 $super 48) -ne $relativeOffset) {
                continue
            }
            $oldTotalBytes = [long](Get-U64 $super 112)
            if ($oldTotalBytes -le 0 -or $oldTotalBytes -gt $oldPartitionBytes) {
                throw "Invalid Btrfs total_bytes at relative offset $relativeOffset."
            }
            $btrfsUpdates += [pscustomobject]@{
                Offset = $absoluteOffset
                RelativeOffset = $relativeOffset
                Data = $super
                OldTotal = $oldTotalBytes
            }
        }
        if ($btrfsUpdates.Count -eq 0) {
            throw 'No valid Btrfs superblock was found in partition 2.'
        }
        $newBtrfsTotal = $newPartitionBytes - $SectorSize
        foreach ($update in $btrfsUpdates) {
            if ($update.OldTotal -ge $newBtrfsTotal) {
                throw 'New image size does not provide a larger Btrfs filesystem.'
            }
        }
    }

    $canRollback = $true
    $newPrimaryEntries = [byte[]]$oldPrimaryEntries.Clone()
    Set-U64 $newPrimaryEntries ($partition2Offset + 40) ([uint64]$newLastUsableLba)
    $newBackupEntries = [byte[]]$newPrimaryEntries.Clone()
    $partitionArrayCrc = Get-Crc32 $newPrimaryEntries 0 $newPrimaryEntries.Length

    $newPrimaryHeader = [byte[]]$oldPrimaryHeader.Clone()
    Set-U64 $newPrimaryHeader 32 ([uint64]$newLastLba)
    Set-U64 $newPrimaryHeader 48 ([uint64]$newLastUsableLba)
    Set-U64 $newPrimaryHeader 72 ([uint64]$entryLba)
    Set-U32 $newPrimaryHeader 88 $partitionArrayCrc
    Set-U32 $newPrimaryHeader 16 0
    Set-U32 $newPrimaryHeader 16 (Get-Crc32 $newPrimaryHeader 0 $headerSize)

    $newBackupHeader = [byte[]]$oldBackupHeader.Clone()
    Set-U64 $newBackupHeader 24 ([uint64]$newLastLba)
    Set-U64 $newBackupHeader 32 1
    Set-U64 $newBackupHeader 48 ([uint64]$newLastUsableLba)
    Set-U64 $newBackupHeader 72 ([uint64]$newBackupEntriesLba)
    Set-U32 $newBackupHeader 88 $partitionArrayCrc
    Set-U32 $newBackupHeader 16 0
    Set-U32 $newBackupHeader 16 (Get-Crc32 $newBackupHeader 0 $headerSize)

    $stream.SetLength($newBytes)
    Write-Bytes $stream ($newBackupEntriesLba * $SectorSize) $newBackupEntries
    Write-Bytes $stream ($newLastLba * $SectorSize) $newBackupHeader
    Write-Bytes $stream $primaryEntriesOffset $newPrimaryEntries
    Write-Bytes $stream $SectorSize $newPrimaryHeader

    if ($ResizeBtrfs) {
        foreach ($update in $btrfsUpdates) {
            $newSuper = [byte[]]$update.Data.Clone()
            Set-U64 $newSuper 112 ([uint64]$newBtrfsTotal)
            Set-U32 $newSuper 0 0
            Set-U32 $newSuper 0 (Get-Crc32C $newSuper 32 4064)
            Write-Bytes $stream $update.Offset $newSuper
        }
    }
    $stream.Flush($true)

    $verifyHeader = Read-Bytes $stream $SectorSize $SectorSize
    if ((Get-U64 $verifyHeader 32) -ne $newLastLba -or (Get-U64 $verifyHeader 48) -ne $newLastUsableLba) {
        throw 'Primary GPT verification failed.'
    }
    $verifyEntries = Read-Bytes $stream $primaryEntriesOffset $entryArrayBytes
    if ((Get-U64 $verifyEntries ($partition2Offset + 40)) -ne $newLastUsableLba) {
        throw 'GPT partition 2 verification failed.'
    }
    if ($ResizeBtrfs) {
        foreach ($update in $btrfsUpdates) {
            $verifySuper = Read-Bytes $stream $update.Offset $BtrfsSuperblockSize
            if ((Get-U64 $verifySuper 112) -ne $newBtrfsTotal -or (Get-Crc32C $verifySuper 32 4064) -ne (Get-U32 $verifySuper 0)) {
                throw "Btrfs superblock verification failed at relative offset $($update.RelativeOffset)."
            }
        }
    }
    $committed = $true
    $partitionGiB = [math]::Round($newPartitionBytes / 1GB, 2)
    Write-Output "image: $ImagePath"
    Write-Output "image size: $([math]::Round($newBytes / 1GB, 2)) GiB"
    Write-Output "partition 2 size: $partitionGiB GiB"
    if ($ResizeBtrfs) {
        Write-Output "Btrfs size: $([math]::Round($newBtrfsTotal / 1GB, 2)) GiB"
    } else {
        Write-Output 'Btrfs resize skipped'
    }
} catch {
    if ($stream -and $canRollback -and -not $committed) {
        try {
            if ($stream.Length -ne $oldLength) {
                $stream.SetLength($oldLength)
            }
            Write-Bytes $stream $SectorSize $oldPrimaryHeader
            Write-Bytes $stream $primaryEntriesOffset $oldPrimaryEntries
            Write-Bytes $stream ($oldBackupEntriesLba * $SectorSize) $oldBackupEntries
            Write-Bytes $stream ($oldBackupLba * $SectorSize) $oldBackupHeader
            foreach ($update in $btrfsUpdates) {
                Write-Bytes $stream $update.Offset $update.Data
            }
            $stream.Flush($true)
        } catch {
            throw "Resize failed and rollback also failed: $($_.Exception.Message)"
        }
    }
    throw
} finally {
    if ($stream) {
        $stream.Dispose()
    }
}
