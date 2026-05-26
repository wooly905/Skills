<#
.SYNOPSIS
    Install Agent Skills to the user-level shared path (~/.claude/skills/).

.PARAMETER Skill
    Name of a single skill folder to install. If omitted, installs all skills.

.EXAMPLE
    .\install.ps1
    .\install.ps1 -Skill youtube-transcript
#>
param(
    [string]$Skill
)

$TargetRoot = Join-Path $env:USERPROFILE ".claude\skills"

$Exclude = @(".git", ".gitignore", "README.md", "install.ps1")

if ($Skill) {
    $SourcePath = Join-Path $PSScriptRoot $Skill
    if (-not (Test-Path $SourcePath)) {
        Write-Error "Skill '$Skill' not found at $SourcePath"
        exit 1
    }
    $TargetPath = Join-Path $TargetRoot $Skill
    New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
    Copy-Item "$SourcePath\*" $TargetPath -Recurse -Force
    Write-Host "Installed '$Skill' to $TargetPath" -ForegroundColor Green
}
else {
    $Skills = Get-ChildItem -Path $PSScriptRoot -Directory |
        Where-Object { $_.Name -notin $Exclude -and -not $_.Name.StartsWith(".") }

    if ($Skills.Count -eq 0) {
        Write-Warning "No skill folders found."
        exit 0
    }

    foreach ($s in $Skills) {
        $TargetPath = Join-Path $TargetRoot $s.Name
        New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
        Copy-Item "$($s.FullName)\*" $TargetPath -Recurse -Force
        Write-Host "Installed '$($s.Name)' to $TargetPath" -ForegroundColor Green
    }
}

Write-Host "`nDone. Skills are now available in Claude Code, GitHub Copilot, and Cursor." -ForegroundColor Cyan
