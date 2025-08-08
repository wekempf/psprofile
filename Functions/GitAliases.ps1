# See https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/git
# This is a partial list of those aliases. Since PowerShell aliases are not as flexible as bash aliases, we will create
# functions to alias instead. NOTE: The use of these functions means tab completion will not work.

Set-Alias -Name g -Value git
Set-Alias -Name grt -Value Set-LocationGitRoot
Set-Alias -Name ga -Value Invoke-GitAd
Set-Alias -Name gaa -Value Invoke-GitAddAll
Set-Alias -Name gb -Value Invoke-GitBranch
Set-Alias -Name gba -Value Invoke-GitBranchAll
Set-Alias -Name gsw -Value Invoke-GitSwitch
Set-Alias -Name gswc -Value Invoke-GetSwitchNewBranch
Set-Alias -Name gswcf -Value Invoke-GitSwitchNewFeatureBranch
Set-Alias -Name gswm -Value Invoke-GitSwitchMain
Set-Alias -Name gswf -Value Invoke-GitSwitchFeature
Set-Alias -Name gr -Value Invoke-GitRestore
Set-Alias -Name gclean -Value Invoke-GitClean
Set-Alias -Name gc -Value Invoke-GitCommit -Force
Set-Alias -Name gcm -Value Invoke-GitCommitMessage -Force
Set-Alias -Name gca -Value Invoke-GitCommitAll
Set-Alias -Name gcam -Value Invoke-GitCommitAllMessage

function Set-LocationGitRoot {
    Set-Location (git rev-parse --show-toplevel)
}

function Invoke-GitAdd {
    git add $args
}

function Invoke-GitAddAll {
    git add --all $args
}

function Invoke-GitBranch {
    git branch $args
}

function Invoke-GitBranchAll {
    git branch --all $args
}

function Invoke-GitSwitch {
    git switch $args
}

function Invoke-GitSwitchNewBranch {
    git switch -c $args
}

function Invoke-GitSwitchNewFeatureBranch {
    git switch -c feature/$args
}

function Invoke-GitSwitchMain {
    # rely on custom `git default-branch`
    git switch $(git default-branch)
}

function Invoke-GitSwitchFeature {
    git switch feature/$args
}

function Invoke-GitRestore {
    git restore $args
}

function Invoke-GitClean {
    git clean --interactive -d $args
}

function Invoke-GitCommit {
    git commit $args
}

function Invoke-GitCommitMessage {
    git commit -m $args
}

function Invoke-GitCommitAll {
    git commit -a $args
}

function Invoke-GitCommitAllMessage {
    git commit -am $args
}
