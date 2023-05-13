function New-SymbolicLink {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SourceFolder,
        [Parameter(Mandatory=$true)]
        [string]$TargetFolder
    )

    # Check if the source folder exists
    if (-not (Test-Path -Path $SourceFolder -PathType Container)) {
        Write-Error "The source folder '$SourceFolder' does not exist."
        return
    }

    # Check if the target folder exists
    if (-not (Test-Path -Path $TargetFolder -PathType Container)) {
        Write-Error "The target folder '$TargetFolder' does not exist."
        return
    }

    # Create the symbolic link
    try {
        cmd /c mklink /D $TargetFolder $SourceFolder | Out-Null
    }
    catch {
        Write-Error "Failed to create symbolic link: $_"
        return
    }

    Write-Output "Symbolic link created from '$SourceFolder' to '$TargetFolder'."
}

# Global Variables
# # Define the directory of the script being run
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Dotfiles = Split-Path $ScriptDir -Parent
# Define the user's home directory
$HOME = [Environment]::GetFolderPath("UserProfile")

$foldersToLink = @(
    @{
        SourceFolder = "$Dotfiles\\.config\\nvim"
        TargetFolder = "$HOME\\AppData\\Local\\nvim"
    },
)

foreach ($folder in $foldersToLink) {
    $sourceFolder = $folder.SourceFolder
    $targetFolder = $folder.TargetFolder

    Write-Host "Creating symbolic link"
    Write-Host "  $sourceFolder -> $targetFolder"
    New-SymbolicLink -SourceFolder $sourceFolder -TargetFolder $targetFolder
}

