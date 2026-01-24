# Proxy command for Get-ChildItem that adds a -Short switch
# When dot-sourced, this file automatically installs the proxy

& {
    # Store the original Get-ChildItem command
    if (-not (Test-Path Variable:Global:*ShortProxiedGetChildItem)) {
        ${global:*ShortProxiedGetChildItem} = Get-Command Get-ChildItem -CommandType Cmdlet
    }

    # Get the metadata from the original command
    $originalCmd = ${global:*ShortProxiedGetChildItem}
    $metadata = New-Object System.Management.Automation.CommandMetaData ($originalCmd)

    # Add the -Short switch parameter
    $shortParam = New-Object System.Management.Automation.ParameterMetadata 'Short'
    $shortParam.ParameterType = [switch]
    $shortParam.Attributes.Add((New-Object System.Management.Automation.ParameterAttribute))
    $metadata.Parameters.Add('Short', $shortParam)

    # Generate the complete proxy command
    $fullProxy = [System.Management.Automation.ProxyCommand]::Create($metadata)
    
    # Create the code to inject into the begin block
    # Use verbatim here-string to avoid any escaping issues
    $injectedCode = @'
        # Check if -Short was specified and we are not in a pipeline
        if ($script:__ShortWasSpecified) {
            # Short parameter was already removed in dynamicparam block
            
            # Check if output is being piped to another command
            $isPiped = $MyInvocation.PipelineLength -gt 1
            
            # Dynamically build regex pattern from all aliases for Get-ChildItem
            $aliases = @(Get-Alias | Where-Object { $_.Definition -eq 'Get-ChildItem' } | ForEach-Object Name)
            # Also include ls function if it exists
            $allNames = @('Get-ChildItem', 'ls') + $aliases
            $namesPattern = ($allNames | ForEach-Object { [regex]::Escape($_) }) -join '|'
            
            # Check if output is being used with member access like (gci).Name or (gci)[0].Name
            $hasMemberAccess = $MyInvocation.Line -match "\([^)]*\b($namesPattern)\b[^)]*\)(\s*\[[^\]]+\])?\s*\."
            
            if (-not $isPiped -and -not $hasMemberAccess) {
                # Use short display format
                try {
                    & ${global:*ShortProxiedGetChildItem} @PSBoundParameters | ForEach-Object {
                        $item = $_.Name
                        $needsReset = $false
                        if ($_.Attributes -match 'Hidden') {
                            $item = "$($PSStyle.Italic)$item"
                            $needsReset = $true
                        }
                        if ($_.Attributes -match 'Directory') {
                            $item = "$($PSStyle.Foreground.Blue)$item"
                            $needsReset = $true
                        }
                        if ($needsReset) {
                            $item = "$item$($PSStyle.Reset)"
                        }
                        [PSCustomObject]@{
                            Name = $item
                        }
                    } | Format-Wide Name -AutoSize | Out-Host
                } catch {
                    throw
                }
                # Early return - do not set up the pipeline
                return
            }
        }

'@
    # Inject our custom -Short handling into the begin block
    # Need to escape $ in the injected code for -replace, but preserve ${...} variable references
    # The regex \$(?!\{) matches $ not followed by {, which we then escape as $$$$
    $escapedInjectedCode = $injectedCode -replace '\$(?!\{)', '$$$$'
    $fullProxy = $fullProxy -replace '(?s)(begin\s*\{\s*try\s*\{)', "`$1`n$escapedInjectedCode"
    
    # Fix process and end blocks to check if steppablePipeline exists before using it
    $fullProxy = $fullProxy -replace '(\$steppablePipeline\.Process\(\$_\))', 'if ($$steppablePipeline) { $1 }'
    $fullProxy = $fullProxy -replace '(\$steppablePipeline\.End\(\))', 'if ($$steppablePipeline) { $1 }'
    
    # Also need to remove -Short from $PSBoundParameters in the dynamicparam block
    # But first, save whether it was specified so the begin block can check it
    $dynamicparamFix = @'
        if ($PSBoundParameters.ContainsKey('Short')) {
            $script:__ShortWasSpecified = $PSBoundParameters['Short']
            $null = $PSBoundParameters.Remove('Short')
        } else {
            $script:__ShortWasSpecified = $false
        }
'@
    $escapedDynamicparamFix = $dynamicparamFix -replace '\$(?!\{)', '$$$$'
    $fullProxy = $fullProxy -replace '(?s)(dynamicparam\s*\{\s*try\s*\{)', "`$1`n$escapedDynamicparamFix"
    
    # Wrap in function definition
    $functionDef = "function global:Get-ChildItem {`n$fullProxy`n}"

    # Define the function in the global scope
    Invoke-Expression $functionDef
    
    # Create ls proxy function that always uses -Short
    # Generate a full proxy for ls that automatically includes -Short
    $lsProxy = [System.Management.Automation.ProxyCommand]::Create($metadata)
    
    # Modify the ls proxy to always set Short parameter
    $lsShortInjection = '$script:__ShortWasSpecified = $true'
    $escapedLsInjection = $lsShortInjection -replace '\$(?!\{)', '$$$$'
    $lsProxy = $lsProxy -replace '(?s)(dynamicparam\s*\{\s*try\s*\{)', "`$1`n$escapedLsInjection"
    
    # Apply the same fixes to ls proxy
    $lsProxy = $lsProxy -replace '(?s)(begin\s*\{\s*try\s*\{)', "`$1`n$escapedInjectedCode"
    $lsProxy = $lsProxy -replace '(\$steppablePipeline\.Process\(\$_\))', 'if ($$steppablePipeline) { $1 }'
    $lsProxy = $lsProxy -replace '(\$steppablePipeline\.End\(\))', 'if ($$steppablePipeline) { $1 }'
    
    # Remove the -Short parameter from ls since it's always implied
    # Also handle PSBoundParameters in dynamicparam
    $lsDynamicFix = @'
        if ($PSBoundParameters.ContainsKey('Short')) {
            $null = $PSBoundParameters.Remove('Short')
        }
'@
    $escapedLsDynamicFix = $lsDynamicFix -replace '\$(?!\{)', '$$$$'
    $lsProxy = $lsProxy -replace '(?s)(dynamicparam\s*\{\s*try\s*\{.*?)(\n\s*\$script:__ShortWasSpecified = \$true)', "`$1`n$escapedLsDynamicFix`$2"
    
    # Remove -Short parameter from the param block for ls
    $lsProxy = $lsProxy -replace ',?\s*\[switch\]\s*\$\{Short\}', ''
    
    # Define ls function
    $lsFunctionDef = "function global:ls {`n$lsProxy`n}"
    Invoke-Expression $lsFunctionDef
    
    # Create ll as a simple alias to Get-ChildItem
    if (Get-Alias -Name ll -ErrorAction SilentlyContinue) {
        Remove-Item -Path Alias:\ll -Force
    }
    Set-Alias -Name ll -Value Get-ChildItem -Scope Global -Option AllScope
}

# Remove the built-in ls alias if it exists
if (Get-Alias -Name ls -ErrorAction SilentlyContinue | Where-Object { $_.Options -notmatch 'AllScope' }) {
    Remove-Item -Path Alias:\ls -Force -ErrorAction SilentlyContinue
}