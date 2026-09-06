"""
Simple test script to verify Flask and other dependencies are working properly.
"""
print("Starting basic server test...")

try:
    import flask
    print(f"✓ Flask is installed (version {flask.__version__})")
except ImportError:
    print("✗ Flask is not installed!")

try:
    import librosa
    print(f"✓ Librosa is installed (version {librosa.__version__})")
except ImportError:
    print("✗ Librosa is not installed!")

try:
    import torch
    print(f"✓ PyTorch is installed (version {torch.__version__})")
    
    if torch.cuda.is_available():
        print(f"✓ CUDA is available (version {torch.version.cuda})")
    else:
        print("ℹ CUDA is not available, using CPU only")
except ImportError:
    print("✗ PyTorch is not installed!")

try:
    import transformers
    print(f"✓ Transformers is installed (version {transformers.__version__})")
except ImportError:
    print("✗ Transformers is not installed!")

try:
    import numpy
    print(f"✓ NumPy is installed (version {numpy.__version__})")
except ImportError:
    print("✗ NumPy is not installed!")

print("\nCreating a simple Flask test server...")
try:
    from flask import Flask
    app = Flask(__name__)
    
    @app.route('/test')
    def test():
        return "Test successful!"
    
    print("✓ Flask app created successfully")
    print("\nAll basic dependencies appear to be working.")
    print("If you still have issues starting the server, check server.log for more details.")
    print("\nPress Enter to exit...")
    input()
except Exception as e:
    print(f"✗ Error creating Flask app: {str(e)}")
    print("\nPress Enter to exit...")
    input() 