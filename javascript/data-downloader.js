#!/usr/bin/env node
/**
 * Data Downloader
 * Downloads files from URLs with progress tracking
 */

const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');
const { URL } = require('url');
const { promisify } = require('util');

const mkdir = promisify(fs.mkdir);
const writeFile = promisify(fs.writeFile);

class DataDownloader {
    constructor(options = {}) {
        this.concurrency = options.concurrency || 3;
        this.timeout = options.timeout || 30000;
        this.retries = options.retries || 3;
        this.downloadedFiles = [];
        this.failedDownloads = [];
    }

    /**
     * Download a single file
     */
    async downloadFile(url, outputPath, onProgress = null) {
        return new Promise(async (resolve, reject) => {
            const parsedUrl = new URL(url);
            const protocol = parsedUrl.protocol === 'https:' ? https : http;
            
            let retries = this.retries;
            
            const attemptDownload = (attempt = 1) => {
                const request = protocol.get(url, (response) => {
                    if (response.statusCode === 301 || response.statusCode === 302) {
                        // Handle redirect
                        const redirectUrl = new URL(response.headers.location, url).href;
                        console.log(`Redirecting to: ${redirectUrl}`);
                        attemptDownload(attempt);
                        return;
                    }

                    if (response.statusCode !== 200) {
                        reject(new Error(`HTTP ${response.statusCode}`));
                        return;
                    }

                    const totalSize = parseInt(response.headers['content-length'], 10);
                    let downloadedSize = 0;

                    // Ensure output directory exists
                    const outputDir = path.dirname(outputPath);
                    if (!fs.existsSync(outputDir)) {
                        fs.mkdirSync(outputDir, { recursive: true });
                    }

                    const fileStream = fs.createWriteStream(outputPath);
                    let lastProgress = 0;

                    response.on('data', (chunk) => {
                        downloadedSize += chunk.length;
                        
                        if (onProgress && totalSize) {
                            const progress = (downloadedSize / totalSize) * 100;
                            // Throttle progress updates
                            if (progress - lastProgress >= 5 || progress === 100) {
                                onProgress({
                                    url,
                                    downloadedSize,
                                    totalSize,
                                    progress: Math.round(progress)
                                });
                                lastProgress = progress;
                            }
                        }
                    });

                    fileStream.on('finish', () => {
                        fileStream.close();
                        resolve({
                            url,
                            path: outputPath,
                            size: downloadedSize,
                            success: true
                        });
                    });

                    fileStream.on('error', (error) => {
                        fs.unlink(outputPath, () => {}); // Delete partial file
                        reject(error);
                    });

                    response.pipe(fileStream);
                });

                request.on('error', (error) => {
                    if (attempt < retries) {
                        console.log(`Retry ${attempt}/${this.retries} for ${url}`);
                        setTimeout(() => attemptDownload(attempt + 1), 1000 * attempt);
                    } else {
                        reject(error);
                    }
                });

                request.setTimeout(this.timeout, () => {
                    request.destroy();
                    if (attempt < retries) {
                        console.log(`Timeout - Retry ${attempt}/${this.retries} for ${url}`);
                        setTimeout(() => attemptDownload(attempt + 1), 1000 * attempt);
                    } else {
                        reject(new Error('Request timeout'));
                    }
                });
            };

            attemptDownload();
        });
    }

    /**
     * Download multiple files with concurrency control
     */
    async downloadMultiple(urls, outputDir, options = {}) {
        const results = {
            successful: [],
            failed: []
        };

        // Create output directory
        if (!fs.existsSync(outputDir)) {
            await mkdir(outputDir, { recursive: true });
        }

        const queue = [...urls];
        const activeDownloads = new Set();
        
        console.log(`Starting download of ${urls.length} files...\n`);

        while (queue.length > 0 || activeDownloads.size > 0) {
            // Start new downloads if we have capacity
            while (activeDownloads.size < this.concurrency && queue.length > 0) {
                const url = queue.shift();
                const filename = this.getFilenameFromUrl(url, options.filenameTemplate);
                const outputPath = path.join(outputDir, filename);

                const downloadPromise = this.downloadFile(url, outputPath, (progress) => {
                    if (progress.totalSize) {
                        const mbDownloaded = (progress.downloadedSize / 1024 / 1024).toFixed(2);
                        const mbTotal = (progress.totalSize / 1024 / 1024).toFixed(2);
                        process.stdout.write(
                            `\r📥 ${filename}: ${progress.progress}% (${mbDownloaded}/${mbTotal} MB)`
                        );
                    }
                }).then(result => {
                    activeDownloads.delete(downloadPromise);
                    results.successful.push(result);
                    console.log(`\n✅ Downloaded: ${filename}`);
                    return result;
                }).catch(error => {
                    activeDownloads.delete(downloadPromise);
                    results.failed.push({
                        url,
                        error: error.message
                    });
                    console.log(`\n❌ Failed: ${filename} - ${error.message}`);
                    return null;
                });

                activeDownloads.add(downloadPromise);
            }

            // Wait for any download to complete
            if (activeDownloads.size > 0) {
                await Promise.race(activeDownloads);
            }
        }

        return results;
    }

    /**
     * Generate filename from URL
     */
    getFilenameFromUrl(url, template = null) {
        const parsedUrl = new URL(url);
        const pathname = parsedUrl.pathname;
        
        if (template === 'domain-path') {
            const domain = parsedUrl.hostname;
            const path = pathname.replace(/\//g, '_').replace(/^_/, '');
            return `${domain}${path}`;
        } else if (template === 'timestamp') {
            const ext = path.extname(pathname) || '.bin';
            return `file_${Date.now()}${ext}`;
        } else {
            // Default: use the last part of the path
            const filename = path.basename(pathname);
            return filename || `download_${Date.now()}.bin`;
        }
    }

    /**
     * Read URLs from file
     */
    async readUrlsFromFile(filePath) {
        const content = await fs.promises.readFile(filePath, 'utf8');
        return content.split('\n')
            .map(line => line.trim())
            .filter(line => line && !line.startsWith('#') && this.isValidUrl(line));
    }

    /**
     * Validate URL
     */
    isValidUrl(string) {
        try {
            new URL(string);
            return true;
        } catch (_) {
            return false;
        }
    }
}

// CLI Interface
const yargs = require('yargs/yargs');
const { hideBin } = require('yargs/helpers');

const argv = yargs(hideBin(process.argv))
    .option('url', {
        alias: 'u',
        type: 'string',
        description: 'Single URL to download'
    })
    .option('file', {
        alias: 'f',
        type: 'string',
        description: 'File containing URLs (one per line)'
    })
    .option('output', {
        alias: 'o',
        type: 'string',
        description: 'Output directory',
        default: './downloads'
    })
    .option('concurrency', {
        alias: 'c',
        type: 'number',
        description: 'Number of concurrent downloads',
        default: 3
    })
    .option('timeout', {
        type: 'number',
        description: 'Download timeout in milliseconds',
        default: 30000
    })
    .option('retries', {
        type: 'number',
        description: 'Number of retries per download',
        default: 3
    })
    .option('filename-template', {
        type: 'string',
        choices: ['default', 'domain-path', 'timestamp'],
        description: 'Filename generation template',
        default: 'default'
    })
    .argv;

async function main() {
    const downloader = new DataDownloader({
        concurrency: argv.concurrency,
        timeout: argv.timeout,
        retries: argv.retries
    });

    let urls = [];

    try {
        if (argv.url) {
            urls.push(argv.url);
        }

        if (argv.file) {
            const fileUrls = await downloader.readUrlsFromFile(argv.file);
            urls = urls.concat(fileUrls);
        }

        if (urls.length === 0) {
            console.log('❌ No URLs provided. Use --url or --file option.');
            process.exit(1);
        }

        console.log(`Found ${urls.length} URLs to download`);

        const results = await downloader.downloadMultiple(
            urls, 
            argv.output, 
            { filenameTemplate: argv.filenameTemplate }
        );

        console.log('\n' + '='.repeat(50));
        console.log('DOWNLOAD SUMMARY');
        console.log('='.repeat(50));
        console.log(`✅ Successful: ${results.successful.length}`);
        console.log(`❌ Failed: ${results.failed.length}`);
        console.log(`📁 Output directory: ${path.resolve(argv.output)}`);

        if (results.failed.length > 0) {
            console.log('\nFailed downloads:');
            results.failed.forEach(failure => {
                console.log(`  - ${failure.url}: ${failure.error}`);
            });
            process.exit(1);
        }

    } catch (error) {
        console.log('❌ Error:', error.message);
        process.exit(1);
    }
}

if (require.main === module) {
    main();
}

module.exports = DataDownloader;
