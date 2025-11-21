# PasswordManager.ps1

$vault = [System.Collections.ArrayList]@()
$vaultFile = "$PSScriptRoot\vault.json"
function Show-Menu {
    Write-Host "Password Manager" -ForegroundColor Cyan
    Write-Host "----------------" -ForegroundColor DarkCyan
    Write-Host "[1] Add Password" -ForegroundColor Yellow
    Write-Host "[2] Retrieve Password" -ForegroundColor Yellow
    Write-Host "[3] List Accounts" -ForegroundColor Yellow
    Write-Host "[4] Delete Password" -ForegroundColor Yellow
    Write-Host "[5] Exit" -ForegroundColor Yellow
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
                MasterHash  = $item.MasterHash
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
    param(
        [string]$plainText,
        [string]$masterKey
    )

    # --- Generate RANDOM salt ---
    $salt = New-Object byte[] 16
    [System.Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($salt)

    # --- Derive key from password + salt ---
    $derive = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($masterKey, $salt, 200000)
    $key = $derive.GetBytes(32)  # 256-bit key

    # --- Create AES and random IV ---
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.GenerateIV()
    $iv = $aes.IV

    $aes.Key = $key
    $aes.IV  = $iv

    # --- Encrypt ---
    $encryptor = $aes.CreateEncryptor()
    $plainBytes = [Text.Encoding]::UTF8.GetBytes($plainText)
    $cipherBytes = $encryptor.TransformFinalBlock($plainBytes, 0, $plainBytes.Length)

    # --- Store salt + iv + ciphertext together ---
    $result = $salt + $iv + $cipherBytes
    return [Convert]::ToBase64String($result)
}



function Decrypt-Data {
    param(
        [string]$encrypted,
        [string]$masterKey
    )

    $allBytes = [Convert]::FromBase64String($encrypted)

    # --- Extract salt + iv ---
    $salt = $allBytes[0..15]
    $iv   = $allBytes[16..31]
    $cipherBytes = $allBytes[32..($allBytes.Length-1)]

    # --- Derive key using the same salt ---
    $derive = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($masterKey, $salt, 200000)
    $key = $derive.GetBytes(32)

    # --- AES setup ---
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $key
    $aes.IV  = $iv

    $decryptor = $aes.CreateDecryptor()
    $plainBytes = $decryptor.TransformFinalBlock($cipherBytes, 0, $cipherBytes.Length)

    return [Text.Encoding]::UTF8.GetString($plainBytes)
}



function Add-Password {
    # Ask for site
    $site = Read-Host "Enter site (e.g: gmail)"
    
    # Ask for username
    $username = Read-Host "Enter username/email"
    
    # Ask for password
    $password = Read-Host "Enter password"
    
    $exists = $vault | Where-Object {
        $_.Site -eq $site -and $_.Username -eq $username -and $_.MasterHash -eq $masterHash
    }

    if ($exists.Count -gt 0) {
        Write-Host "⚠ An account with the same site and username already exists."
        return
    }

    $encryptedPassword = Encrypt-Data -plainText $password -masterKey $master
    # Add new entry
    $vault.Add([PSCustomObject]@{
        Site     = $site
        Username = $username
        Password = $encryptedPassword
        MasterHash  = $masterHash
    }) | Out-Null
    Save-Data -filePath $vaultFile
    Write-Host "Added account for $site"
}

function Get-Password {
    $filteredVault = $vault | Where-Object { $_.MasterHash -eq $masterHash }
    $sites = @($filteredVault | Select-Object -ExpandProperty Site -Unique)
    Write-Host "Available sites:"
    for ($i = 0; $i -lt $sites.Count; $i++) {
        Write-Host "[$i] $($sites[$i])" -ForegroundColor Yellow
    }
    Write-Host "[b] cancel" -ForegroundColor DarkYellow
    # Ask user to choose a site
    do {
        $siteChoice = Read-Host "Enter site number"
        if ($siteChoice -ieq "b") { return }
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
        if ($item.Site -eq $site -and $item.MasterHash -eq $masterHash) {
            $siteMatches += [PSCustomObject]$item
        }
    }


    if ($siteMatches.Count -eq 0) {
        Write-Host "No accounts found for '$site'"
        return
    }

    if ($siteMatches.Count -gt 1) {
        for ($i = 0; $i -lt $siteMatches.Count; $i++) {
            Write-Host "[$i] $($siteMatches[$i].Username)" -ForegroundColor Yellow
        }
        Write-Host "[b] cancel" -ForegroundColor DarkYellow
        do {
            $choice = (Read-Host "Which account?").Trim()
            if ($choice -ieq "b") { return }
            if ($choice -notmatch '^\d+$') { Write-Host "Please enter a number."; continue }
            $idx = [int]$choice
            if ($idx -lt 0 -or $idx -ge $siteMatches.Count) { Write-Host "Out of range"; continue }
            break
        } while ($true)
    }
    else { $idx = 0 }

    $acc = $siteMatches[$idx]
    Write-Host "`nUsername: $($acc.Username) is copied"
    $acc.Username | Set-Clipboard
    $seconds = 5
    for ($i = $seconds; $i -gt 0; $i--) {
        Write-Host -NoNewline "`rClearing clipboard in $i seconds..."
        Start-Sleep -Seconds 1
    }
    $decryptedPassword = Decrypt-Data -encrypted $acc.Password -masterKey $master
    Write-Host "Password: $decryptedPassword is copied"
    $decryptedPassword | Set-Clipboard
}

function Delete-Password {
    # Filter vault by master hash
    $filteredVault = $vault | Where-Object { $_.MasterHash -eq $masterHash }

    # Get unique sites
    $sites = @($filteredVault | Select-Object -ExpandProperty Site -Unique)
    if ($sites.Count -eq 0) {
        Write-Host "No accounts found for your master password."
        return
    }

    # Show available sites
    Write-Host "Available sites:"
    for ($i = 0; $i -lt $sites.Count; $i++) {
        Write-Host "[$i] $($sites[$i])" -ForegroundColor Yellow
    }
    Write-Host "[b] cancel" -ForegroundColor DarkYellow
    # Ask user to choose a site
    do {
        Write-Host "`nSelect a site (or 'b' to cancel): " -NoNewline -ForegroundColor Green
        $siteChoice = Read-Host
        if ($siteChoice -ieq "b") { return } 
        if ($siteChoice -notmatch '^\d+$' -or [int]$siteChoice -ge $sites.Count) {
            Write-Host "Invalid selection, try again."
            continue
        }
        break
    } while ($true)

    $site = $sites[[int]$siteChoice]

    # Get accounts for the selected site
    $accounts = $filteredVault | Where-Object { $_.Site -eq $site }
    if ($accounts.Count -eq 0) {
        Write-Host "No accounts found for $site"
        return
    }
    if ($accounts.Count -gt 1) {
        for ($i = 0; $i -lt $accounts.Count; $i++) {
            Write-Host "[$i] $($accounts[$i].Username)" -ForegroundColor Yellow
        }
        Write-Host "[b] cancel" -ForegroundColor DarkYellow
        do {
            $index = Read-Host "Enter the number of the account to delete"
            if ($index -ieq "b") { return }
            if ($index -notmatch '^\d+$' -or [int]$index -ge $accounts.Count) {
                Write-Host "Invalid selection, try again."
                continue
            }
            break
        } while ($true)
    }
    else {
        $index = 0
    }

    $selected = $accounts[$index]

    # Remove account and save vault
    $vault.Remove($selected) | Out-Null
    Save-Data -filePath $vaultFile
    Write-Host "Deleted account $($selected.Username) at $site"
}


function List-Accounts {

    if ($vault.Count -eq 0) {
        Write-Host "Vault is empty." -ForegroundColor Red
        return
    }

    # Filter vault by master hash
    $filteredVault = $vault | Where-Object { $_.MasterHash -eq $masterHash }
    
    if ($filteredVault.Count -eq 0) {
        Write-Host "No accounts found for your master password." -ForegroundColor Red
        return
    }

    Write-Host "`nSaved accounts:" -ForegroundColor Cyan

    # Group by site, sorted
    $grouped = $filteredVault | Sort-Object Site, Username | Group-Object Site

    foreach ($group in $grouped) {
        Write-Host "`nSite: $($group.Name)" -ForegroundColor Cyan
        $accounts = $group.Group

        # Optional header
        Write-Host ("{0,-5} {1}" -f "Index", "Username") -ForegroundColor DarkCyan

        for ($i = 0; $i -lt $accounts.Count; $i++) {
            Write-Host ("{0,-5} {1}" -f "[$i]", $accounts[$i].Username) -ForegroundColor Yellow
        }
    }
    pause
}


Load-Data -filePath $vaultFile
while ($true) {
    $secureMaster = Read-Host -AsSecureString "Enter your master password (type 'new' to create, "q" to quit)"
    
    # Check if user typed 'sign up'
    if ($secureMaster.Length -eq 0) { continue } # ignore empty input
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureMaster)
    $inputMaster = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    
    if ($inputMaster -ieq "new") {
        # Create new master password
        $secureMaster = Read-Host -AsSecureString "Create a new master password"
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureMaster)
        $master = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        $masterHash = [Convert]::ToBase64String((New-Object Security.Cryptography.SHA256Managed).ComputeHash([Text.Encoding]::UTF8.GetBytes($master)))
        Write-Host "Master password set. You can now use the password manager."
        break
    }

    if ($inputMaster -ieq "q") {
        exit 0
    }
    # If vault exists, validate password
    if ($vault.Count -gt 0) {
        $inputHash = [Convert]::ToBase64String((New-Object Security.Cryptography.SHA256Managed).ComputeHash([Text.Encoding]::UTF8.GetBytes($inputMaster)))
        # Check against any stored master hashes
        if ($vault | Where-Object { $_.MasterHash -eq $inputHash }) {
            $master = $inputMaster
            $masterHash = $inputHash
            Write-Host "Sign-in successful."
            break
        } else {
            Write-Host "Incorrect master password."
        }
    } else {
        Write-Host "No vault found. Type 'new' to create a master password."
    }
}
# Main Loop
while ($true) {
    Clear-Host
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
}
