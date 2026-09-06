#!/usr/bin/env python
"""
Simple script to test the connection to the server
"""
import sys
import argparse
import requests
import time
import json

def test_server_connection(server_url):
    """Test the connection to the server and check if it's working correctly"""
    base_url = server_url.rstrip('/')
    health_url = f"{base_url}/health"
    
    print(f"Testing connection to server at {server_url}")
    print("=" * 60)
    
    try:
        # Try to connect to the health endpoint
        print(f"Sending request to {health_url}")
        start_time = time.time()
        response = requests.get(health_url, timeout=5)
        elapsed = time.time() - start_time
        
        print(f"Response received in {elapsed:.2f} seconds")
        print(f"Status code: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"Response data: {json.dumps(data, indent=2)}")
            
            if data.get('status') == 'healthy' and data.get('model_loaded'):
                print("\n✅ Server is HEALTHY and model is loaded!")
                return True
            else:
                print("\n⚠️ Server responded but may not be fully functional.")
                return False
        else:
            print("\n❌ Server responded with an error status code.")
            return False
    
    except requests.exceptions.ConnectionError:
        print("\n❌ CONNECTION ERROR: Could not connect to the server.")
        print(f"Make sure the server is running and the URL ({server_url}) is correct.")
        return False
    
    except requests.exceptions.Timeout:
        print("\n❌ TIMEOUT: Server took too long to respond.")
        return False
    
    except Exception as e:
        print(f"\n❌ ERROR: {str(e)}")
        return False

def main():
    parser = argparse.ArgumentParser(description='Test connection to the voice emotion server')
    parser.add_argument('--url', '-u', type=str, help='Server URL (e.g., http://192.168.1.100:5000)')
    args = parser.parse_args()
    
    # If no URL provided, ask for it
    server_url = args.url
    if not server_url:
        server_url = input("Enter the server URL (e.g., http://192.168.1.100:5000): ")
    
    # Make sure URL has http:// prefix
    if not server_url.startswith('http'):
        server_url = f"http://{server_url}"
    
    success = test_server_connection(server_url)
    
    if success:
        print("\nSUCCESS! The server is running and ready to process emotion detection requests.")
        print(f"\nUse this URL in your Flutter app: {server_url}")
    else:
        print("\nFAILED! The server connection test was not successful.")
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main()) 