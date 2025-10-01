#!/usr/bin/env python3
"""
URL Status Checker
Checks HTTP status codes of multiple URLs
"""

import requests
import argparse
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from urllib.parse import urlparse

def check_url(url, timeout=10):
    """Check a single URL and return its status"""
    try:
        # Add scheme if missing
        if not urlparse(url).scheme:
            url = 'http://' + url
        
        response = requests.get(url, timeout=timeout, allow_redirects=True)
        
        return {
            'url': url,
            'status_code': response.status_code,
            'reason': response.reason,
            'response_time': response.elapsed.total_seconds(),
            'error': None
        }
    
    except requests.exceptions.RequestException as e:
        return {
            'url': url,
            'status_code': None,
            'reason': None,
            'response_time': None,
            'error': str(e)
        }

def print_status(result):
    """Print formatted status result"""
    if result['error']:
        print(f"🔴 {result['url']} - ERROR: {result['error']}")
    else:
        status = result['status_code']
        response_time = result['response_time']
        
        if 200 <= status < 300:
            symbol = "🟢"
        elif 300 <= status < 400:
            symbol = "🔵"
        elif 400 <= status < 500:
            symbol = "🟡"
        else:
            symbol = "🔴"
        
        print(f"{symbol} {result['url']} - {status} {result['reason']} "
              f"({response_time:.2f}s)")

def main():
    parser = argparse.ArgumentParser(description='Check HTTP status of multiple URLs')
    parser.add_argument('urls', nargs='*', help='URLs to check')
    parser.add_argument('--file', '-f', help='File containing URLs (one per line)')
    parser.add_argument('--timeout', type=int, default=10, 
                       help='Request timeout in seconds (default: 10)')
    parser.add_argument('--threads', type=int, default=5,
                       help='Number of concurrent threads (default: 5)')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Show detailed output')
    
    args = parser.parse_args()
    
    # Collect URLs
    urls = set(args.urls)
    
    if args.file:
        try:
            with open(args.file, 'r') as f:
                urls.update(line.strip() for line in f if line.strip())
        except FileNotFoundError:
            print(f"Error: File {args.file} not found")
            sys.exit(1)
    
    if not urls:
        print("No URLs provided. Use --help for usage information.")
        sys.exit(1)
    
    print(f"Checking {len(urls)} URLs...")
    print("=" * 80)
    
    start_time = time.time()
    results = []
    
    # Check URLs concurrently
    with ThreadPoolExecutor(max_workers=args.threads) as executor:
        future_to_url = {executor.submit(check_url, url, args.timeout): url 
                        for url in urls}
        
        for future in as_completed(future_to_url):
            result = future.result()
            results.append(result)
            print_status(result)
    
    # Summary
    total_time = time.time() - start_time
    successful = [r for r in results if not r['error'] and 200 <= r['status_code'] < 400]
    redirects = [r for r in results if not r['error'] and 300 <= r['status_code'] < 400]
    client_errors = [r for r in results if not r['error'] and 400 <= r['status_code'] < 500]
    server_errors = [r for r in results if not r['error'] and r['status_code'] >= 500]
    errors = [r for r in results if r['error']]
    
    print("\n" + "=" * 80)
    print("SUMMARY:")
    print(f"Total URLs checked: {len(urls)}")
    print(f"Successful (2xx): {len(successful)}")
    print(f"Redirects (3xx): {len(redirects)}")
    print(f"Client Errors (4xx): {len(client_errors)}")
    print(f"Server Errors (5xx): {len(server_errors)}")
    print(f"Connection Errors: {len(errors)}")
    print(f"Total time: {total_time:.2f} seconds")
    
    # Save results to file
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_file = f"url_check_results_{timestamp}.txt"
    
    with open(output_file, 'w') as f:
        f.write("URL Status Check Results\n")
        f.write(f"Generated: {datetime.now()}\n")
        f.write("=" * 50 + "\n\n")
        
        for result in results:
            if result['error']:
                f.write(f"ERROR: {result['url']} - {result['error']}\n")
            else:
                f.write(f"{result['status_code']}: {result['url']} "
                       f"({result['response_time']:.2f}s)\n")
    
    print(f"\nDetailed results saved to: {output_file}")

if __name__ == "__main__":
    main()
