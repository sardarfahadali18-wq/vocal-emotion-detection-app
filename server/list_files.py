#!/usr/bin/env python
"""
Simple script to list audio files in the uploads directory
"""
import os
import sys
import argparse
from datetime import datetime
import wave

def get_audio_duration(file_path):
    """Get the duration of a WAV file in seconds"""
    try:
        with wave.open(file_path, 'rb') as wf:
            frames = wf.getnframes()
            rate = wf.getframerate()
            duration = frames / float(rate)
            return duration
    except:
        return None

def format_timestamp(filename):
    """Extract timestamp from filename if it matches the format YYYYMMDD_HHMMSS_*.wav"""
    try:
        parts = filename.split('_', 2)
        if len(parts) >= 2:
            date_part = parts[0]
            time_part = parts[1]
            if len(date_part) == 8 and len(time_part) == 6:
                dt = datetime.strptime(f"{date_part}_{time_part}", "%Y%m%d_%H%M%S")
                return dt.strftime("%Y-%m-%d %H:%M:%S")
    except:
        pass
    return "Unknown date"

def main():
    parser = argparse.ArgumentParser(description='List audio files in the uploads directory')
    parser.add_argument('--detail', '-d', action='store_true', help='Show detailed information')
    parser.add_argument('--delete', type=int, help='Delete file by index')
    args = parser.parse_args()
    
    # Get the uploads directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    upload_dir = os.path.join(script_dir, "uploads")
    
    if not os.path.exists(upload_dir):
        print(f"Uploads directory {upload_dir} not found.")
        return 1
    
    # List all audio files
    files = [f for f in os.listdir(upload_dir) if f.endswith(('.wav', '.mp3'))]
    
    if args.delete is not None:
        if 1 <= args.delete <= len(files):
            file_to_delete = files[args.delete - 1]
            file_path = os.path.join(upload_dir, file_to_delete)
            try:
                os.remove(file_path)
                print(f"Deleted: {file_to_delete}")
                # Refresh the file list
                files = [f for f in os.listdir(upload_dir) if f.endswith(('.wav', '.mp3'))]
            except Exception as e:
                print(f"Error deleting {file_to_delete}: {e}")
                return 1
        else:
            print(f"Invalid file index. Please specify a number between 1 and {len(files)}")
            return 1
    
    if len(files) == 0:
        print("No audio files found in the uploads directory.")
        return 0
    
    print(f"\nFound {len(files)} audio files in {upload_dir}:")
    print("-" * 80)
    
    for i, file in enumerate(files):
        file_path = os.path.join(upload_dir, file)
        file_size = os.path.getsize(file_path) / 1024  # Size in KB
        
        if args.detail:
            timestamp = format_timestamp(file)
            duration = get_audio_duration(file_path)
            duration_str = f"{duration:.2f} seconds" if duration else "Unknown duration"
            print(f"{i+1}. {file}")
            print(f"   Date: {timestamp}")
            print(f"   Size: {file_size:.2f} KB")
            print(f"   Duration: {duration_str}")
            print("-" * 40)
        else:
            print(f"{i+1}. {file} ({file_size:.2f} KB)")
    
    print("\nUse --detail or -d option for more information")
    print("Use --delete [index] to delete a file")
    return 0

if __name__ == "__main__":
    sys.exit(main()) 