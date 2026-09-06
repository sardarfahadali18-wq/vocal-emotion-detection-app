@echo off
echo =======================================
echo Starting Voice Emotion Analysis Server
echo IP: 192.168.228.12  Port: 5000
echo =======================================
echo.

REM Check if virtual environment exists
if not exist venv (
    echo Creating virtual environment...
    python -m venv venv
)

REM Activate virtual environment
echo Activating virtual environment...
call venv\Scripts\activate
echo Virtual environment activated.

REM Force reinstall dependencies to ensure they're properly installed
echo Installing dependencies...
pip install -r requirements.txt
if %ERRORLEVEL% NEQ 0 (
    echo Failed to install dependencies. Trying again with --no-cache-dir...
    pip install --no-cache-dir -r requirements.txt
)
echo Dependencies installed.

REM Create uploads folder if it doesn't exist
if not exist uploads (
    echo Creating uploads folder...
    mkdir uploads
)

REM Show network adapters
echo Available network interfaces:
ipconfig | findstr /C:"IPv4"
echo.
echo Note: The app expects server at 192.168.228.12
echo You may need to update the app settings to use one of your IPs.
echo.

REM Run the server with error handling
echo Starting server...
echo Press Ctrl+C to stop the server
echo.
echo TIP: Use "python list_files.py" in another window to view saved audio files
echo.

REM Run with error handling to prevent server from closing immediately
python app.py

REM If the server exits with an error
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ================================================================
    echo Server exited with error code %ERRORLEVEL%
    echo Check server.log for more details
    echo ================================================================
    echo.
    
    REM Display the last few lines of the log file if it exists
    if exist server.log (
        echo Last few lines from log file:
        echo ----------------------------------
        type server.log | findstr "ERROR" 
        echo ----------------------------------
    )
)

REM Keep the window open if there was an error
echo.
echo Press any key to exit...
pause > nul 