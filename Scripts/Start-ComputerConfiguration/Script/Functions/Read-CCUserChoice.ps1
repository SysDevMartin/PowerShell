function Read-CCUserChoice {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$Title,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$Prompt,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Host.ChoiceDescription[]]$Choices,

        [int]$Default = -1
    )

    $choice = $Host.UI.PromptForChoice($Title, $Prompt, $Choices, $Default)
    return $choice
}