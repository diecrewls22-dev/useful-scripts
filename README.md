# Useful Scripts Collection 🛠️

A collection of practical scripts for automation, file management, and system utilities across multiple programming languages.

## 📁 Script Categories

### 🦠 Batch Scripts (.bat)
- **`file-organizer.bat`** - Organizes files in a directory by extension
- **`system-cleanup.bat`** - Cleans temporary files and cache
- **`network-troubleshooter.bat`** - Basic network diagnostics

### 🐍 Python Scripts (.py)
#### File Management
- **`duplicate-finder.py`** - Finds duplicate files by content hash
- **`bulk-renamer.py`** - Batch renames files with patterns

#### Web Utilities
- **`url-status-checker.py`** - Checks HTTP status of multiple URLs
- **`simple-web-scraper.py`** - Extracts data from websites

#### Utilities
- **`password-generator.py`** - Generates secure passwords
- **`pdf-merger.py`** - Merges multiple PDF files

### 📜 JavaScript/Node.js (.js)
- **`image-converter.js`** - Converts images between formats
- **`json-formatter.js`** - Validates and formats JSON files
- **`data-downloader.js`** - Downloads files from URLs

### 💻 PowerShell (.ps1)
- **`service-monitor.ps1`** - Monitors Windows services
- **`user-management.ps1`** - Manages local user accounts

### 🐚 Bash Scripts (.sh)
- **`system-info.sh`** - Displays system information
- **`backup-script.sh`** - Creates compressed backups

## 🚀 Quick Start

### Python Scripts
```bash
pip install -r requirements.txt
python python/file-management/duplicate-finder.py
```
### Node.js scripts
```bash
npm install
node javascript/image-converter.js
```
### Batch scripts
```bash
batch\file-organizer.bat
```

### 🛠️ Requirements

Python: 3.6+
Node.js: 14+
Windows: For batch and PowerShell scripts
Linux/Mac: For bash scripts

### 🤝 Contributing

Found a bug? Have a great script idea? Feel free to:

Fork the repo
Create a feature branch
Submit a pull request
See CONTRIBUTING.md for details.

### ⚠️ Disclaimer

Use these scripts at your own risk. Always test in a safe environment before running on important systems.

### ⭐ Star this repo if you find it helpful!


## 4. Let's Create Some Starter Scripts

### **Python: Password Generator** (`python/utilities/password-generator.py`)
```python
import random
import string
import argparse

def generate_password(length=12, use_special_chars=True):
    characters = string.ascii_letters + string.digits
    if use_special_chars:
        characters += string.punctuation
    
    password = ''.join(random.choice(characters) for _ in range(length))
    return password

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Generate secure passwords')
    parser.add_argument('-l', '--length', type=int, default=12, help='Password length')
    parser.add_argument('--no-special', action='store_true', help='Exclude special characters')
    parser.add_argument('-n', '--count', type=int, default=1, help='Number of passwords to generate')
    
    args = parser.parse_args()
    
    print(f"Generated {args.count} password(s):")
    for i in range(args.count):
        password = generate_password(args.length, not args.no_special)
        print(f"{i+1}. {password}")
```
### Batch: File Organizer (batch/file-organizer.bat)
```batch
@echo off
setlocal enabledelayedexpansion

echo File Organizer Script
echo.

if "%~1"=="" (
    set "target_dir=%cd%"
) else (
    set "target_dir=%~1"
)

echo Organizing files in: %target_dir%
echo.

set /a moved=0

for %%f in ("%target_dir%\*.*") do (
    if not "%%~xf"=="" (
        if not "%%~xf"==".bat" (
            set "ext=%%~xf"
            set "ext=!ext:~1!"
            
            if not exist "%target_dir%\!ext!" (
                mkdir "%target_dir%\!ext!"
            )
            
            move "%%f" "%target_dir%\!ext!\"
            set /a moved+=1
            echo Moved: %%~nxf
        )
    )
)

echo.
echo Organization complete! Moved !moved! files.
pause
```
### JavaScript: JSON Formatter (javascript/json-formatter.js)
```javascript
const fs = require('fs');
const path = require('path');

function formatJSON(filePath) {
    try {
        const data = fs.readFileSync(filePath, 'utf8');
        const jsonObj = JSON.parse(data);
        const formattedJSON = JSON.stringify(jsonObj, null, 2);
        
        const dir = path.dirname(filePath);
        const ext = path.extname(filePath);
        const name = path.basename(filePath, ext);
        const outputPath = path.join(dir, `${name}_formatted${ext}`);
        
        fs.writeFileSync(outputPath, formattedJSON);
        console.log(`Formatted JSON saved to: ${outputPath}`);
    } catch (error) {
        console.error('Error:', error.message);
    }
}

// Usage
if (process.argv.length < 3) {
    console.log('Usage: node json-formatter.js <file.json>');
    process.exit(1);
}

const filePath = process.argv[2];
formatJSON(filePath);
```
