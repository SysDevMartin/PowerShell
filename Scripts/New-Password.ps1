function New-RandomString {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [int]$Length,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [string]$AllowedCharacters,
        
        [ValidateNotNull()]
        [switch]$PreventDuplicateCharacters
    )

    # Prevent the function from getting stuck in an infinite loop if there are
    # not enough allowed characters to be able to prevent duplicate characeters.
    if ($AllowedCharacters.Length -le 1) {
        $PreventDuplicateCharacters = $false
    }

    # Generate characters.
    $characterString = ''
    for ($i = 0; $i -lt $Length; $i++) {
        $characterIndex = Get-Random -Minimum 0 -Maximum $AllowedCharacters.Length
        $character = $AllowedCharacters.Substring($characterIndex, 1)

        # Prevent duplicate side-by-side characters.
        if ($PreventDuplicateCharacters -and ($i -gt 0)) {
            while ($characterString.Substring($i - 1, 1) -ceq $character) {
                $characterIndex = Get-Random -Minimum 0 -Maximum $AllowedCharacters.Length
                $character = $AllowedCharacters.Substring($characterIndex, 1)
            }
        }

        $characterString += $character
    }

    return $characterString
}

function New-Password {
    [CmdletBinding(DefaultParameterSetName = 'SecureString')]
    param(
        [Parameter(Position = 0, ParameterSetName = 'SecureString')]
        [Parameter(Position = 0, ParameterSetName = 'Clipboard')]
        [ValidateSet('User', 'PIN', 'Secure', 'SuperSecure')]
        [string]$Type = 'User',

        [Parameter(Position = 1, ParameterSetName = 'SecureString')]
        [Parameter(Position = 1, ParameterSetName = 'Clipboard')]
        [ValidateRange(1, 10000)]
        [int]$Length,

        [Parameter(ParameterSetName = 'SecureString')]
        [switch]$AsSecureString,

        [Parameter(ParameterSetName = 'Clipboard')]
        [switch]$CopyToClipboard
    )

    $password = ''

    switch ($Type) {
        'User' {
            $tempLength = if ($Length) { $Length } else { 12 }

            $minLength = 5
            if ($tempLength -lt $minLength) {
                $tempLength = $minLength
            }

            $password += New-RandomString -Length 1 -AllowedCharacters 'ABCDEFGHJKLMNPQRSTUVWZYX'
            $password += New-RandomString -Length ($tempLength - $minLength) -AllowedCharacters 'abcdefghjkmnpqrstuvwxyz' -PreventDuplicateCharacters
            $password += New-RandomString -Length 4 -AllowedCharacters '123456789' -PreventDuplicateCharacters
        }

        'PIN' {
            $tempLength = if ($Length) { $Length } else { 4 }
            $password += New-RandomString -Length $tempLength -AllowedCharacters '0123456789'
        }

        'Secure' {
            $tempLength = if ($Length) { $Length } else { 30 }
            $password += New-RandomString -Length $tempLength -AllowedCharacters 'ABCDEFGHIJKLMNOPQRSTUVWZYXabcdefghijklmnopqrstuvwxyz0123456789'
        }

        'SuperSecure' {
            $tempLength = if ($Length) { $Length } else { 60 }
            $password += New-RandomString -Length $tempLength -AllowedCharacters 'ABCDEFGHIJKLMNOPQRSTUVWZYXabcdefghijklmnopqrstuvwxyz0123456789_-+.,:;=@^<>|(){}[]$%?!&#'
        }
    }

    if ($CopyToClipboard) {
        Set-Clipboard -Value $password
    }

    if ($AsSecureString) {
        $password = ConvertTo-SecureString -String $password -AsPlainText
    }

    if (-not $CopyToClipboard) {
        $password
    }
}