[CmdletBinding()]
param()
$Global:DebugPreference = 'Continue'

get-command dotnet.exe -ErrorAction Stop | out-null
function Get-RelativePath {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [Alias('FileInfo')]
        [System.IO.FileSystemInfo]
        $InputObject,

        [Parameter(Mandatory)]
        [string]
        $RelativeTo
    )
    begin {
        $ActualRelativeTo = Resolve-Path $RelativeTo | Select-Object -ExpandProperty ProviderPath
        Write-Debug "Resolving relative paths from '$ActualRelativeTo'."
    }
    process {
        # We can actually ignore directories.
        if ($InputObject -is [System.IO.DirectoryInfo]) {
            return
        }
        else {
            try {
                $InputObject.FullName.Replace($ActualRelativeTo, '', [System.StringComparison]::OrdinalIgnoreCase).Trim('/', '\')
            }
            catch {
                Write-Error $_ -TargetObject @{ InputObject = $InputObject ; RelativeTo = $ActualRelativeTo }
            }
        }
    }
}

Push-Location -Path $PSScriptRoot -StackName 'PSSharp.PowerShell.FSharpCore Build.ps1' -ErrorAction Stop
try {
    dotnet.exe publish .\PSSharp.PowerShell.FSharpCore --configuration Release | Write-Debug
    $FSharpCore = Get-Item -Path '.\PSSHarp.PowerShell.FSharpCore\bin\Release\net6.0\publish\FSharp.Core.dll'
    $Version = $FSharpCore.VersionInfo.FileVersion
    $OutputDirectory = ".\build\PSSharp.FSharp.PowerShell\$Version"
    if (Test-Path $OutputDirectory) {
        Remove-Item -Path $OutputDirectory -Force -Recurse -Confirm:$false -ErrorAction Stop
    }
    $CopyItemParameters = @{
        Path        = '.\PSSharp.PowerShell.FSharpCore\bin\Release\net6.0\publish'
        Exclude     = 'PSSharp.*'
        Destination = ".\build\PSSharp.FSharp.PowerShell\$Version"
        Recurse     = $true
        PassThru    = $true
        OutVariable = 'Files'
    }
    Copy-Item @CopyItemParameters
    $NewModuleManifestParameters = @{
        Path               = ".\build\PSSharp.FSharp.PowerShell\$Version\PSSharp.PowerShell.FSharpCore.psd1"
        Guid               = '151775e8-93de-4145-8466-03b19c47f0dc'
        CompanyName        = 'PSSharp'
        Author             = 'Caleb Frederickson'
        ModuleVersion      = $Version
        Description        = 'Wrapper module for the FSharp.Core assemblies. No additional functionality.'
        RequiredAssemblies = @('FSharp.Core.dll')
        FileList           = $Files | Get-RelativePath -RelativeTo ".\build\PSSharp.FSharp.PowerShell\$Version"
        ProjectUri         = 'https://github.com/Stroniax/PSSharp.PowerShell.FSharpCore'
        LicenseUri         = 'https://opensource.org/licenses/MIT'
    }
    New-ModuleManifest @NewModuleManifestParameters

    Get-Item -Path $NewModuleManifestParameters['Path']
}
finally {
    Pop-Location -StackName 'PSSharp.PowerShell.FSharpCore Build.ps1'
}