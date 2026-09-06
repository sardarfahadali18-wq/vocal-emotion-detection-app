@echo off
echo =======================================
echo Testing Emotion Recognition Server Setup
echo =======================================
echo.

REM Check if virtual environment exists
if not exist venv (
    echo Creating virtual environment...
    python -m venv venv
    if %ERRORLEVEL% NEQ 0 (
        echo Failed to create virtual environment.
        echo Ensure Python is installed and in your PATH.
        goto :error
    )
)

REM Activate virtual environment
echo Activating virtual environment...
call venv\Scripts\activate
if %ERRORLEVEL% NEQ 0 (
    echo Failed to activate virtual environment.
    goto :error
)

REM Install dependencies
echo Installing dependencies...
pip install -r requirements.txt
if %ERRORLEVEL% NEQ 0 (
    echo Failed to install dependencies. Trying with --no-cache-dir...
    pip install --no-cache-dir -r requirements.txt
    if %ERRORLEVEL% NEQ 0 (
        echo Failed to install dependencies.
        echo Check your internet connection and pip configuration.
        goto :error
    )
)

REM Run the test script
echo.
echo Running test script...
python test_server.py

goto :end

:error
echo.
echo =======================================
echo      Setup test failed with errors
echo =======================================
echo.
echo Common solutions:
echo 1. Make sure Python 3.9+ is installed and in your PATH
echo 2. Check your internet connection
echo 3. Try running as Administrator
echo.
echo Press any key to exit...
pause > nul
exit /b 1

:end
echo.
echo If all tests passed, you can now run run_hotspot_server.bat
echo.
echo Press any key to exit...
pause > nul 