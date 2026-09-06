@echo off
echo Starting Voice Emotion Analysis Server...
echo Log file: server.log

REM Check if virtual environment exists
if not exist venv (
    echo Creating virtual environment...
    python -m venv venv
)

REM Activate virtual environment
call venv\Scripts\activate

REM Install dependencies if needed
if not exist venv\Lib\site-packages\flask (
    echo Installing dependencies...
    pip install -r requirements.txt
)

REM Create uploads folder if it doesn't exist
if not exist uploads (
    echo Creating uploads folder...
    mkdir uploads
)

REM Run the server with error handling
echo.
echo Starting server at http://localhost:5000
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
    
    REM Display the last 10 lines of the log file if it exists
    if exist server.log (
        echo Last few lines from log file:
        echo ----------------------------------
        type server.log | findstr /n . | findstr /r "^[0-9]*[0-9]:" | findstr /r /c:"^[0-9][0-9][0-9][0-9]:" /c:"^[0-9][0-9][0-9]:" /c:"^[0-9][0-9]:" /c:"^[0-9]:" | tail -10
        echo ----------------------------------
    )
)

REM Keep the window open if there was an error
echo.
echo Press any key to exit...
pause > nul 