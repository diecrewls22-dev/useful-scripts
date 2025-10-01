#!/usr/bin/env python3
"""
Simple Web Scraper
Extracts data from websites using CSS selectors
"""

import requests
from bs4 import BeautifulSoup
import argparse
import json
import csv
import sys
from urllib.parse import urljoin, urlparse

def scrape_url(url, selectors, timeout=10):
    """Scrape data from a URL using CSS selectors"""
    try:
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
        
        response = requests.get(url, timeout=timeout, headers=headers)
        response.raise_for_status()
        
        soup = BeautifulSoup(response.content, 'html.parser')
        results = {}
        
        for selector_name, selector in selectors.items():
            elements = soup.select(selector)
            
            if selector_name.startswith('links_'):
                # Extract links
                base_url = f"{urlparse(url).scheme}://{urlparse(url).netloc}"
                results[selector_name] = [urljoin(base_url, el.get('href')) 
                                        for el in elements if el.get('href')]
            elif selector_name.startswith('images_'):
                # Extract image URLs
                results[selector_name] = [urljoin(url, el.get('src')) 
                                        for el in elements if el.get('src')]
            else:
                # Extract text content
                results[selector_name] = [el.get_text(strip=True) for el in elements]
        
        return {
            'url': url,
            'success': True,
            'data': results,
            'error': None
        }
    
    except requests.exceptions.RequestException as e:
        return {
            'url': url,
            'success': False,
            'data': None,
            'error': str(e)
        }

def main():
    parser = argparse.ArgumentParser(description='Simple web scraper using CSS selectors')
    parser.add_argument('url', help='URL to scrape')
    parser.add_argument('--selectors', '-s', required=True,
                       help='CSS selectors as JSON string or @filename.json')
    parser.add_argument('--output', '-o', 
                       help='Output file (JSON or CSV)')
    parser.add_argument('--timeout', type=int, default=10,
                       help='Request timeout in seconds (default: 10)')
    
    args = parser.parse_args()
    
    # Load selectors
    if args.selectors.startswith('@'):
        # Load from file
        try:
            with open(args.selectors[1:], 'r') as f:
                selectors = json.load(f)
        except FileNotFoundError:
            print(f"Error: Selector file {args.selectors[1:]} not found")
            sys.exit(1)
        except json.JSONDecodeError as e:
            print(f"Error: Invalid JSON in selector file: {e}")
            sys.exit(1)
    else:
        # Parse JSON string
        try:
            selectors = json.loads(args.selectors)
        except json.JSONDecodeError as e:
            print(f"Error: Invalid JSON in selectors: {e}")
            sys.exit(1)
    
    print(f"Scraping: {args.url}")
    print("Selectors:", json.dumps(selectors, indent=2))
    print("=" * 60)
    
    result = scrape_url(args.url, selectors, args.timeout)
    
    if not result['success']:
        print(f"Error: {result['error']}")
        sys.exit(1)
    
    # Display results
    for selector_name, data in result['data'].items():
        print(f"\n{selector_name}:")
        if data:
            for i, item in enumerate(data[:10], 1):  # Show first 10 items
                print(f"  {i}. {item}")
            if len(data) > 10:
                print(f"  ... and {len(data) - 10} more")
        else:
            print("  No results found")
    
    # Save results
    if args.output:
        if args.output.endswith('.json'):
            with open(args.output, 'w', encoding='utf-8') as f:
                json.dump(result, f, indent=2, ensure_ascii=False)
            print(f"\nResults saved to: {args.output}")
        
        elif args.output.endswith('.csv'):
            with open(args.output, 'w', newline='', encoding='utf-8') as f:
                writer = csv.writer(f)
                writer.writerow(['Selector', 'Item#', 'Content'])
                
                for selector_name, data in result['data'].items():
                    for i, item in enumerate(data, 1):
                        writer.writerow([selector_name, i, item])
            
            print(f"\nResults saved to: {args.output}")
        
        else:
            print(f"\nUnsupported output format: {args.output}")

if __name__ == "__main__":
    main()
