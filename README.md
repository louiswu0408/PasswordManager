# Password Manager (PowerShell)

A simple and secure password manager implemented in PowerShell.  
Stores encrypted passwords locally and allows adding, retrieving, listing, and deleting accounts with a master password.

---

## Features

- Store multiple accounts with username and password.
- Encrypt passwords using AES-256 with a unique salt and IV per entry.
- Derive encryption key from your master password using PBKDF2 (Rfc2898DeriveBytes).
- Auto-copy feature: usernames are copied immediately, and passwords are copied automatically when you paste (Ctrl+V), keeping sensitive data secure.
- Avoid duplicate accounts with the same username and password.
- Vault data is saved in a JSON file, sorted by site and username.

---

## Requirements

- PowerShell 5.1 or later (Windows PowerShell or PowerShell Core)
- Windows OS (tested on Windows 10+)

---

## Installation

1. Clone or download this repository:

```powershell
git clone https://github.com/louiswu0408/PasswordManager.git
```

2. Navigate to the directory:

```powershell
cd PasswordManager
```

3. Run the script:

```powershell
./PasswordManager.ps1
```
