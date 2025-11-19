# PasswordManager.ps1

$vault = [System.Collections.ArrayList]@()
$vaultFile = "$PSScriptRoot\vault.json"
Write-Host $PSScriptRoot
function Show-Menu {
    Write-Host "Password Manager"
    Write-Host "----------------"
    Write-Host "1. Add Password"
    Write-Host "2. Retrieve Password"
    Write-Host "3. List Accounts"
    Write-Host "4. Delete Password"
    Write-Host "5. Exit"
}

function Load-Data {
    param($filePath)

    # Check if the vault file exists
    if (Test-Path $filePath) {
        # Read the JSON file
        $json = Get-Content -Path $filePath -Raw
        $data = $json | ConvertFrom-Json

        # Clear the in-memory vault
        $vault.Clear()

        # Add each entry to the ArrayList
        foreach ($item in $data) {
            $vault.Add([PSCustomObject]@{
                Site     = $item.Site
                Username = $item.Username
                Password = $item.Password
            }) | Out-Null
        }

        Write-Host "Vault loaded from $filePath"
    } else {
        Write-Host "No vault file found, starting fresh."
    }
}

function Save-Data {
    param($filePath)

    # Sort vault: first by Site, then by Username
    $sortedVault = $vault | Sort-Object Site, Username

    # Convert to JSON and save
    $json = $sortedVault | ConvertTo-Json -Depth 3
    Set-Content -Path $filePath -Value $json
    Write-Host "Vault saved to $filePath (sorted by Site and Username)"
}

function Encrypt-Data {
    param($plainText, $masterKey)
    # todo
}

function Decrypt-Data {
    param($encrypted, $masterKey)
    # todo
}

function Add-Password {
    # Ask for site
    $site = Read-Host "Enter site (e.g: gmail)"
    
    # Ask for username
    $username = Read-Host "Enter username/email"
    
    # Ask for password
    $password = Read-Host "Enter password"
    
    # Add new entry
    $vault.Add([PSCustomObject]@{
        Site     = $site
        Username = $username
        Password = $password
    }) | Out-Null
    Save-Data -filePath $vaultFile
    Write-Host "Added account for $site"
}

function Get-Password {
    $sites = $vault | Select-Object -ExpandProperty Site -Unique
    Write-Host "Available sites:"
    for ($i = 0; $i -lt $sites.Count; $i++) {
        Write-Host "[$i] $($sites[$i])"
    }

    # Ask user to choose a site
    do {
        $siteChoice = Read-Host "Enter site number"
        if ($siteChoice -notmatch '^\d+$' -or [int]$siteChoice -ge $sites.Count) {
            Write-Host "Invalid selection, try again."
            continue
        }
        break
    } while ($true)

    $site = $sites[[int]$siteChoice]

    # Find matching accounts
    $siteMatches = @()
    foreach ($item in $vault) {
        if ($item.Site -eq $site) {
            $siteMatches += [PSCustomObject]$item
        }
    }

    if ($siteMatches.Count -eq 0) {
        Write-Host "No accounts found for '$site'"
        return
    }

    if ($siteMatches.Count -eq 1) {
        $acc = $siteMatches[0]
        Write-Host "`nUsername: $($acc.Username) is copied"
        $acc.Username | Set-Clipboard
        Start-Sleep -Seconds 5
        Write-Host "Password: $($acc.Password) is copied"
        $acc.Password | Set-Clipboard
        return
    }

    for ($i = 0; $i -lt $siteMatches.Count; $i++) {
        Write-Host "[$i] $($siteMatches[$i].Username)"
    }

    do {
        $choice = (Read-Host "Which account?").Trim()
        if ($choice -notmatch '^\d+$') { Write-Host "Please enter a number."; continue }
        $idx = [int]$choice
        if ($idx -lt 0 -or $idx -ge $siteMatches.Count) { Write-Host "Out of range"; continue }
        break
    } while ($true)

    $acc = $siteMatches[$idx]
    Write-Host "`nUsername: $($acc.Username) is copied"
    $acc.Username | Set-Clipboard
    Start-Sleep -Seconds 5
    Write-Host "Password: $($acc.Password) is copied"
    $acc.Password | Set-Clipboard
}

function Delete-Password {
    $site = Read-Host "Enter site to delete"
    $accounts = $vault | Where-Object { $_.Site -eq $site }
    if ($accounts.Count -eq 0) {
        Write-Host "No account found for $site"
        return
    }

    for ($i=0; $i -lt $accounts.Count; $i++) {
        Write-Host "[$i] $($accounts[$i].Username)"
    }

    $index = Read-Host "Enter the number of the account to delete"
    $selected = $accounts[$index]

    $vault.Remove($selected) | Out-Null
    Save-Data -filePath $vaultFile
    Write-Host "Deleted account $($selected.Username) at $site"

}

function List-Accounts {
    if ($vault.Count -eq 0) {
        Write-Host "Vault is empty."
        return
    }
    Write-Host "`nSaved accounts:"
    $grouped = $vault | Group-Object Site

    foreach ($group in $grouped) {
        Write-Host "`nSite: $($group.Name)"
        $accounts = $group.Group
        for ($i = 0; $i -lt $accounts.Count; $i++) {
            Write-Host "[$i] $($accounts[$i].Username)"
        }
    }
}

Load-Data -filePath $vaultFile
# Main Loop
while ($true) {
    Show-Menu
    $choice = Read-Host "Choose an option"

    switch ($choice) {
        1 { Add-Password }
        2 { Get-Password }
        3 { List-Accounts }
        4 { Delete-Password }
        5 { return }
        default { Write-Host "Invalid choice, try again." }
    }
    pause
    Write-Host "`n"
}
