#!/usr/bin/env python3
"""
Duplicate File Finder
Finds duplicate files by comparing MD5 hashes
"""

import os
import hashlib
import argparse
from collections import defaultdict
import sys

def get_file_hash(filepath, chunk_size=8192):
    """Calculate MD5 hash of a file"""
    hasher = hashlib.md5()
    try:
        with open(filepath, 'rb') as f:
            while chunk := f.read(chunk_size):
                hasher.update(chunk)
        return hasher.hexdigest()
    except (IOError, OSError) as e:
        print(f"Error reading {filepath}: {e}")
        return None

def find_duplicates(directory, min_size=1024):
    """Find duplicate files in directory"""
    file_hashes = defaultdict(list)
    total_files = 0
    duplicate_count = 0
    
    print(f"Scanning directory: {directory}")
    print("This may take a while for large directories...")
    print()
    
    for root, dirs, files in os.walk(directory):
        for filename in files:
            filepath = os.path.join(root, filename)
            
            # Skip if file is too small
            try:
                if os.path.getsize(filepath) < min_size:
                    continue
            except OSError:
                continue
            
            total_files += 1
            if total_files % 100 == 0:
                print(f"Processed {total_files} files...")
            
            file_hash = get_file_hash(filepath)
            if file_hash:
                file_hashes[file_hash].append(filepath)
    
    # Find duplicates
    duplicates = {hash_val: paths for hash_val, paths in file_hashes.items() 
                 if len(paths) > 1}
    
    return duplicates, total_files

def format_size(size_bytes):
    """Convert bytes to human readable format"""
    for unit in ['B', 'KB', 'MB', 'GB']:
        if size_bytes < 1024.0:
            return f"{size_bytes:.2f} {unit}"
        size_bytes /= 1024.0
    return f"{size_bytes:.2f} TB"

def main():
    parser = argparse.ArgumentParser(description='Find duplicate files by content hash')
    parser.add_argument('directory', nargs='?', default='.', 
                       help='Directory to scan (default: current directory)')
    parser.add_argument('--min-size', type=int, default=1024,
                       help='Minimum file size in bytes to check (default: 1024)')
    parser.add_argument('--delete', action='store_true',
                       help='Prompt to delete duplicates (keep first occurrence)')
    
    args = parser.parse_args()
    
    if not os.path.isdir(args.directory):
        print(f"Error: {args.directory} is not a valid directory")
        sys.exit(1)
    
    duplicates, total_files = find_duplicates(args.directory, args.min_size)
    
    print("\n" + "="*60)
    print("DUPLICATE FILE REPORT")
    print("="*60)
    print(f"Scanned directory: {os.path.abspath(args.directory)}")
    print(f"Total files processed: {total_files}")
    print(f"Duplicate groups found: {len(duplicates)}")
    print()
    
    if not duplicates:
        print("No duplicates found! 🎉")
        return
    
    total_space = 0
    for i, (file_hash, filepaths) in enumerate(duplicates.items(), 1):
        print(f"Group {i} (Hash: {file_hash[:16]}...):")
        
        # Get file size of first file in group
        try:
            file_size = os.path.getsize(filepaths[0])
            total_space += file_size * (len(filepaths) - 1)
        except OSError:
            file_size = 0
        
        for j, filepath in enumerate(filepaths):
            status = "KEEP" if j == 0 else "DUPLICATE"
            print(f"  [{status}] {filepath}")
        print(f"  Size: {format_size(file_size)} each")
        print(f"  Waste: {format_size(file_size * (len(filepaths) - 1))}")
        print()
    
    print(f"Total reclaimable space: {format_size(total_space)}")
    
    if args.delete and duplicates:
        print("\n" + "="*60)
        response = input("Do you want to delete duplicates? (y/N): ").lower()
        if response == 'y':
            deleted_count = 0
            for file_hash, filepaths in duplicates.items():
                # Keep first file, delete the rest
                for filepath in filepaths[1:]:
                    try:
                        os.remove(filepath)
                        print(f"Deleted: {filepath}")
                        deleted_count += 1
                    except OSError as e:
                        print(f"Error deleting {filepath}: {e}")
            print(f"\nDeleted {deleted_count} duplicate files")

if __name__ == "__main__":
    main()
