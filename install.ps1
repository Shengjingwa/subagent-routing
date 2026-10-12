<#
.SYNOPSIS
Install the subagent-routing rule for Cursor, Claude Code, and Codex.

.DESCRIPTION
Renders rules/subagent-routing.md with your tier models and the absolute path of
the details file, then:
  -Cursor  writes out/cursor-rule.md and copies it to the clipboard. Cursor keeps
           User Rules in its settings, so you paste the rule there yourself.
  -Claude  writes a marked block into CLAUDE.md in the Claude Code config directory.
  -Codex   writes a marked block into AGENTS.md (or a non-empty AGENTS.override.md)
           in the Codex home directory.
Run it again to change tiers; it replaces only its own block. -Uninstall removes
the blocks. A backup of each changed file is kept as <file>.subagent-routing.bak.

.EXAMPLE
./install.ps1 -Claude -Light haiku -Standard sonnet -Strong opus
#>
[CmdletBinding()]
param(
    [switch]$Cursor,
    [switch]$Claude,
    [switch]$Codex,
    [string]$Light = '',
    [string]$Standard = '',
    [string]$Strong = '',
    [switch]$Uninstall,
    [switch]$NoClipboard,
    # For tests: use this directory as the home directory and ignore
    # CLAUDE_CONFIG_DIR and CODEX_HOME.
    [string]$HomePath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$beginPrefix = '<!-- >>> subagent-routing'
$endPrefix = '<!-- <<< subagent-routing'
$root = $PSScriptRoot
$version = ([System.IO.File]::ReadAllText((Join-Path $root 'VERSION'))).Trim()
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Write-Usage {
    Write-Host 'Usage: ./install.ps1 [-Cursor] [-Claude] [-Codex] [-Light <model>] [-Standard <model>] [-Strong <model>] [-Uninstall] [-NoClipboard]'
    Write-Host 'Select at least one agent. Tiers you leave out stay as placeholders.'
}

function Test-ModelName {
    param([string]$Tier, [string]$Value)

    # Model ids and Cursor-style parameters such as name[effort=high]; nothing that can break the rule text.
    # \z, not $: in .NET, $ also matches before a final newline.
    if ($Value -and $Value -notmatch '^[A-Za-z0-9._:/=,+\[\]-]+\z') {
        throw "Invalid $Tier model '$Value'. Use the model id only, for example claude-sonnet-5-5 or sonnet."
    }
}

function Get-RenderedRule {
    $template = [System.IO.File]::ReadAllText((Join-Path $root 'rules/subagent-routing.md'))
    $details = (Resolve-Path -LiteralPath (Join-Path $root 'skills/subagent-routing/SKILL.md')).ProviderPath
    $values = @{
        '{{LIGHT_MODEL}}'    = $(if ($Light) { $Light } else { '<light-model>' })
        '{{STANDARD_MODEL}}' = $(if ($Standard) { $Standard } else { '<standard-model>' })
        '{{STRONG_MODEL}}'   = $(if ($Strong) { $Strong } else { '<strong-model>' })
        '{{DETAILS_PATH}}'   = $details
    }
    foreach ($key in $values.Keys) {
        $template = $template.Replace($key, $values[$key])
    }
    return $template.TrimEnd("`r", "`n")
}

function Read-TextFile {
    param([string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $offset = 0
    if ($hasBom) {
        $offset = 3
    }
    $text = (New-Object System.Text.UTF8Encoding $false).GetString($bytes, $offset, $bytes.Length - $offset)
    return [pscustomobject]@{ Text = $text; HasBom = $hasBom }
}

function Write-TextFile {
    param([string]$Path, [string]$Text, [bool]$HasBom)

    $encoding = New-Object System.Text.UTF8Encoding $HasBom
    [System.IO.File]::WriteAllText($Path, $Text, $encoding)
}

function Update-ManagedBlock {
    param([string]$Path, [string]$Body, [bool]$Remove)

    $existing = Test-Path -LiteralPath $Path -PathType Leaf
    if (-not $existing -and $Remove) {
        return 'not installed'
    }

    $text = ''
    $hasBom = $false
    if ($existing) {
        $file = Read-TextFile -Path $Path
        $text = $file.Text
        $hasBom = $file.HasBom
    }
    $newline = "`n"
    if ($text.Contains("`r`n")) {
        $newline = "`r`n"
    }

    $lines = New-Object System.Collections.Generic.List[string]
    if ($text.Trim()) {
        foreach ($line in ($text -split '\r?\n')) {
            $lines.Add($line)
        }
        if ($text.EndsWith("`n", [System.StringComparison]::Ordinal)) {
            # Splitting "a`nb`n" leaves an empty last element for the final newline.
            $lines.RemoveAt($lines.Count - 1)
        }
    }

    $ordinal = [System.StringComparison]::Ordinal
    $begins = @(for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].StartsWith($beginPrefix, $ordinal)) { $i } })
    $ends = @(for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].StartsWith($endPrefix, $ordinal)) { $i } })
    if ($begins.Count -gt 1 -or $ends.Count -gt 1 -or $begins.Count -ne $ends.Count -or ($begins.Count -eq 1 -and $ends[0] -lt $begins[0])) {
        throw "The subagent-routing block in $Path is damaged (unmatched or repeated markers). Fix it by hand, then run again."
    }

    if ($Remove) {
        if ($begins.Count -eq 0) {
            return 'not installed'
        }
        $start = $begins[0]
        $count = $ends[0] - $begins[0] + 1
        # Also remove the blank line that the installer put before the block.
        if ($start -gt 0 -and $lines[$start - 1] -eq '') {
            $start--
            $count++
        }
        $lines.RemoveRange($start, $count)
    }
    else {
        $blockLines = @("$beginPrefix v$version (managed by install script; run it again to change tiers) -->")
        $blockLines += @($Body -split '\r?\n')
        $blockLines += "$endPrefix -->"
        if ($begins.Count -eq 1) {
            $lines.RemoveRange($begins[0], $ends[0] - $begins[0] + 1)
            $lines.InsertRange($begins[0], [string[]]$blockLines)
        }
        else {
            if ($lines.Count -gt 0) {
                $lines.Add('')
            }
            $lines.AddRange([string[]]$blockLines)
        }
    }

    $newText = ''
    if ($lines.Count -gt 0) {
        $newText = ($lines -join $newline) + $newline
    }
    # -ceq: a case-only change to a model name is still a change.
    if ($existing -and $newText -ceq $text) {
        return 'already up to date'
    }

    if ($existing) {
        Copy-Item -LiteralPath $Path -Destination "$Path.subagent-routing.bak" -Force
    }
    if ($Remove -and -not $newText.Trim()) {
        if ((Get-Item -LiteralPath $Path -Force).LinkType) {
            # Deleting would remove the link and leave the block in its target.
            Write-TextFile -Path $Path -Text '' -HasBom $false
            return 'removed'
        }
        Remove-Item -LiteralPath $Path -Force
        return 'removed (the file held only this block; backup kept)'
    }
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Write-TextFile -Path $Path -Text $newText -HasBom $hasBom
    if ($Remove) {
        return 'removed'
    }
    if ($existing) {
        return 'installed'
    }
    return 'installed (new file)'
}

if (-not ($Cursor -or $Claude -or $Codex)) {
    Write-Usage
    exit 1
}
Test-ModelName -Tier 'light' -Value $Light
Test-ModelName -Tier 'standard' -Value $Standard
Test-ModelName -Tier 'strong' -Value $Strong

$homeDir = $HOME
$claudeDir = $null
$codexDir = $null
if ($HomePath) {
    $homeDir = $HomePath
    $claudeDir = Join-Path $homeDir '.claude'
    $codexDir = Join-Path $homeDir '.codex'
}
else {
    $claudeDir = $(if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $homeDir '.claude' })
    $codexDir = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $homeDir '.codex' })
}

$body = Get-RenderedRule
$placeholders = @()
if (-not $Light) { $placeholders += 'light' }
if (-not $Standard) { $placeholders += 'standard' }
if (-not $Strong) { $placeholders += 'strong' }

if ($Claude) {
    $target = Join-Path $claudeDir 'CLAUDE.md'
    $result = Update-ManagedBlock -Path $target -Body $body -Remove $Uninstall.IsPresent
    Write-Host "Claude Code: $result - $target"
}

if ($Codex) {
    $agentsFile = Join-Path $codexDir 'AGENTS.md'
    $override = Join-Path $codexDir 'AGENTS.override.md'
    if ($Uninstall) {
        $result = Update-ManagedBlock -Path $agentsFile -Body $body -Remove $true
        Write-Host "Codex: $result - $agentsFile"
        if (Test-Path -LiteralPath $override -PathType Leaf) {
            $result = Update-ManagedBlock -Path $override -Body $body -Remove $true
            Write-Host "Codex: $result - $override"
        }
    }
    elseif ((Test-Path -LiteralPath $override -PathType Leaf) -and (Get-Item -LiteralPath $override).Length -gt 0) {
        # Codex reads only the override file when it is not empty.
        $result = Update-ManagedBlock -Path $override -Body $body -Remove $false
        Write-Host "Codex: $result - $override"
        if ((Test-Path -LiteralPath $agentsFile -PathType Leaf) -and
            @((Read-TextFile -Path $agentsFile).Text -split '\r?\n' | Where-Object { $_.StartsWith($beginPrefix, [System.StringComparison]::Ordinal) }).Count -gt 0) {
            Write-Host "Codex: warning - $agentsFile still has a subagent-routing block. Codex ignores it while AGENTS.override.md is not empty. Run with -Uninstall -Codex to remove both blocks, then install again."
        }
    }
    else {
        $result = Update-ManagedBlock -Path $agentsFile -Body $body -Remove $false
        Write-Host "Codex: $result - $agentsFile"
    }
}

if ($Cursor) {
    $outFile = Join-Path (Join-Path $root 'out') 'cursor-rule.md'
    if ($Uninstall) {
        if (Test-Path -LiteralPath $outFile) {
            Remove-Item -LiteralPath $outFile -Force
        }
        Write-Host 'Cursor: remove the User Rule titled subagent-routing in Cursor Settings > Rules.'
    }
    else {
        New-Item -ItemType Directory -Path (Split-Path -Parent $outFile) -Force | Out-Null
        [System.IO.File]::WriteAllText($outFile, $body + "`n", $utf8NoBom)
        $copied = $false
        if (-not $NoClipboard) {
            try {
                Set-Clipboard -Value $body
                $copied = $true
            }
            catch {
                $copied = $false
            }
        }
        $where = $(if ($copied) { "$outFile and on the clipboard" } else { $outFile })
        Write-Host "Cursor: the rule is in $where."
        Write-Host '  Add it in Cursor Settings > Rules > User Rules with the title subagent-routing (replace the old one if it exists),'
        Write-Host "  or ask a Cursor agent: Add the content of $outFile as a user rule titled subagent-routing."
    }
}

if (-not $Uninstall) {
    if ($placeholders.Count -gt 0) {
        Write-Host "Placeholders left for: $($placeholders -join ', '). Run again with -Light, -Standard, -Strong to fill them."
    }
    Write-Host 'Start a new chat or session so that the agent loads the rule. To update, run git pull and this script again.'
}
