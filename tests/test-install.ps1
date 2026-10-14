# Tests for install.ps1. Run: pwsh -NoProfile -File tests/test-install.ps1 [-Shell powershell]
param(
    # The PowerShell executable that runs install.ps1: pwsh (7) or powershell (Windows PowerShell 5.1).
    [string]$Shell = 'pwsh'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$installer = Join-Path $root 'install.ps1'
$details = (Resolve-Path -LiteralPath (Join-Path $root 'skills/subagent-routing/SKILL.md')).ProviderPath
$failures = New-Object System.Collections.Generic.List[string]
$passed = 0

function Invoke-Installer {
    param([string[]]$Arguments)

    $output = & $Shell -NoProfile -ExecutionPolicy Bypass -File $installer @Arguments 2>&1 | Out-String
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}

function Assert-True {
    param([string]$Name, [bool]$Condition, [string]$Detail = '')

    if ($Condition) {
        $script:passed++
    }
    else {
        $script:failures.Add("$Name $Detail")
    }
}

function Read-Bytes { param([string]$Path) return [System.IO.File]::ReadAllBytes($Path) }
function Read-Utf8 { param([string]$Path) return [System.IO.File]::ReadAllText($Path) }
function Set-Utf8 { param([string]$Path, [string]$Text) [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding $false)) }
function Get-BlockCount {
    param([string]$Text)
    return ([regex]::Matches($Text, '(?m)^<!-- >>> subagent-routing')).Count
}

function New-TempHome {
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ('subagent-routing-test-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $path | Out-Null
    return $path
}

$homes = New-Object System.Collections.Generic.List[string]

# 1. No agent selected.
$r = Invoke-Installer -Arguments @()
Assert-True 'no agent exits 1' ($r.ExitCode -eq 1) "exit=$($r.ExitCode)"

# 2. Fresh install with tiers.
$h = New-TempHome; $homes.Add($h)
$r = Invoke-Installer -Arguments @('-Claude', '-Codex', '-Light', 'haiku', '-Standard', 'sonnet', '-Strong', 'opus', '-HomePath', $h)
$claudeFile = Join-Path $h '.claude/CLAUDE.md'
$codexFile = Join-Path $h '.codex/AGENTS.md'
Assert-True 'fresh install exits 0' ($r.ExitCode -eq 0) $r.Output
Assert-True 'claude file created' (Test-Path $claudeFile)
Assert-True 'codex file created' (Test-Path $codexFile)
$text = Read-Utf8 $claudeFile
Assert-True 'one block' ((Get-BlockCount $text) -eq 1)
Assert-True 'tiers rendered' ($text.Contains('- Light: `haiku`') -and $text.Contains('- Standard: `sonnet`') -and $text.Contains('- Strong: `opus`'))
Assert-True 'details path rendered' ($text.Contains($details))
Assert-True 'no template tokens' (-not $text.Contains('{{'))
Assert-True 'no BOM on new file' ((Read-Bytes $claudeFile)[0] -ne 0xEF)

# 3. Running again changes nothing.
$r = Invoke-Installer -Arguments @('-Claude', '-Light', 'haiku', '-Standard', 'sonnet', '-Strong', 'opus', '-HomePath', $h)
Assert-True 'rerun up to date' ($r.Output -match 'already up to date') $r.Output

# 4. Changing a tier replaces the block in place.
$r = Invoke-Installer -Arguments @('-Claude', '-Light', 'haiku,gemini-3.8-flash-high', '-Standard', 'sonnet', '-Strong', 'claude-opus-5-5[effort=high]', '-HomePath', $h)
$text = Read-Utf8 $claudeFile
Assert-True 'tier change keeps one block' ((Get-BlockCount $text) -eq 1)
Assert-True 'tier change applied' ($text.Contains('- Light: `haiku,gemini-3.8-flash-high`') -and $text.Contains('- Strong: `claude-opus-5-5[effort=high]`') -and -not $text.Contains('- Strong: `opus`'))
Assert-True 'backup written' (Test-Path "$claudeFile.subagent-routing.bak")
$r = Invoke-Installer -Arguments @('-Claude', '-Light', 'haiku', '-Standard', 'sonnet', '-Strong', 'Opus', '-HomePath', $h)
$r = Invoke-Installer -Arguments @('-Claude', '-Light', 'haiku', '-Standard', 'sonnet', '-Strong', 'opus', '-HomePath', $h)
Assert-True 'case-only tier change applied' ((Read-Utf8 $claudeFile).Contains('- Strong: `opus`')) $r.Output

# 5. Uninstall removes a file that held only the block.
$r = Invoke-Installer -Arguments @('-Claude', '-Codex', '-Uninstall', '-HomePath', $h)
Assert-True 'uninstall exits 0' ($r.ExitCode -eq 0) $r.Output
Assert-True 'block-only file removed' (-not (Test-Path $claudeFile))

# 6. Existing content, CRLF and BOM are kept; uninstall restores the original bytes.
$h = New-TempHome; $homes.Add($h)
New-Item -ItemType Directory -Path (Join-Path $h '.claude'), (Join-Path $h '.codex') | Out-Null
$claudeFile = Join-Path $h '.claude/CLAUDE.md'
$codexFile = Join-Path $h '.codex/AGENTS.md'
$originalLf = "# Mine`nkeep this line`n"
[System.IO.File]::WriteAllText($claudeFile, $originalLf, (New-Object System.Text.UTF8Encoding $false))
$originalCrlf = "# Codex rules`r`nkeep`r`n"
[System.IO.File]::WriteAllText($codexFile, $originalCrlf, (New-Object System.Text.UTF8Encoding $true))
$claudeBefore = Read-Bytes $claudeFile
$codexBefore = Read-Bytes $codexFile
$r = Invoke-Installer -Arguments @('-Claude', '-Codex', '-HomePath', $h)
$text = Read-Utf8 $claudeFile
Assert-True 'existing content kept' ($text.StartsWith($originalLf + "`n<!-- >>> subagent-routing"))
Assert-True 'placeholders without tiers' ($text.Contains('- Light: `<light-model>`') -and $text.Contains('- Strong: `<strong-model>`'))
Assert-True 'placeholder notice printed' ($r.Output -match 'Placeholders left for: light, standard, strong')
$codexBytes = Read-Bytes $codexFile
Assert-True 'BOM kept' ($codexBytes[0] -eq 0xEF -and $codexBytes[1] -eq 0xBB -and $codexBytes[2] -eq 0xBF)
$codexText = Read-Utf8 $codexFile
Assert-True 'CRLF kept' (-not ($codexText -replace "`r`n", '').Contains("`n"))
$r = Invoke-Installer -Arguments @('-Claude', '-Codex', '-Uninstall', '-HomePath', $h)
Assert-True 'uninstall restores LF file' ([System.Linq.Enumerable]::SequenceEqual([byte[]](Read-Bytes $claudeFile), [byte[]]$claudeBefore))
Assert-True 'uninstall restores CRLF BOM file' ([System.Linq.Enumerable]::SequenceEqual([byte[]](Read-Bytes $codexFile), [byte[]]$codexBefore))

# 6c. A missing final newline, mixed endings, and a whitespace-only file come back byte for byte.
$h = New-TempHome; $homes.Add($h)
New-Item -ItemType Directory -Path (Join-Path $h '.claude') | Out-Null
$claudeFile = Join-Path $h '.claude/CLAUDE.md'
Set-Utf8 $claudeFile 'mine'
$r = Invoke-Installer -Arguments @('-Claude', '-Strong', 'opus', '-HomePath', $h)
$text = Read-Utf8 $claudeFile
Assert-True 'no final newline: flagged marker' ($text.StartsWith("mine`n`n<!-- >>> subagent-routing", [System.StringComparison]::Ordinal) -and $text.Contains('; added a final newline)')) $r.Output
$r = Invoke-Installer -Arguments @('-Claude', '-Strong', 'sonnet', '-HomePath', $h)
$text = Read-Utf8 $claudeFile
Assert-True 'flag kept on tier change' ($text.Contains('; added a final newline)') -and $text.Contains('- Strong: `sonnet`')) $r.Output
$r = Invoke-Installer -Arguments @('-Claude', '-Uninstall', '-HomePath', $h)
Assert-True 'no final newline restored' ((Read-Utf8 $claudeFile) -ceq 'mine') $r.Output

Set-Utf8 $claudeFile 'mine'
$r = Invoke-Installer -Arguments @('-Claude', '-HomePath', $h)
[System.IO.File]::AppendAllText($claudeFile, "after`n")
$r = Invoke-Installer -Arguments @('-Claude', '-Uninstall', '-HomePath', $h)
Assert-True 'text after block keeps newline' ((Read-Utf8 $claudeFile) -ceq "mine`nafter`n") $r.Output

Set-Utf8 $claudeFile "a`r`nb"
$r = Invoke-Installer -Arguments @('-Claude', '-HomePath', $h)
$r = Invoke-Installer -Arguments @('-Claude', '-Uninstall', '-HomePath', $h)
Assert-True 'no final newline CRLF restored' ((Read-Utf8 $claudeFile) -ceq "a`r`nb") $r.Output

$mixed = "a`r`nb`nc`r`n"
Set-Utf8 $claudeFile $mixed
$r = Invoke-Installer -Arguments @('-Claude', '-HomePath', $h)
Assert-True 'mixed endings kept on install' ((Read-Utf8 $claudeFile).StartsWith($mixed, [System.StringComparison]::Ordinal)) $r.Output
Assert-True 'mixed endings: no flag when the file ended with a newline' (-not (Read-Utf8 $claudeFile).Contains('; added a final newline)'))
$r = Invoke-Installer -Arguments @('-Claude', '-Uninstall', '-HomePath', $h)
Assert-True 'mixed endings restored' ((Read-Utf8 $claudeFile) -ceq $mixed) $r.Output

Set-Utf8 $claudeFile "`n"
$r = Invoke-Installer -Arguments @('-Claude', '-HomePath', $h)
$r = Invoke-Installer -Arguments @('-Claude', '-Uninstall', '-HomePath', $h)
Assert-True 'whitespace-only file restored' ((Test-Path $claudeFile) -and (Read-Utf8 $claudeFile) -ceq "`n") $r.Output

# A last line that ends in a lone CR, a BOM file without a final newline, a file that
# holds only a BOM, and text that is not UTF-8 also come back byte for byte.
function Test-RoundTrip {
    param([string]$Name, [byte[]]$Original)

    [System.IO.File]::WriteAllBytes($claudeFile, $Original)
    $r = Invoke-Installer -Arguments @('-Claude', '-HomePath', $h)
    $r = Invoke-Installer -Arguments @('-Claude', '-Uninstall', '-HomePath', $h)
    $after = [byte[]]@()
    if (Test-Path $claudeFile) {
        $after = [System.IO.File]::ReadAllBytes($claudeFile)
    }
    Assert-True $Name ([System.Linq.Enumerable]::SequenceEqual($after, $Original)) $r.Output
}
Set-Utf8 $claudeFile "a`r"
$r = Invoke-Installer -Arguments @('-Claude', '-HomePath', $h)
$r = Invoke-Installer -Arguments @('-Claude', '-HomePath', $h)
Assert-True 'lone CR: rerun up to date' ($r.Output -match 'already up to date') $r.Output
$r = Invoke-Installer -Arguments @('-Claude', '-Uninstall', '-HomePath', $h)
Assert-True 'lone CR restored' ((Read-Utf8 $claudeFile) -ceq "a`r") $r.Output
Test-RoundTrip 'BOM without final newline restored' ([byte[]](0xEF, 0xBB, 0xBF, 0x6D, 0x69, 0x6E, 0x65))
Test-RoundTrip 'BOM-only file restored' ([byte[]](0xEF, 0xBB, 0xBF))
$latin1Bytes = [byte[]](0x63, 0x61, 0x66, 0xE9, 0x0A)
[System.IO.File]::WriteAllBytes($claudeFile, $latin1Bytes)
$r = Invoke-Installer -Arguments @('-Claude', '-HomePath', $h)
$installed = [System.IO.File]::ReadAllBytes($claudeFile)
Assert-True 'non-UTF-8 text kept on install' ([System.Linq.Enumerable]::SequenceEqual([byte[]]$installed[0..4], $latin1Bytes)) $r.Output
Test-RoundTrip 'non-UTF-8 text restored' $latin1Bytes

# 7. A non-empty AGENTS.override.md receives the block instead of AGENTS.md.
$h = New-TempHome; $homes.Add($h)
New-Item -ItemType Directory -Path (Join-Path $h '.codex') | Out-Null
$override = Join-Path $h '.codex/AGENTS.override.md'
[System.IO.File]::WriteAllText($override, "override`n", (New-Object System.Text.UTF8Encoding $false))
$r = Invoke-Installer -Arguments @('-Codex', '-HomePath', $h)
Assert-True 'override receives block' ((Get-BlockCount (Read-Utf8 $override)) -eq 1)
Assert-True 'AGENTS.md left alone' (-not (Test-Path (Join-Path $h '.codex/AGENTS.md')))

# 7b. An override added after install: install warns about the old block, uninstall removes both.
$h = New-TempHome; $homes.Add($h)
$agentsFile = Join-Path $h '.codex/AGENTS.md'
$override = Join-Path $h '.codex/AGENTS.override.md'
$r = Invoke-Installer -Arguments @('-Codex', '-HomePath', $h)
[System.IO.File]::WriteAllText($override, "override`n", (New-Object System.Text.UTF8Encoding $false))
$r = Invoke-Installer -Arguments @('-Codex', '-HomePath', $h)
Assert-True 'stale AGENTS.md block warned' ($r.Output -match 'still has a subagent-routing block') $r.Output
Assert-True 'override receives block after install' ((Get-BlockCount (Read-Utf8 $override)) -eq 1)
$r = Invoke-Installer -Arguments @('-Codex', '-Uninstall', '-HomePath', $h)
Assert-True 'uninstall removes AGENTS.md block' (-not (Test-Path $agentsFile)) $r.Output
Assert-True 'uninstall removes override block' ((Read-Utf8 $override) -eq "override`n") $r.Output
Assert-True 'uninstall reports both files' ($r.Output.Contains('AGENTS.md') -and $r.Output.Contains('AGENTS.override.md')) $r.Output

# 8. Invalid model name is refused and nothing is written.
$h = New-TempHome; $homes.Add($h)
$r = Invoke-Installer -Arguments @('-Claude', '-Light', 'bad`name', '-HomePath', $h)
Assert-True 'invalid model refused' ($r.ExitCode -ne 0) "exit=$($r.ExitCode)"
Assert-True 'invalid model writes nothing' (-not (Test-Path (Join-Path $h '.claude/CLAUDE.md')))
$r = Invoke-Installer -Arguments @('-Claude', '-Light', "haiku`n", '-HomePath', $h)
Assert-True 'model with trailing newline refused' ($r.ExitCode -ne 0) "exit=$($r.ExitCode)"
Assert-True 'trailing newline writes nothing' (-not (Test-Path (Join-Path $h '.claude/CLAUDE.md')))

# 9. A damaged block stops the installer and leaves the file unchanged.
New-Item -ItemType Directory -Path (Join-Path $h '.claude') | Out-Null
$damaged = Join-Path $h '.claude/CLAUDE.md'
[System.IO.File]::WriteAllText($damaged, "a`n<!-- >>> subagent-routing v0 -->`nhalf`n", (New-Object System.Text.UTF8Encoding $false))
$before = Read-Bytes $damaged
$r = Invoke-Installer -Arguments @('-Claude', '-HomePath', $h)
Assert-True 'damaged block refused' ($r.ExitCode -ne 0 -and $r.Output -match 'damaged') $r.Output
Assert-True 'damaged file unchanged' ([System.Linq.Enumerable]::SequenceEqual([byte[]](Read-Bytes $damaged), [byte[]]$before))

# 10. Cursor output has the rule without markers.
$outDir = Join-Path $root 'out'
$outDirExisted = Test-Path -LiteralPath $outDir
$outFile = Join-Path $outDir 'cursor-rule.md'
# The clone's out\cursor-rule.md may hold the user's own rendered rule.
$outBefore = if (Test-Path -LiteralPath $outFile) { [System.IO.File]::ReadAllBytes($outFile) } else { $null }
$r = Invoke-Installer -Arguments @('-Cursor', '-NoClipboard', '-Light', 'claude-haiku-5-5', '-HomePath', $h)
$cursorText = Read-Utf8 $outFile
Assert-True 'cursor rule written' ($cursorText.StartsWith('# Subagent routing') -and $cursorText.Contains('- Light: `claude-haiku-5-5`'))
Assert-True 'cursor rule has no markers' ((Get-BlockCount $cursorText) -eq 0)
$r = Invoke-Installer -Arguments @('-Cursor', '-Uninstall', '-HomePath', $h)
Assert-True 'cursor uninstall removes output' (-not (Test-Path $outFile))
if ($null -ne $outBefore) {
    [System.IO.File]::WriteAllBytes($outFile, $outBefore)
}
elseif (-not $outDirExisted) {
    Remove-Item -LiteralPath $outDir -Recurse -Force -ErrorAction SilentlyContinue
}

# 11. Uninstall through a symlink keeps the link and empties its target.
$h = New-TempHome; $homes.Add($h)
New-Item -ItemType Directory -Path (Join-Path $h '.claude') | Out-Null
$target = Join-Path $h 'real-CLAUDE.md'
$link = Join-Path $h '.claude/CLAUDE.md'
[System.IO.File]::WriteAllText($target, '', (New-Object System.Text.UTF8Encoding $false))
$linked = $true
try {
    New-Item -ItemType SymbolicLink -Path $link -Target $target -ErrorAction Stop | Out-Null
}
catch {
    $linked = $false
    Write-Host 'skip: symlink test (cannot create symbolic links here)'
}
if ($linked) {
    $r = Invoke-Installer -Arguments @('-Claude', '-HomePath', $h)
    Assert-True 'install through link writes target' ((Get-BlockCount (Read-Utf8 $target)) -eq 1) $r.Output
    $r = Invoke-Installer -Arguments @('-Claude', '-Uninstall', '-HomePath', $h)
    Assert-True 'uninstall keeps link' ([bool](Get-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue).LinkType) $r.Output
    Assert-True 'uninstall empties target' ((Get-Item -LiteralPath $target).Length -eq 0) $r.Output
}

foreach ($path in $homes) {
    Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "passed: $passed, failed: $($failures.Count)"
foreach ($failure in $failures) {
    Write-Host "FAIL: $failure"
}
if ($failures.Count -gt 0) {
    exit 1
}
