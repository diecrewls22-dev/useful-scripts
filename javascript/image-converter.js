#!/usr/bin/env node
/**
 * Image Format Converter
 * Converts images between different formats (JPEG, PNG, WebP, etc.)
 */

const sharp = require('sharp');
const fs = require('fs');
const path = require('path');
const { promisify } = require('util');

const readdir = promisify(fs.readdir);
const stat = promisify(fs.stat);

class ImageConverter {
    constructor() {
        this.supportedFormats = ['jpeg', 'jpg', 'png', 'webp', 'tiff', 'avif'];
    }

    async convertImage(inputPath, outputPath, options = {}) {
        try {
            let image = sharp(inputPath);
            
            // Apply options
            if (options.width || options.height) {
                image = image.resize(options.width, options.height, {
                    fit: options.fit || 'cover',
                    withoutEnlargement: true
                });
            }
            
            if (options.quality) {
                image = image.jpeg({ quality: options.quality });
            }
            
            await image.toFile(outputPath);
            return true;
        } catch (error) {
            throw new Error(`Failed to convert ${inputPath}: ${error.message}`);
        }
    }

    getOutputFormat(inputPath, format) {
        if (format) return format.toLowerCase();
        
        const ext = path.extname(inputPath).toLowerCase().slice(1);
        if (ext === 'jpg') return 'jpeg';
        return ext;
    }

    async processDirectory(inputDir, outputDir, format, options) {
        try {
            const files = await readdir(inputDir);
            const results = {
                successful: [],
                failed: []
            };

            for (const file of files) {
                const inputPath = path.join(inputDir, file);
                const fileStat = await stat(inputPath);

                if (fileStat.isFile()) {
                    const inputFormat = this.getOutputFormat(inputPath, '');
                    
                    if (this.supportedFormats.includes(inputFormat)) {
                        const outputFilename = path.basename(file, path.extname(file)) + '.' + format;
                        const outputPath = path.join(outputDir, outputFilename);

                        try {
                            await this.convertImage(inputPath, outputPath, options);
                            results.successful.push({
                                input: file,
                                output: outputFilename
                            });
                            console.log(`✅ Converted: ${file} → ${outputFilename}`);
                        } catch (error) {
                            results.failed.push({
                                file: file,
                                error: error.message
                            });
                            console.log(`❌ Failed: ${file} - ${error.message}`);
                        }
                    }
                }
            }

            return results;
        } catch (error) {
            throw new Error(`Failed to process directory: ${error.message}`);
        }
    }
}

// CLI Interface
const yargs = require('yargs/yargs');
const { hideBin } = require('yargs/helpers');

const argv = yargs(hideBin(process.argv))
    .option('input', {
        alias: 'i',
        type: 'string',
        description: 'Input file or directory',
        demandOption: true
    })
    .option('output', {
        alias: 'o',
        type: 'string',
        description: 'Output file or directory',
        demandOption: true
    })
    .option('format', {
        alias: 'f',
        type: 'string',
        choices: ['jpeg', 'png', 'webp', 'tiff', 'avif'],
        description: 'Output format',
        demandOption: true
    })
    .option('width', {
        type: 'number',
        description: 'Resize width'
    })
    .option('height', {
        type: 'number',
        description: 'Resize height'
    })
    .option('quality', {
        alias: 'q',
        type: 'number',
        description: 'JPEG quality (1-100)',
        default: 80
    })
    .option('recursive', {
        alias: 'r',
        type: 'boolean',
        description: 'Process subdirectories recursively'
    })
    .argv;

async function main() {
    const converter = new ImageConverter();
    const options = {
        width: argv.width,
        height: argv.height,
        quality: argv.quality
    };

    try {
        const inputStat = await stat(argv.input);
        
        if (inputStat.isFile()) {
            // Single file conversion
            const outputFormat = converter.getOutputFormat(argv.input, argv.format);
            const outputFilename = path.basename(argv.input, path.extname(argv.input)) + '.' + outputFormat;
            const outputPath = path.isAbsolute(argv.output) ? argv.output : path.join(process.cwd(), argv.output, outputFilename);

            await converter.convertImage(argv.input, outputPath, options);
            console.log(`✅ Successfully converted: ${argv.input} → ${outputPath}`);
        
        } else if (inputStat.isDirectory()) {
            // Directory conversion
            if (!fs.existsSync(argv.output)) {
                fs.mkdirSync(argv.output, { recursive: true });
            }

            const results = await converter.processDirectory(argv.input, argv.output, argv.format, options);
            
            console.log('\n📊 Conversion Summary:');
            console.log(`✅ Successful: ${results.successful.length}`);
            console.log(`❌ Failed: ${results.failed.length}`);
            
            if (results.failed.length > 0) {
                console.log('\nFailed files:');
                results.failed.forEach(failure => {
                    console.log(`  - ${failure.file}: ${failure.error}`);
                });
            }
        }
    } catch (error) {
        console.error('❌ Error:', error.message);
        process.exit(1);
    }
}

if (require.main === module) {
    main();
}

module.exports = ImageConverter;
