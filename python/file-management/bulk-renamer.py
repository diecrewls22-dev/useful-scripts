#!/usr/bin/env python3
"""
Bulk File Renamer
Renames multiple files with various patterns
"""

import os
import re
import argparse
import sys
from datetime import datetime

def safe_rename(old_path, new_path):
    """Safely rename a file with error handling"""
    try:
        os.rename(old_path, new_path)
        return True
    except OSError as e:
        print(f"Error renaming {old_path}: {e}")
        return False

def preview_changes(files, new_names, directory):
    """Preview changes before applying"""
    print("\nPREVIEW CHANGES:")
    print("-" * 80)
    for old_name, new_name in zip(files, new_names):
        old_path = os.path.join(directory, old_name)
        new_path = os.path.join(directory, new_name)
        print(f"'{old_name}' → '{new_name}'")
    print("-" * 80)

def main():
    parser = argparse.ArgumentParser(description='Bulk rename files with various patterns')
    parser.add_argument('directory', nargs='?', default='.', 
                       help='Directory containing files to rename (default: current)')
    parser.add_argument('--pattern', '-p', required=True,
                       help='Naming pattern. Use {n} for counter, {name} for original name, {ext} for extension')
    parser.add_argument('--start', type=int, default=1,
                       help='Starting number for counter (default: 1)')
    parser.add_argument('--padding', type=int, default=0,
                       help='Zero padding for counter (e.g., 3 for 001, 002)')
    parser.add_argument('--filter', '-f', 
                       help='Only process files matching this regex pattern')
    parser.add_argument('--dry-run', action='store_true',
                       help='Preview changes without renaming')
    
    args = parser.parse_args()
    
    if not os.path.isdir(args.directory):
        print(f"Error: {args.directory} is not a valid directory")
        sys.exit(1)
    
    # Get all files in directory
    all_files = [f for f in os.listdir(args.directory) 
                if os.path.isfile(os.path.join(args.directory, f))]
    
    # Apply filter if specified
    if args.filter:
        try:
            pattern = re.compile(args.filter)
            files = [f for f in all_files if pattern.search(f)]
        except re.error as e:
            print(f"Invalid regex pattern: {e}")
            sys.exit(1)
    else:
        files = all_files
    
    if not files:
        print("No files found to rename!")
        return
    
    print(f"Found {len(files)} files to process")
    
    # Generate new names
    new_names = []
    counter = args.start
    
    for filename in files:
        name, ext = os.path.splitext(filename)
        ext = ext.lower()
        
        # Build new name using pattern
        new_name = args.pattern
        
        # Replace placeholders
        if '{n}' in new_name:
            counter_str = str(counter)
            if args.padding > 0:
                counter_str = counter_str.zfill(args.padding)
            new_name = new_name.replace('{n}', counter_str)
            counter += 1
        
        new_name = new_name.replace('{name}', name)
        new_name = new_name.replace('{ext}', ext[1:] if ext else '')  # Remove dot from extension
        
        # Ensure unique filename
        base_new_name = new_name
        suffix = 1
        while new_name + ext in new_names or os.path.exists(os.path.join(args.directory, new_name + ext)):
            new_name = f"{base_new_name}_{suffix}"
            suffix += 1
        
        new_names.append(new_name + ext)
    
    # Preview changes
    preview_changes(files, new_names, args.directory)
    
    if args.dry_run:
        print("\nThis was a dry run. No files were changed.")
        return
    
    # Confirm and apply changes
    response = input("\nApply these changes? (y/N): ").lower()
    if response != 'y':
        print("Operation cancelled.")
        return
    
    # Perform renaming
    success_count = 0
    for old_name, new_name in zip(files, new_names):
        old_path = os.path.join(args.directory, old_name)
        new_path = os.path.join(args.directory, new_name)
        
        if safe_rename(old_path, new_path):
            success_count += 1
            print(f"✓ Renamed: {old_name} → {new_name}")
        else:
            print(f"✗ Failed: {old_name}")
    
    print(f"\nOperation complete! Successfully renamed {success_count}/{len(files)} files")

if __name__ == "__main__":
    main()
