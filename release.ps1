#Requires -Module Microsoft.PowerShell.SecretManagement
#Requires -Module Microsoft.PowerShell.SecretStore
$global:DebugPreference = 'Continue'
$BuildPath = Join-Path $PSScriptRoot build.ps1
$BuildPathExists = Test-Path $BuildPath
if (-not $BuildPathExists) {
    throw "Could not find build script at path '$BuildPath'."
}

$ReleaseModulePath = & $BuildPath -ErrorAction Stop | Where-Object Name -eq 'PSSharp.PowerShell.FSharpCore.psd1'
if (-not $ReleaseModulePath) {
    throw "Could not identify module to release from bulid output."
}
Write-Debug "Build output: $ReleaseModulePath"
$TempDirectory = Join-Path ([System.IO.Path]::GetTempPath()) -ChildPath 'PSSharp.PowerShell.FSharpCore'
try {
    # ModuleName/ModuleVersion/Manifest.psd1
    $ModulePath = Split-Path $ReleaseModulePath -Parent
    # We need to copy our module so that we can publish it without conflicting with another version in the build directory
    if (Test-Path $TempDirectory) {
        Remove-Item -Path $TempDirectory -Force -Recurse -Confirm:$false -ErrorAction Stop
    }
    Copy-Item -Path $ModulePath -Destination $TempDirectory -Recurse

    $PublishModuleParameters = @{
        Path        = $TempDirectory
        NuGetApiKey = Get-Secret -Name PSGalleryApiKey -AsPlainText
        Repository  = 'PSGallery'
        Tags        = 'F#', 'FSharp', 'PSSharp', 'Assembly', 'Dependency'
        ProjectUri  = 'https://www.github.com/Stroniax/PSSharp.PowerShell.FSharpCore'
        LicenseUri  = 'https://opensource.org/licenses/MIT'
    }
    Publish-Module @PublishModuleParameters
}
finally {
    Remove-Item -Path $TempDirectory -Force -Recurse -ErrorAction Ignore -Confirm:$false
}