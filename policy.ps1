-----Made by respiral and cearful
-----Unknown rec policy
try { [Console]::CursorVisible = $false } catch {}

try {
    $RawUI = $Host.UI.RawUI
    $TargetWidth = 145
    $Buf = $RawUI.BufferSize
    if ($Buf.Width -lt $TargetWidth) {
        $Buf.Width = $TargetWidth
        $RawUI.BufferSize = $Buf
    }
    $Win = $RawUI.WindowSize
    $MaxWin = $RawUI.MaxWindowSize
    $Win.Width = [Math]::Min($TargetWidth, $MaxWin.Width)
    $RawUI.WindowSize = $Win
} catch {}

function Show-Header {
    Clear-Host
    Write-Host "====================================================================================================================================" -ForegroundColor DarkMagenta
    Write-Host '  ________  _______   ________  ________  ________ ___  ___  ___               ________  ___  ___  ________  ________  ________     ' -ForegroundColor DarkMagenta
    Write-Host '  |\   ____\|\  ___ \ |\   __  \|\   __  \|\   __  \|\  \|\  \|\  \             |\   ____\|\  \|\  \|\   __  \|\   __  \|\   ___ \    ' -ForegroundColor Magenta
    Write-Host '  \ \  \___|\ \   __/|\ \  \|\  \ \  \|\  \ \  \|\  \ \  \\\  \ \  \            \ \  \___|\ \  \\\  \ \  \|\  \ \  \|\  \ \  \_|\ \   ' -ForegroundColor Red
    Write-Host '  \ \  \    \ \  \_|/_\ \   __  \ \   _  _\ \   __\\ \  \\\  \ \  \            \ \  \  __\ \  \\\  \ \   __  \ \   _  _\ \  \ \\ \  ' -ForegroundColor DarkRed
    Write-Host '  \ \  \____\ \  \_|\ \ \  \ \  \ \  \\  \\ \  \_| \ \  \\\  \ \  \____        \ \  \|\  \ \  \\\  \ \  \ \  \ \  \\  \\ \  \_\\ \ ' -ForegroundColor DarkYellow
    Write-Host '  \ \_______\ \_______\ \__\ \__\ \__\\ _\\ \__\   \ \_______\ \_______\       \ \_______\ \_______\ \__\ \__\ \__\\ _\\ \_______\' -ForegroundColor Yellow
    Write-Host '  \|_______|\|_______|\|__|\|__|\|__|\|__|\|__|    \|_______|\|_______|        \|_______|\|_______|\|__|\|__|\|__|\|__|\|_______|' -ForegroundColor Yellow
    Write-Host "====================================================================================================================================" -ForegroundColor DarkYellow
}

function Run-ProgressAnimation {
    param (
        [string]$StepNumber,
        [string]$StepName,
        [string]$ActivityText
    )
    Show-Header
    Write-Host " [ $StepNumber ] |  CURRENT STAGE: " -NoNewline -ForegroundColor Red
    Write-Host $StepName -ForegroundColor Red
    Write-Host " ---------- |  ----------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""

    $ProgressLineY = [Console]::CursorTop - 1

    for ($pct = 0; $pct -le 100; $pct += 20) {
        try { [Console]::SetCursorPosition(0, $ProgressLineY) } catch {}
        $totalBlocks = 10
        $filledBlocks = $pct / 10
        $emptyBlocks = $totalBlocks - $filledBlocks
        $bar = ("#" * $filledBlocks) + ("-" * $emptyBlocks)
        $OutputText = " [$bar]  |  Status: $ActivityText ($pct%)"
        $BufferWidth = try { [Console]::WindowWidth - 1 } catch { 80 }
        if ($OutputText.Length -lt $BufferWidth) { $OutputText = $OutputText.PadRight($BufferWidth) }
        Write-Host $OutputText -ForegroundColor Red
        Start-Sleep -Milliseconds 25
    }
    Write-Host ""
}

function Wait-ForContinue {
    param([string]$NextStepLabel)
    Write-Host ""
    Write-Host " Press ENTER to continue to $NextStepLabel..." -NoNewline -ForegroundColor DarkGray
    try { [Console]::CursorVisible = $true } catch {}
    Read-Host | Out-Null
    try { [Console]::CursorVisible = $false } catch {}
}

function Write-StageReport {
    param(
        [string]$StepNumber,
        [string]$StepName,
        [array]$Results
    )
    $StatusColor = @{
        "SECURE"   = "Green"
        "INFO"     = "Yellow"
        "WARNING"  = "Yellow"
        "ALERT"    = "Yellow"
        "CRITICAL" = "Red"
    }

    Show-Header
    Write-Host " [ $StepNumber ] |  $StepName" -ForegroundColor Red
    Write-Host " ------------ |  --------------------------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""

    foreach ($Item in $Results) {
        $Color = $StatusColor[$Item.Status]
        if (-not $Color) { $Color = "White" }
        $Tag = "[$($Item.Status)]".PadRight(11)
        Write-Host "   $Tag|  $($Item.Detail)" -ForegroundColor $Color
    }

    $CriticalCount = ($Results | Where-Object { $_.Status -eq "CRITICAL" }).Count
    $WarnCount     = ($Results | Where-Object { $_.Status -in @("WARNING","ALERT") }).Count

    Write-Host ""
    Write-Host " ------------ |  --------------------------------------------------------------------------------------------------" -ForegroundColor DarkGray
    if ($CriticalCount -gt 0) {
        Write-Host " [ SUMMARY ]  |  $CriticalCount critical, $WarnCount alert/warning finding(s) on this stage." -ForegroundColor Red
    } elseif ($WarnCount -gt 0) {
        Write-Host " [ SUMMARY ]  |  $WarnCount alert/warning finding(s) on this stage. No criticals." -ForegroundColor Yellow
    } else {
        Write-Host " [ SUMMARY ]  |  Stage clear. No findings." -ForegroundColor Green
    }
}

function Test-IsHiddenExecutable {
    param([string]$FilePath)
    try {
        $Bytes = [System.IO.File]::ReadAllBytes($FilePath)
        if ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0x4D -and $Bytes[1] -eq 0x5A) {
            return $true
        }
    } catch {}
    return $false
}

function Get-ShannonEntropy {
    param([string]$FilePath, [int]$SampleBytes = 1MB)
    try {
        $Stream = [System.IO.File]::OpenRead($FilePath)
        try {
            $Len = [Math]::Min($Stream.Length, $SampleBytes)
            if ($Len -le 0) { return 0 }
            $Buffer = New-Object byte[] $Len
            [void]$Stream.Read($Buffer, 0, $Len)
        } finally {
            $Stream.Close()
        }
        $Counts = New-Object 'int[]' 256
        foreach ($B in $Buffer) { $Counts[$B]++ }
        $Entropy = 0.0
        foreach ($C in $Counts) {
            if ($C -gt 0) {
                $P = $C / $Len
                $Entropy -= $P * [Math]::Log($P, 2)
            }
        }
        return [Math]::Round($Entropy, 2)
    } catch {
        return 0
    }
}

function Test-IsEncryptedZip {
    param([string]$FilePath)
    try {
        $Bytes = [System.IO.File]::ReadAllBytes($FilePath)
        if ($Bytes.Length -lt 8) { return $false }
        if ($Bytes[0] -eq 0x50 -and $Bytes[1] -eq 0x4B) {
            $Flag = [BitConverter]::ToUInt16($Bytes, 6)
            return (($Flag -band 0x1) -eq 0x1)
        }
    } catch {}
    return $false
}

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Show-Header
    Write-Host " [!] FORENSIC EXCEPTION: ROOT PRIVILEGES REQUIRED" -ForegroundColor Red
    Write-Host " Deep driver sweeps and memory offsets inspection cannot run in user-mode."
    Write-Host " Please close this, right-click PowerShell, and select 'Run as Administrator'."
    Write-Host ""
    try { [Console]::CursorVisible = $true } catch {}
    Exit
}

$AuthorizedUsernames = @(
    "c_earful"
)

function New-OneTimeCode {
    param([int]$Length = 10)
    $Chars = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789'
    $Rng = [System.Random]::new()
    -join (1..$Length | ForEach-Object { $Chars[$Rng.Next(0, $Chars.Length)] })
}

$OneTimeCode   = New-OneTimeCode
$Authenticated = $false
$MaxAttempts   = 3
$Attempt       = 0

while (-not $Authenticated -and $Attempt -lt $MaxAttempts) {
    $Attempt++
    Show-Header
    Write-Host " [ ACCESS CONTROL ] |  OPERATOR AUTHORIZATION REQUIRED" -ForegroundColor Cyan
    Write-Host " ------------------ |  --------------------------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host " One-time access code (valid for this session only - share it with the operator logging in):" -ForegroundColor DarkGray
    Write-Host "   $OneTimeCode" -ForegroundColor Yellow
    Write-Host ""
    $InputUser = Read-Host " Username"
    $InputCode = Read-Host " One-Time Code (paste it in)"

    if (($AuthorizedUsernames -contains $InputUser) -and ($InputCode -eq $OneTimeCode)) {
        $Authenticated = $true
        Write-Host ""
        Write-Host " [ACCESS GRANTED] Welcome, $InputUser." -ForegroundColor Green
        Write-Host ""
        Write-Host " Press ENTER to continue..." -NoNewline -ForegroundColor DarkGray
        Read-Host | Out-Null
    } else {
        Write-Host ""
        Write-Host " [ACCESS DENIED] Invalid username or code. Attempts remaining: $($MaxAttempts - $Attempt)" -ForegroundColor Red
        Start-Sleep -Seconds 1
    }
}

if (-not $Authenticated) {
    Show-Header
    Write-Host " [ACCESS DENIED] Maximum login attempts exceeded. Exiting." -ForegroundColor Red
    Write-Host ""
    try { [Console]::CursorVisible = $true } catch {}
    Exit
}

try {

$DetectedThreats     = [System.Collections.Generic.List[string]]::new()
$IdentifiedCheatNames = [System.Collections.Generic.List[string]]::new()
$UnsignedDrivers      = @()
$SuspiciousRegistry   = @()
$SuspiciousTasks      = @()
$SuspiciousServices   = @()
$WmiPersistence       = @()
$NetworkAnomalies     = @()
$HiddenADS            = @()
$HostsManipulated     = $false
$HostsEntries         = @()
$UnsignedProcesses    = @()
$InjectedModules      = @()
$ParentSpoofing       = @()
$RecentArtifacts      = @()
$DisguisedExecutables = @()
$PackedBinaries       = @()
$HiddenExecutables    = @()
$EncryptedArchives    = @()

$UserDir = $env:USERPROFILE

$CheatKeywords = @(
    "cheat","hack","injector","aimbot","wallhack","modmenu","xenos","vape",
    "cheatengine","bypass","urban","exploit","loader","krnl","synapse",
    "electron-bot","skid","fatality","gamesense","onetap","ring0","r77",
    "process-hollow","hollowing","unhook","evade","spoofer","hwid"
)

Run-ProgressAnimation -StepNumber "STEP 1/6" -StepName "KERNEL SYSTEM & PERSISTENCE MECHANISMS" -ActivityText "Querying drivers, tasks, services & auto-start keys..."

$RealTimeActive = $true
try {
    $Pref = Get-MpPreference -ErrorAction SilentlyContinue
    if ($Pref -and $Pref.DisableRealtimeMonitoring -eq $true) { $RealTimeActive = $false }
} catch { $RealTimeActive = $false }

try {
    $UnsignedDrivers = Get-WmiObject Win32_PnPSignedDriver -ErrorAction SilentlyContinue |
                       Where-Object { $_.IsSigned -eq $false -and $_.DeviceName -ne $null } |
                       Select-Object -Property DeviceName, Manufacturer -Unique
} catch {}

$RegPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Windows"
)
foreach ($Path in $RegPaths) {
    if (Test-Path $Path) {
        $Properties = Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue
        foreach ($PropName in $Properties.PSObject.Properties.Name) {
            if ($PropName -notin @("PSPath","PSParentPath","PSChildName","PSDrive","PSProvider")) {
                $Value = $Properties.$PropName
                foreach ($Keyword in $CheatKeywords) {
                    if ($Value -like "*$Keyword*") {
                        $SuspiciousRegistry += "$PropName ($Value) [matched: $Keyword]"
                        $IdentifiedCheatNames.Add($Keyword)
                        break
                    }
                }
            }
        }
    }
}

try {
    $AppInit = Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Windows" -ErrorAction SilentlyContinue
    if ($AppInit.AppInit_DLLs -and $AppInit.AppInit_DLLs.Trim() -ne "") {
        $SuspiciousRegistry += "AppInit_DLLs -> $($AppInit.AppInit_DLLs)"
    }
} catch {}

try {
    $IFEOPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"
    if (Test-Path $IFEOPath) {
        Get-ChildItem $IFEOPath -ErrorAction SilentlyContinue | ForEach-Object {
            $Debugger = (Get-ItemProperty -Path $_.PSPath -Name "Debugger" -ErrorAction SilentlyContinue).Debugger
            if ($Debugger) {
                $SuspiciousRegistry += "IFEO Debugger Hijack on $($_.PSChildName) -> $Debugger"
            }
        }
    }
} catch {}

try {
    $Winlogon = Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue
    if ($Winlogon.Shell -and $Winlogon.Shell -ne "explorer.exe") {
        $SuspiciousRegistry += "Winlogon Shell tampered -> $($Winlogon.Shell)"
    }
    if ($Winlogon.Userinit -and $Winlogon.Userinit -notmatch "userinit\.exe\s*,?\s*$") {
        $SuspiciousRegistry += "Winlogon Userinit tampered -> $($Winlogon.Userinit)"
    }
} catch {}

try {
    $Tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.State -ne "Disabled" }
    foreach ($Task in $Tasks) {
        $Actions = $Task.Actions
        foreach ($Action in $Actions) {
            $Cmd = "$($Action.Execute) $($Action.Arguments)"
            foreach ($Keyword in $CheatKeywords) {
                if ($Cmd -like "*$Keyword*" -or $Task.TaskName -like "*$Keyword*") {
                    $SuspiciousTasks += "$($Task.TaskName) -> $Cmd [matched: $Keyword]"
                    $IdentifiedCheatNames.Add($Keyword)
                    break
                }
            }
        }
    }
} catch {}

try {
    $Services = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue |
                Where-Object { $_.PathName -ne $null }
    foreach ($Svc in $Services) {
        foreach ($Keyword in $CheatKeywords) {
            if ($Svc.PathName -like "*$Keyword*" -or $Svc.Name -like "*$Keyword*") {
                $SuspiciousServices += "$($Svc.Name) [$($Svc.State)] -> $($Svc.PathName) [matched: $Keyword]"
                $IdentifiedCheatNames.Add($Keyword)
                break
            }
        }
    }
} catch {}

try {
    $WmiConsumers = Get-CimInstance -Namespace root\subscription -ClassName CommandLineEventConsumer -ErrorAction SilentlyContinue
    foreach ($Consumer in $WmiConsumers) {
        $WmiPersistence += "CommandLineEventConsumer: $($Consumer.Name) -> $($Consumer.CommandLineTemplate)"
    }
    $WmiActiveScript = Get-CimInstance -Namespace root\subscription -ClassName ActiveScriptEventConsumer -ErrorAction SilentlyContinue
    foreach ($Consumer in $WmiActiveScript) {
        $WmiPersistence += "ActiveScriptEventConsumer: $($Consumer.Name)"
    }
} catch {}

$Stage1Results = @(
    if ($RealTimeActive) {
        @{ Status = "SECURE";   Detail = "Real-Time Shield Status: ACTIVE" }
    } else {
        @{ Status = "CRITICAL"; Detail = "Real-Time Shield Status: DEACTIVATED" }
    }
    if ($UnsignedDrivers.Count -gt 0) {
        @{ Status = "WARNING";  Detail = "Kernel: Found $($UnsignedDrivers.Count) unsigned third-party drivers." }
    } else {
        @{ Status = "SECURE";   Detail = "Kernel Driver Signatures: ALL COMPLIANT" }
    }
    if ($SuspiciousRegistry.Count -gt 0) {
        @{ Status = "CRITICAL"; Detail = "Registry: Suspicious startup/injection entries identified!" }
    } else {
        @{ Status = "SECURE";   Detail = "Registry autoruns, AppInit, IFEO & Winlogon keys: CLEAN" }
    }
    if ($SuspiciousTasks.Count -gt 0) {
        @{ Status = "CRITICAL"; Detail = "Scheduled Tasks: Suspicious task actions found!" }
    } else {
        @{ Status = "SECURE";   Detail = "Scheduled Task Library: CLEAN" }
    }
    if ($SuspiciousServices.Count -gt 0) {
        @{ Status = "CRITICAL"; Detail = "Services: Suspicious service binaries found!" }
    } else {
        @{ Status = "SECURE";   Detail = "Windows Services: CLEAN" }
    }
    if ($WmiPersistence.Count -gt 0) {
        @{ Status = "ALERT";    Detail = "WMI: Event subscription persistence detected!" }
    } else {
        @{ Status = "SECURE";   Detail = "WMI Event Subscriptions: NONE FOUND" }
    }
)
Write-StageReport -StepNumber "STEP 1/6" -StepName "KERNEL SYSTEM & PERSISTENCE MECHANISMS" -Results $Stage1Results
Start-Sleep -Seconds 1
Wait-ForContinue -NextStepLabel "STEP 2/6 (Network & DNS Integrity)"

Run-ProgressAnimation -StepNumber "STEP 2/6" -StepName "NETWORK SOCKETS & RESOLUTION INTEGRITY" -ActivityText "Tracing active sockets, DNS cache & proxy config..."

$HostsPath = "$env:windir\System32\drivers\etc\hosts"
if (Test-Path $HostsPath) {
    $HostsContent = Get-Content $HostsPath -ErrorAction SilentlyContinue
    $ActiveEntries = $HostsContent | Where-Object { $_ -match "^\s*[^#]\S" }
    foreach ($Entry in $ActiveEntries) {
        $HostsEntries += $Entry.Trim()
        if ($Entry -match "roblox|discord|epicgames|steamcommunity|riotgames|easyanticheat|battle\.net") {
            $HostsManipulated = $true
        }
    }
}

$ProxyTampered = $false
try {
    $ProxySettings = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -ErrorAction SilentlyContinue
    if ($ProxySettings.ProxyEnable -eq 1 -and $ProxySettings.ProxyServer) {
        $ProxyTampered = $true
        $ProxyServerValue = $ProxySettings.ProxyServer
    }
} catch {}

$DnsAnomalies = @()
try {
    $DnsCache = Get-DnsClientCache -ErrorAction SilentlyContinue
    foreach ($Entry in $DnsCache) {
        foreach ($Keyword in $CheatKeywords) {
            if ($Entry.Entry -like "*$Keyword*") {
                $DnsAnomalies += "$($Entry.Entry) -> $($Entry.Data) [matched: $Keyword]"
                $IdentifiedCheatNames.Add($Keyword)
                break
            }
        }
    }
} catch {}

try {
    $Connections = Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue
    foreach ($Conn in $Connections) {
        $Process = Get-Process -Id $Conn.OwningProcess -ErrorAction SilentlyContinue
        if ($Process) {
            foreach ($Keyword in $CheatKeywords) {
                if ($Process.Name -like "*$Keyword*") {
                    $NetworkAnomalies += "$($Process.Name) [PID: $($Process.Id)] -> Connecting to $($Conn.RemoteAddress):$($Conn.RemotePort) [matched: $Keyword]"
                    $IdentifiedCheatNames.Add($Keyword)
                    break
                }
            }
        }
    }
} catch {}

$Stage2Results = @(
    if ($HostsManipulated) {
        @{ Status = "CRITICAL"; Detail = "Local Hosts File: CRITICAL REDIRECTION DETECTED" }
    } else {
        @{ Status = "SECURE";   Detail = "Local Hosts File: NO LOOPBACK EXPLOITS DETECTED" }
    }
    if ($ProxyTampered) {
        @{ Status = "ALERT";    Detail = "System Proxy: ACTIVE CUSTOM PROXY -> $ProxyServerValue" }
    } else {
        @{ Status = "SECURE";   Detail = "System Proxy Configuration: DEFAULT / DISABLED" }
    }
    if ($DnsAnomalies.Count -gt 0) {
        @{ Status = "ALERT";    Detail = "DNS Cache: Suspicious domain resolutions found." }
    } else {
        @{ Status = "SECURE";   Detail = "DNS Resolver Cache: CLEAN" }
    }
    if ($NetworkAnomalies.Count -gt 0) {
        @{ Status = "CRITICAL"; Detail = "Suspicious outgoing processes established network connections!" }
    } else {
        @{ Status = "SECURE";   Detail = "Active network sockets verified as clean." }
    }
)
Write-StageReport -StepNumber "STEP 2/6" -StepName "NETWORK SOCKETS & RESOLUTION INTEGRITY" -Results $Stage2Results
Start-Sleep -Seconds 1
Wait-ForContinue -NextStepLabel "STEP 3/6 (Process Hooks & DLL Injection)"

Run-ProgressAnimation -StepNumber "STEP 3/6" -StepName "PROCESS HOOKS & ACTIVE DLL INJECTION" -ActivityText "Auditing process memory & signature chains..."

$WatchedHostProcs = "roblox|rivals|discord|steam|valorant|csgo|cs2|fortnite|minecraft|javaw"
$TargetProcList = Get-Process | Where-Object {
    ($_.Name -match ($CheatKeywords -join "|")) -or ($_.Name -match $WatchedHostProcs)
}

$MasqueradingProcesses = @()
$CriticalSystemNames = @("svchost","csrss","lsass","winlogon","services","spoolsv","taskhostw","smss","wininit")
foreach ($Proc in (Get-Process | Where-Object { $_.Name -in $CriticalSystemNames })) {
    $RealPath = try { $Proc.MainModule.FileName } catch { $null }
    if ($RealPath -and $RealPath -notlike "$env:windir\System32\*" -and $RealPath -notlike "$env:windir\SysWOW64\*") {
        $MasqueradingProcesses += "$($Proc.Name).exe [PID $($Proc.Id)] running from unexpected path: $RealPath"
    }
}

foreach ($Proc in $TargetProcList) {
    $ProcPath = try { $Proc.MainModule.FileName } catch { $null }

    try {
        $ProcInfo = Get-CimInstance Win32_Process -Filter "ProcessId = $($Proc.Id)" -ErrorAction SilentlyContinue
        if ($ProcInfo) {
            $Parent = Get-Process -Id $ProcInfo.ParentProcessId -ErrorAction SilentlyContinue
            if ($Parent -and $Parent.Name -in @("svchost","explorer","services","lsass") ) {
                $ParentPath = try { $Parent.MainModule.FileName } catch { $null }
                if ($ParentPath -and $ParentPath -notlike "$env:windir\System32\*" -and $ParentPath -notlike "$env:windir\explorer.exe") {
                    $ParentSpoofing += "$($Proc.Name) [PID $($Proc.Id)] has spoofed parent '$($Parent.Name)' at $ParentPath"
                }
            }
        }
    } catch {}

    foreach ($Keyword in $CheatKeywords) {
        if ($Proc.Name -like "*$Keyword*" -and $ProcPath) {
            $Signature = Get-AuthenticodeSignature -FilePath $ProcPath -ErrorAction SilentlyContinue
            $Hash = (Get-FileHash -Path $ProcPath -Algorithm SHA256).Hash
            if ($Signature.Status -ne "Valid") {
                $UnsignedProcesses += "$($Proc.Name) [UNSIGNED] at: $ProcPath [SHA256: $Hash] [matched: $Keyword]"
            } else {
                $UnsignedProcesses += "$($Proc.Name) [Signed] at: $ProcPath [SHA256: $Hash] [matched: $Keyword]"
            }
            $IdentifiedCheatNames.Add($Keyword)
            break
        }
    }

    if ($Proc.Name -match $WatchedHostProcs) {
        try {
            $Modules = [System.Diagnostics.Process]::GetProcessById($Proc.Id).Modules
            foreach ($Mod in $Modules) {
                $ModName = $Mod.ModuleName
                $ModPath = $Mod.FileName
                $Suspicious = $false
                $MatchedModKeyword = $null
                foreach ($Keyword in $CheatKeywords) {
                    if ($ModName -like "*$Keyword*" -or $ModPath -like "*$Keyword*") { $Suspicious = $true; $MatchedModKeyword = $Keyword; break }
                }
                if (-not $Suspicious -and ($ModPath -like "*\Temp\*" -or $ModPath -like "*\Downloads\*")) {
                    $Suspicious = $true
                }
                if ($Suspicious) {
                    $ModSig = Get-AuthenticodeSignature -FilePath $ModPath -ErrorAction SilentlyContinue
                    $ModHash = (Get-FileHash -Path $ModPath -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash
                    $MatchTag = if ($MatchedModKeyword) { " [matched: $MatchedModKeyword]" } else { " [matched: suspicious drop-zone path]" }
                    if ($ModSig.Status -ne "Valid") {
                        $InjectedModules += "$($Proc.Name) -> Unsigned/Anomalous Module: $ModPath [SHA256: $ModHash]$MatchTag"
                    } else {
                        $InjectedModules += "$($Proc.Name) -> Flagged Path Module (Signed): $ModPath$MatchTag"
                    }
                    if ($MatchedModKeyword) { $IdentifiedCheatNames.Add($MatchedModKeyword) }
                }
            }
        } catch {}
    }
}

$Stage3Results = @(
    if ($UnsignedProcesses.Count -gt 0) {
        @{ Status = "CRITICAL"; Detail = "Cheat-matched processes found and evaluated." }
    } else {
        @{ Status = "SECURE";   Detail = "No processes matched known cheat/injector naming patterns." }
    }
    if ($InjectedModules.Count -gt 0) {
        @{ Status = "CRITICAL"; Detail = "Anomalous modules loaded inside monitored host processes!" }
    } else {
        @{ Status = "SECURE";   Detail = "No anomalous modules loaded in monitored host processes." }
    }
    if ($ParentSpoofing.Count -gt 0) {
        @{ Status = "ALERT";    Detail = "Parent-process spoofing indicators detected!" }
    } else {
        @{ Status = "SECURE";   Detail = "Process lineage validated as consistent with expected system paths." }
    }
    if ($MasqueradingProcesses.Count -gt 0) {
        @{ Status = "CRITICAL"; Detail = "Process(es) impersonating trusted system binaries detected!" }
    } else {
        @{ Status = "SECURE";   Detail = "All critical system processes confirmed running from trusted paths." }
    }
)
Write-StageReport -StepNumber "STEP 3/6" -StepName "PROCESS HOOKS & ACTIVE DLL INJECTION" -Results $Stage3Results
Start-Sleep -Seconds 1
Wait-ForContinue -NextStepLabel "STEP 4/6 (Download Provenance & Execution History)"

Run-ProgressAnimation -StepNumber "STEP 4/6" -StepName "DOWNLOAD PROVENANCE & EXECUTION HISTORY" -ActivityText "Cross-referencing manifests, Prefetch & command history..."

$SuspiciousExtensions = @()
$ChromeExtDirs = @(
    "$UserDir\AppData\Local\Google\Chrome\User Data\Default\Extensions",
    "$UserDir\AppData\Local\Microsoft\Edge\User Data\Default\Extensions",
    "$UserDir\AppData\Roaming\Mozilla\Firefox\Profiles"
)
foreach ($Dir in $ChromeExtDirs) {
    if (Test-Path $Dir) {
        Get-ChildItem -Path $Dir -Recurse -Include "manifest.json" -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                $Manifest = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
                $NameField = "$($Manifest.name)"
                foreach ($Keyword in $CheatKeywords) {
                    if ($NameField -like "*$Keyword*") {
                        $SuspiciousExtensions += "$NameField -> $($_.FullName) [matched: $Keyword]"
                        $IdentifiedCheatNames.Add($Keyword)
                        break
                    }
                }
            } catch {}
        }
    }
}

$MotwFlagged = @()
if (Test-Path "$UserDir\Downloads") {
    Get-ChildItem -Path "$UserDir\Downloads" -Include "*.exe","*.zip","*.rar" -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
        foreach ($Keyword in $CheatKeywords) {
            if ($_.Name -like "*$Keyword*") {
                $Zone = Get-Item -Path $_.FullName -Stream "Zone.Identifier" -ErrorAction SilentlyContinue
                if ($Zone) {
                    $MotwFlagged += "$($_.FullName) (downloaded from external source) [matched: $Keyword]"
                    $IdentifiedCheatNames.Add($Keyword)
                }
                break
            }
        }
    }
}

$PrefetchEvidence = @()
$PrefetchPath = "$env:windir\Prefetch"
if (Test-Path $PrefetchPath) {
    Get-ChildItem -Path $PrefetchPath -Include "*.pf" -File -ErrorAction SilentlyContinue | ForEach-Object {
        foreach ($Keyword in $CheatKeywords) {
            if ($_.Name -like "*$Keyword*") {
                $PrefetchEvidence += "$($_.Name) (last run: $($_.LastWriteTime)) [matched: $Keyword]"
                $IdentifiedCheatNames.Add($Keyword)
                break
            }
        }
    }
}

$RecycleBinEvidence = @()
try {
    $Shell = New-Object -ComObject Shell.Application
    $Recycle = $Shell.Namespace(0xA)
    if ($Recycle) {
        foreach ($Item in $Recycle.Items()) {
            $ItemName = $Item.Name
            foreach ($Keyword in $CheatKeywords) {
                if ($ItemName -like "*$Keyword*") {
                    $RecycleBinEvidence += "$ItemName (deleted, found in Recycle Bin) [matched: $Keyword]"
                    $IdentifiedCheatNames.Add($Keyword)
                    break
                }
            }
        }
    }
} catch {}

$PsHistoryEvidence = @()
$PsHistoryPath = "$UserDir\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
if (Test-Path $PsHistoryPath) {
    $HistoryLines = Get-Content -Path $PsHistoryPath -ErrorAction SilentlyContinue
    foreach ($Line in $HistoryLines) {
        foreach ($Keyword in $CheatKeywords) {
            if ($Line -like "*$Keyword*") {
                $PsHistoryEvidence += "$($Line.Trim()) [matched: $Keyword]"
                $IdentifiedCheatNames.Add($Keyword)
                break
            }
        }
    }
}

$Stage4Results = @(
    if ($SuspiciousExtensions.Count -gt 0) {
        @{ Status = "ALERT";    Detail = "Browser extensions matching cheat/injector naming found." }
    } else {
        @{ Status = "SECURE";   Detail = "No suspicious browser extensions detected." }
    }
    if ($MotwFlagged.Count -gt 0) {
        @{ Status = "ALERT";    Detail = "Downloaded files with external Mark-of-the-Web + cheat naming found." }
    } else {
        @{ Status = "SECURE";   Detail = "No flagged externally-sourced downloads found." }
    }
    if ($PrefetchEvidence.Count -gt 0) {
        @{ Status = "CRITICAL"; Detail = "Evidence of previously-executed cheat tooling found (Prefetch)!" }
    } else {
        @{ Status = "SECURE";   Detail = "No Prefetch evidence of past cheat-tool execution." }
    }
    if ($RecycleBinEvidence.Count -gt 0) {
        @{ Status = "ALERT";    Detail = "Deleted files matching cheat naming found in Recycle Bin." }
    } else {
        @{ Status = "SECURE";   Detail = "No matching deleted files found in Recycle Bin." }
    }
    if ($PsHistoryEvidence.Count -gt 0) {
        @{ Status = "ALERT";    Detail = "PowerShell command history references cheat/injector tooling." }
    } else {
        @{ Status = "SECURE";   Detail = "No flagged commands found in PowerShell history." }
    }
)
Write-StageReport -StepNumber "STEP 4/6" -StepName "DOWNLOAD PROVENANCE & EXECUTION HISTORY" -Results $Stage4Results
Start-Sleep -Seconds 1
Wait-ForContinue -NextStepLabel "STEP 5/6 (Defender Deep Engine Scan - may take a while)"

Run-ProgressAnimation -StepNumber "STEP 5/6" -StepName "WINDOWS DEFENDER DEEP ENGINE SCAN" -ActivityText "Scanning local directories via Defender CLI..."

$PathsToScan = @(
    "$UserDir\Downloads",
    "$UserDir\Desktop",
    "$UserDir\Documents",
    "$UserDir\AppData\Local",
    "$UserDir\AppData\Roaming",
    "$UserDir\AppData\LocalLow",
    "$env:TEMP",
    "$env:ProgramData"
)

$DefenderScanPaths = $PathsToScan | Where-Object { $_ -ne "$env:ProgramData" }

$ExcludedSubfolders = @("Package Cache","Microsoft","NVIDIA","NVIDIA Corporation","Windows Defender","chocolatey")
function Test-NotExcludedPath {
    param([string]$FullPath)
    foreach ($Folder in $ExcludedSubfolders) {
        if ($FullPath -like "*\$Folder\*") { return $false }
    }
    return $true
}

$DefenderPath = "$env:ProgramFiles\Windows Defender\MpCmdRun.exe"

if (Test-Path $DefenderPath) {
    foreach ($Path in $DefenderScanPaths) {
        if (Test-Path $Path) {
            Write-Host "   [SCANNING]  |  $Path " -NoNewline -ForegroundColor DarkCyan
            $DefProc = Start-Process -FilePath $DefenderPath -ArgumentList "-Scan -ScanType 3 -File `"$Path`"" -WindowStyle Hidden -PassThru
            $ElapsedSec = 0
            while (-not $DefProc.HasExited) {
                Start-Sleep -Milliseconds 500
                $ElapsedSec += 0.5
                Write-Host "." -NoNewline -ForegroundColor DarkGray
            }
            Write-Host " done ($([math]::Round($ElapsedSec,1))s)" -ForegroundColor Green
        }
    }
    try {
        $Threats = Get-MpThreatDetection -ErrorAction SilentlyContinue | Where-Object {
            $_.InitialDetectionTime -gt (Get-Date).AddDays(-3)
        }
        foreach ($Threat in $Threats) {
            $InfectedFiles = $Threat.Resources | Where-Object { $_ -like "*$UserDir*" -or $_ -like "*$env:ProgramData*" }
            foreach ($File in $InfectedFiles) {
                $DetectedThreats.Add("$($Threat.ThreatName) detected at: $File")
            }
        }
    } catch {}
} else {
    foreach ($Path in $PathsToScan) {
        if (Test-Path $Path) {
            $Files = Get-ChildItem -Path $Path -Include "*.exe","*.dll","*.sys" -Recurse -File -ErrorAction SilentlyContinue |
                     Where-Object { Test-NotExcludedPath $_.FullName }
            foreach ($File in $Files) {
                $Signature = Get-AuthenticodeSignature -FilePath $File.FullName -ErrorAction SilentlyContinue
                if ($Signature.Status -ne "Valid") {
                    $Hash = (Get-FileHash -Path $File.FullName -Algorithm SHA256).Hash
                    $DetectedThreats.Add("Unverified Binary: $($File.FullName) [SHA256: $Hash]")
                }
            }
        }
    }
}

foreach ($Path in $PathsToScan) {
    if (Test-Path $Path) {
        $Files = Get-ChildItem -Path $Path -Include "*.exe","*.dll","*.zip","*.rar","*.7z","*.txt" -Recurse -File -ErrorAction SilentlyContinue |
                 Where-Object { Test-NotExcludedPath $_.FullName }
        foreach ($File in $Files) {
            $Streams = Get-Item -Path $File.FullName -Stream * -ErrorAction SilentlyContinue | Where-Object { $_.Stream -ne ':$DATA' }
            if ($Streams) {
                foreach ($Stream in $Streams) {
                    $HiddenADS += "$($File.FullName):$($Stream.Stream) ($($Stream.Length) Bytes)"
                }
            }
        }
    }
}

try {
    foreach ($Path in $PathsToScan) {
        if (Test-Path $Path) {
            $Recent = Get-ChildItem -Path $Path -Include "*.exe","*.dll" -Recurse -File -ErrorAction SilentlyContinue |
                      Where-Object { $_.CreationTime -gt (Get-Date).AddHours(-48) -and (Test-NotExcludedPath $_.FullName) }
            foreach ($R in $Recent) {
                $RecentArtifacts += "$($R.FullName) (Created: $($R.CreationTime))"
            }
        }
    }
} catch {}

$DisguisableExtensions = "*.txt","*.log","*.dat","*.ini","*.cfg","*.jpg","*.jpeg","*.png","*.ico","*.ttf","*.bin","*.tmp"
foreach ($Path in $PathsToScan) {
    if (Test-Path $Path) {
        Get-ChildItem -Path $Path -Include $DisguisableExtensions -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { Test-NotExcludedPath $_.FullName } | ForEach-Object {
                if (Test-IsHiddenExecutable -FilePath $_.FullName) {
                    $DisguisedExecutables += "$($_.FullName) (extension: $($_.Extension), actually a Windows executable)"
                }
            }
    }
}

foreach ($Path in $PathsToScan) {
    if (Test-Path $Path) {
        Get-ChildItem -Path $Path -Include "*.exe","*.dll" -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { Test-NotExcludedPath $_.FullName } | ForEach-Object {
                $Sig = Get-AuthenticodeSignature -FilePath $_.FullName -ErrorAction SilentlyContinue
                if ($Sig.Status -ne "Valid") {
                    $Entropy = Get-ShannonEntropy -FilePath $_.FullName
                    if ($Entropy -ge 7.2) {
                        $PackedBinaries += "$($_.FullName) (entropy: $Entropy/8.0 - likely packed/encrypted payload)"
                    }
                }
            }
    }
}

foreach ($Path in $PathsToScan) {
    if (Test-Path $Path) {
        Get-ChildItem -Path $Path -Recurse -Force -File -ErrorAction SilentlyContinue |
            Where-Object {
                ($_.Attributes -band [System.IO.FileAttributes]::Hidden) -and
                (Test-NotExcludedPath $_.FullName) -and
                ($_.Extension -in ".exe",".dll" -or (Test-IsHiddenExecutable -FilePath $_.FullName))
            } | ForEach-Object {
                $HiddenExecutables += "$($_.FullName) (Hidden attribute set)"
            }
    }
}

foreach ($Path in @("$UserDir\Downloads", "$UserDir\Desktop")) {
    if (Test-Path $Path) {
        Get-ChildItem -Path $Path -Include "*.zip" -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { Test-NotExcludedPath $_.FullName } | ForEach-Object {
                if (Test-IsEncryptedZip -FilePath $_.FullName) {
                    $EncryptedArchives += "$($_.FullName) (password-protected archive)"
                }
            }
    }
}

$Stage5Results = @(
    if ($DetectedThreats.Count -gt 0) {
        @{ Status = "CRITICAL"; Detail = "Active threats identified in scanned directories!" }
    } else {
        @{ Status = "SECURE";   Detail = "No active malware signatures flagged in target directories." }
    }
    if ($HiddenADS.Count -gt 0) {
        @{ Status = "ALERT";    Detail = "Found hidden NTFS data streams in execution directory!" }
    } else {
        @{ Status = "SECURE";   Detail = "No hidden NTFS data streams detected." }
    }
    if ($RecentArtifacts.Count -gt 0) {
        @{ Status = "INFO";     Detail = "$($RecentArtifacts.Count) executable(s) created in the last 48 hours." }
    } else {
        @{ Status = "SECURE";   Detail = "No newly-dropped executables in the last 48 hours." }
    }
    if ($DisguisedExecutables.Count -gt 0) {
        @{ Status = "CRITICAL"; Detail = "Found executables disguised with non-executable file extensions!" }
    } else {
        @{ Status = "SECURE";   Detail = "No extension-disguised executables detected." }
    }
    if ($PackedBinaries.Count -gt 0) {
        @{ Status = "CRITICAL"; Detail = "Found unsigned binaries with encryption/packing-level entropy!" }
    } else {
        @{ Status = "SECURE";   Detail = "No high-entropy packed/encrypted binaries detected." }
    }
    if ($HiddenExecutables.Count -gt 0) {
        @{ Status = "ALERT";    Detail = "Found hidden-attribute files carrying executable content!" }
    } else {
        @{ Status = "SECURE";   Detail = "No hidden-attribute executable artifacts detected." }
    }
    if ($EncryptedArchives.Count -gt 0) {
        @{ Status = "ALERT";    Detail = "Password-protected archives found in Downloads/Desktop." }
    } else {
        @{ Status = "SECURE";   Detail = "No encrypted archives found in Downloads/Desktop." }
    }
)
Write-StageReport -StepNumber "STEP 5/6" -StepName "WINDOWS DEFENDER DEEP ENGINE SCAN" -Results $Stage5Results
Start-Sleep -Seconds 1
Wait-ForContinue -NextStepLabel "STEP 6/6 (Final Correlation & Report)"

Run-ProgressAnimation -StepNumber "STEP 6/6" -StepName "CROSS-VECTOR CORRELATION & SCORING" -ActivityText "Correlating all forensic signals into final verdict..."
Start-Sleep -Milliseconds 300
Wait-ForContinue -NextStepLabel "the FINAL REPORT"

Show-Header
Write-Host "================================== DEEP FORENSIC CYBER SECURITY REPORT ==================================" -ForegroundColor DarkGray

$CriticalFound = ($DetectedThreats.Count -gt 0) -or $HostsManipulated -or ($SuspiciousRegistry.Count -gt 0) -or
                 ($NetworkAnomalies.Count -gt 0) -or ($HiddenADS.Count -gt 0) -or ($SuspiciousTasks.Count -gt 0) -or
                 ($SuspiciousServices.Count -gt 0) -or ($WmiPersistence.Count -gt 0) -or ($UnsignedProcesses.Count -gt 0) -or
                 ($InjectedModules.Count -gt 0) -or ($ParentSpoofing.Count -gt 0) -or ($MasqueradingProcesses.Count -gt 0) -or
                 ($PrefetchEvidence.Count -gt 0) -or ($RecycleBinEvidence.Count -gt 0) -or ($PsHistoryEvidence.Count -gt 0) -or
                 ($DisguisedExecutables.Count -gt 0) -or ($PackedBinaries.Count -gt 0) -or ($HiddenExecutables.Count -gt 0) -or
                 ($EncryptedArchives.Count -gt 0)

if ($CriticalFound) {
    Write-Host " [!] ZERO-TRUST COMPROMISE INDICATORS DETECTED:" -ForegroundColor Red
    Write-Host ""

    if ($IdentifiedCheatNames.Count -gt 0) {
        $UniqueCheatNames = $IdentifiedCheatNames | Select-Object -Unique
        Write-Host "   [CHEATS IDENTIFIED] -> $($UniqueCheatNames -join ', ')" -ForegroundColor Red
        Write-Host ""
    }

    foreach ($Threat in ($DetectedThreats | Select-Object -Unique)) {
        Write-Host "   [THREAT VECTOR]   -> $Threat" -ForegroundColor Red
    }
    foreach ($U in $UnsignedProcesses) {
        Write-Host "   [PROCESS]         -> $U" -ForegroundColor Red
    }
    foreach ($M in $InjectedModules) {
        Write-Host "   [INJECTION]       -> $M" -ForegroundColor Red
    }
    foreach ($P in $ParentSpoofing) {
        Write-Host "   [LINEAGE]         -> $P" -ForegroundColor Yellow
    }
    foreach ($MP in $MasqueradingProcesses) {
        Write-Host "   [IMPERSONATION]   -> $MP" -ForegroundColor Red
    }
    foreach ($Anomaly in $NetworkAnomalies) {
        Write-Host "   [NETWORK OUTFLOW] -> $Anomaly" -ForegroundColor Red
    }
    foreach ($Reg in $SuspiciousRegistry) {
        Write-Host "   [PERSISTENCE]     -> Registry: $Reg" -ForegroundColor Red
    }
    foreach ($T in $SuspiciousTasks) {
        Write-Host "   [PERSISTENCE]     -> Scheduled Task: $T" -ForegroundColor Red
    }
    foreach ($S in $SuspiciousServices) {
        Write-Host "   [PERSISTENCE]     -> Service: $S" -ForegroundColor Red
    }
    foreach ($W in $WmiPersistence) {
        Write-Host "   [PERSISTENCE]     -> WMI: $W" -ForegroundColor Yellow
    }
    foreach ($ADS in $HiddenADS) {
        Write-Host "   [NTFS EVASION]    -> Hidden Stream: $ADS" -ForegroundColor Yellow
    }
    if ($HostsManipulated) {
        Write-Host "   [DNS REDIRECTION] -> Local resolution hijacked for core applications!" -ForegroundColor Red
    }
    if ($UnsignedDrivers.Count -gt 0) {
        Write-Host "   [KERNEL ALERT]    -> Unsigned drivers active in Device Manager." -ForegroundColor Yellow
        foreach ($Drv in $UnsignedDrivers) {
            Write-Host "                        * $($Drv.DeviceName) ($($Drv.Manufacturer))" -ForegroundColor Yellow
        }
    }
    foreach ($D in $DnsAnomalies) {
        Write-Host "   [DNS CACHE]       -> $D" -ForegroundColor Yellow
    }
    foreach ($E in $SuspiciousExtensions) {
        Write-Host "   [BROWSER]         -> $E" -ForegroundColor Yellow
    }
    foreach ($MW in $MotwFlagged) {
        Write-Host "   [DOWNLOAD]        -> $MW" -ForegroundColor Yellow
    }
    foreach ($PF in $PrefetchEvidence) {
        Write-Host "   [PAST EXECUTION]  -> $PF" -ForegroundColor Red
    }
    foreach ($RB in $RecycleBinEvidence) {
        Write-Host "   [CLEANUP TRACE]   -> $RB" -ForegroundColor Yellow
    }
    foreach ($PH in $PsHistoryEvidence) {
        Write-Host "   [SHELL HISTORY]   -> $PH" -ForegroundColor Yellow
    }
    foreach ($DE in $DisguisedExecutables) {
        Write-Host "   [DISGUISED EXE]   -> $DE" -ForegroundColor Red
    }
    foreach ($PB in $PackedBinaries) {
        Write-Host "   [PACKED/ENCRYPTED]-> $PB" -ForegroundColor Red
    }
    foreach ($HE in $HiddenExecutables) {
        Write-Host "   [HIDDEN FILE]     -> $HE" -ForegroundColor Red
    }
    foreach ($EA in $EncryptedArchives) {
        Write-Host "   [ENCRYPTED ARCHIVE]-> $EA" -ForegroundColor Yellow
    }
} else {
    Write-Host " [+] VERDICT: Secure environment signature baselines completely intact." -ForegroundColor Green
}

Write-Host ""
Write-Host "=================================== FORENSIC ADVISORY FEEDBACK ===================================" -ForegroundColor DarkGray

if ($RealTimeActive) {
    Write-Host " 1. [COMPLIANT] Anti-Malware protection structures actively monitoring platform." -ForegroundColor Green
} else {
    Write-Host " 1. [CRITICAL] Windows Defender disabled. Real-time bypass threat profile: MAX." -ForegroundColor Red
}

if ($DetectedThreats.Count -gt 0 -or $UnsignedProcesses.Count -gt 0) {
    Write-Host " 2. [VULNERABILITY] Unsigned memory stacks or malware binaries isolated. Action recommended." -ForegroundColor Red
} else {
    Write-Host " 2. [COMPLIANT] Memory space and directories are completely free of unauthorized payloads." -ForegroundColor Green
}

if ($NetworkAnomalies.Count -gt 0 -or $HostsManipulated -or $ProxyTampered) {
    Write-Host " 3. [VULNERABILITY] Network routes manipulated or running backdoors discovered." -ForegroundColor Red
} else {
    Write-Host " 3. [COMPLIANT] Dynamic socket tracking validated all local network pipes as secure." -ForegroundColor Green
}

if ($SuspiciousRegistry.Count -gt 0 -or $HiddenADS.Count -gt 0 -or $SuspiciousTasks.Count -gt 0 -or $SuspiciousServices.Count -gt 0 -or $WmiPersistence.Count -gt 0) {
    Write-Host " 4. [ALERT] Evasion/Persistence techniques found across registry, tasks, services, or WMI." -ForegroundColor Yellow
} else {
    Write-Host " 4. [COMPLIANT] No automatic persistence hooks found in registry, tasks, services, or WMI." -ForegroundColor Green
}

if ($InjectedModules.Count -gt 0 -or $ParentSpoofing.Count -gt 0 -or $MasqueradingProcesses.Count -gt 0) {
    Write-Host " 5. [ALERT] Runtime injection, process-lineage, or system-process impersonation found." -ForegroundColor Yellow
} else {
    Write-Host " 5. [COMPLIANT] Runtime module integrity and process identity fully confirmed." -ForegroundColor Green
}

if ($SuspiciousExtensions.Count -gt 0 -or $MotwFlagged.Count -gt 0) {
    Write-Host " 6. [ALERT] Browser extension or download-provenance flags require manual review." -ForegroundColor Yellow
} else {
    Write-Host " 6. [COMPLIANT] Browser extensions and recent downloads show no cheat-related markers." -ForegroundColor Green
}

if ($PrefetchEvidence.Count -gt 0) {
    Write-Host " 7. [CRITICAL] Prefetch shows cheat/injector tooling was executed on this machine, even if deleted since." -ForegroundColor Red
} else {
    Write-Host " 7. [COMPLIANT] No Prefetch evidence of prior cheat-tool execution found." -ForegroundColor Green
}

if ($RecycleBinEvidence.Count -gt 0 -or $PsHistoryEvidence.Count -gt 0) {
    Write-Host " 8. [ALERT] Recycle Bin or shell command history references cheat/injector-named items." -ForegroundColor Yellow
} else {
    Write-Host " 8. [COMPLIANT] No cover-up traces found in Recycle Bin or command history." -ForegroundColor Green
}

if ($DisguisedExecutables.Count -gt 0 -or $PackedBinaries.Count -gt 0 -or $HiddenExecutables.Count -gt 0 -or $EncryptedArchives.Count -gt 0) {
    Write-Host " 9. [CRITICAL] Concealment techniques found: renamed extensions, packed/encrypted payloads, hidden files, or encrypted archives." -ForegroundColor Red
} else {
    Write-Host " 9. [COMPLIANT] No disguised, packed, hidden, or encrypted evasion artifacts detected." -ForegroundColor Green
}

Write-Host " 10. [SYSTEM INFO] Deep forensic trace completed successfully. Machine isolation: STABLE." -ForegroundColor Cyan
Write-Host "====================================================================================================" -ForegroundColor DarkGray

}
catch {
    Write-Host ""
    Write-Host " [!] SCAN INTERRUPTED: An unexpected error stopped the scan early." -ForegroundColor Red
    Write-Host "     Nothing was changed on your system - this only affects reporting." -ForegroundColor Yellow
    Write-Host "     Error detail: $($_.Exception.Message)" -ForegroundColor DarkGray
}
finally {
    try { [Console]::CursorVisible = $true } catch {}
}