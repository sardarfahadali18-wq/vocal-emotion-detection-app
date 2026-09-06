@echo off
echo =======================================
echo Installing dependencies for Emotion Recognition Server
echo =======================================
echo.

REM Check if virtual environment exists
if not exist venv (
    echo Creating virtual environment...
    python -m venv venv
    if %ERRORLEVEL% NEQ 0 (
        echo Failed to create virtual environment.
        echo Ensure Python is installed and in your PATH.
        exit /b 1
    )
)

REM Activate virtual environment
echo Activating virtual environment...
call venv\Scripts\activate
if %ERRORLEVEL% NEQ 0 (
    echo Failed to activate virtual environment.
    exit /b 1
)

REM Upgrade pip first
echo Upgrading pip...
python -m pip install --upgrade pip

REM Try to install exact versions first
echo Attempting to install exact package versions...
pip install -r requirements.txt

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Failed to install exact versions.
    echo.
    echo Trying with flexible version requirements...
    
    REM Try flexible versions
    pip install -r requirements_flexible.txt
    
    if %ERRORLEVEL% NEQ 0 (
        echo.
        echo Failed to install even with flexible versions.
        echo.
        echo Trying individual package installations...
        
        REM Try individual packages
        echo Installing Flask...
        pip install flask
        
        echo Installing NumPy...
        pip install numpy
        
        echo Installing PyTorch...
        pip install torch
        
        echo Installing Transformers...
        pip install transformers
        
        echo Installing Librosa...
        pip install librosa
    )
)

REM Final check
python -c "import flask, numpy, torch, transformers, librosa; print('All dependencies installed successfully!')" 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo One or more packages could not be imported. Installation may have failed.
) else (
    echo.
    echo Dependencies installed successfully!
)

echo.
echo Press any key to exit...
pause > nul 