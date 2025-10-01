#!/usr/bin/env python3
"""
PDF Merger
Merges multiple PDF files into a single PDF
"""

import argparse
import os
import sys
from PyPDF2 import PdfMerger, PdfReader

def merge_pdfs(input_files, output_file, bookmark=True):
    """Merge multiple PDF files into one"""
    merger = PdfMerger()
    
    try:
        for input_file in input_files:
            # Validate PDF file
            try:
                with open(input_file, 'rb') as f:
                    reader = PdfReader(f)
                    if len(reader.pages) == 0:
                        print(f"Warning: {input_file} appears to be empty")
            except Exception as e:
                print(f"Error reading {input_file}: {e}")
                continue
            
            # Add to merger
            if bookmark:
                # Use filename as bookmark
                bookmark_name = os.path.splitext(os.path.basename(input_file))[0]
                merger.append(input_file, bookmark=bookmark_name)
            else:
                merger.append(input_file)
            
            print(f"Added: {input_file} ({len(reader.pages)} pages)")
        
        # Write output
        with open(output_file, 'wb') as output:
            merger.write(output)
        
        merger.close()
        return True
        
    except Exception as e:
        print(f"Error merging PDFs: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description='Merge multiple PDF files into one')
    parser.add_argument('input_files', nargs='+', 
                       help='Input PDF files to merge')
    parser.add_argument('--output', '-o', required=True,
                       help='Output PDF filename')
    parser.add_argument('--no-bookmarks', action='store_true',
                       help='Do not add bookmarks for each file')
    parser.add_argument('--sort', action='store_true',
                       help='Sort input files alphabetically')
    
    args = parser.parse_args()
    
    # Validate input files
    valid_files = []
    for input_file in args.input_files:
        if not os.path.isfile(input_file):
            print(f"Warning: {input_file} not found, skipping")
            continue
        if not input_file.lower().endswith('.pdf'):
            print(f"Warning: {input_file} is not a PDF file, skipping")
            continue
        valid_files.append(input_file)
    
    if not valid_files:
        print("No valid PDF files to merge!")
        sys.exit(1)
    
    # Sort if requested
    if args.sort:
        valid_files.sort()
    
    print(f"Merging {len(valid_files)} PDF files:")
    for f in valid_files:
        print(f"  - {f}")
    
    # Check if output file exists
    if os.path.exists(args.output):
        response = input(f"\nOutput file {args.output} exists. Overwrite? (y/N): ")
        if response.lower() != 'y':
            print("Operation cancelled.")
            return
    
    # Perform merge
    success = merge_pdfs(valid_files, args.output, not args.no_bookmarks)
    
    if success:
        # Verify output
        try:
            with open(args.output, 'rb') as f:
                reader = PdfReader(f)
                total_pages = len(reader.pages)
            
            print(f"\n✅ Successfully merged {len(valid_files)} files into {args.output}")
            print(f"📄 Total pages in output: {total_pages}")
            
        except Exception as e:
            print(f"\n⚠️  Merge completed but could not verify output: {e}")
    else:
        print("\n❌ Failed to merge PDFs")
        sys.exit(1)

if __name__ == "__main__":
    main()
