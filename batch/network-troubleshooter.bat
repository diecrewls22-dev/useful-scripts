@echo off
setlocal enabledelayedexpansion

echo ================================
echo   NETWORK TROUBLESHOOTER
echo ================================
echo.

set "logfile=network_diagnostics_%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%.txt"
set "logfile=!logfile: =0!"

echo Network Diagnostics Log > "!logfile!"
echo Generated on: %date% %time% >> "!logfile!"
echo ================================ >> "!logfile!"
echo. >> "!logfile!"

echo [1/7] Checking IP Configuration...
echo. >> "!logfile!"
echo 1. IP CONFIGURATION >> "!logfile!"
echo ================================ >> "!logfile!"
ipconfig /all >> "!logfile!" 2>&1
echo ✓ IP configuration logged

echo [2/7] Testing Network Adapters...
echo. >> "!logfile!"
echo 2. NETWORK ADAPTERS >> "!logfile!"
echo ================================ >> "!logfile!"
wmic nic get name, index, netenabled, speed >> "!logfile!" 2>&1
echo ✓ Network adapters checked

echo [3/7] Testing Local Connectivity...
echo. >> "!logfile!"
echo 3. LOCAL CONNECTIVITY >> "!logfile!"
echo ================================ >> "!logfile!"
ping 127.0.0.1 -n 4 >> "!logfile!" 2>&1
echo ✓ Local connectivity tested

echo [4/7] Testing Gateway Connectivity...
echo. >> "!logfile!"
echo 4. GATEWAY CONNECTIVITY >> "!logfile!"
echo ================================ >> "!logfile!"
for /f "tokens=2 delims=:" %%i in ('ipconfig ^| findstr "Default Gateway"') do (
    set "gateway=%%i"
    set "gateway=!gateway: =!"
    if not "!gateway!"=="" (
        echo Testing gateway: !gateway! >> "!logfile!"
        ping !gateway! -n 4 >> "!logfile!" 2>&1
    )
)
echo ✓ Gateway connectivity tested

echo [5/7] Testing DNS Resolution...
echo. >> "!logfile!"
echo 5. DNS RESOLUTION >> "!logfile!"
echo ================================ >> "!logfile!"
nslookup google.com >> "!logfile!" 2>&1
echo ✓ DNS resolution tested

echo [6/7] Checking Network Routes...
echo. >> "!logfile!"
echo 6. NETWORK ROUTES >> "!logfile!"
echo ================================ >> "!logfile!"
route print >> "!logfile!" 2>&1
echo ✓ Network routes checked

echo [7/7] Testing Internet Connectivity...
echo. >> "!logfile!"
echo 7. INTERNET CONNECTIVITY >> "!logfile!"
echo ================================ >> "!logfile!"
ping 8.8.8.8 -n 4 >> "!logfile!" 2>&1
ping google.com -n 4 >> "!logfile!" 2>&1
echo ✓ Internet connectivity tested

echo.
echo ================================
echo Diagnostics complete!
echo Report saved to: !logfile!
echo ================================
echo.

rem Show summary
echo QUICK SUMMARY:
echo --------------
ipconfig | findstr "IPv4"
ping -n 1 8.8.8.8 | findstr "Reply"
ping -n 1 google.com | findstr "Reply"

echo.
pause
