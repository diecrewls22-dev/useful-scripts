#!/usr/bin/env node
/**
 * JSON Formatter and Validator
 * Formats JSON files and validates JSON syntax
 */

const fs = require('fs');
const path = require('path');
const { promisify } = require('util');

const readFile = promisify(fs.readFile);
const writeFile = promisify(fs.writeFile);
const access = promisify(fs.access);

class JSONFormatter {
    constructor() {
        this.defaultIndent = 2;
    }

    /**
     * Format JSON string with proper indentation
     */
    formatJSON(jsonString, indent = this.defaultIndent) {
        try {
            const parsed = JSON.parse(jsonString);
            return JSON.stringify(parsed, null, indent);
        } catch (error) {
            throw new Error(`Invalid JSON: ${error.message}`);
        }
    }

    /**
     * Minify JSON string
     */
    minifyJSON(jsonString) {
        try {
            const parsed = JSON.parse(jsonString);
            return JSON.stringify(parsed);
        } catch (error) {
            throw new Error(`Invalid JSON: ${error.message}`);
        }
    }

    /**
     * Validate JSON without formatting
     */
    validateJSON(jsonString) {
        try {
            JSON.parse(jsonString);
            return { valid: true, error: null };
        } catch (error) {
            return { valid: false, error: error.message };
        }
    }

    /**
     * Sort JSON keys alphabetically
     */
    sortJSON(jsonString, indent = this.defaultIndent) {
        try {
            const parsed = JSON.parse(jsonString);
            
            function sortObject(obj) {
                if (Array.isArray(obj)) {
                    return obj.map(sortObject);
                } else if (obj !== null && typeof obj === 'object') {
                    return Object.keys(obj).sort().reduce((result, key) => {
                        result[key] = sortObject(obj[key]);
                        return result;
                    }, {});
                }
                return obj;
            }

            const sorted = sortObject(parsed);
            return JSON.stringify(sorted, null, indent);
        } catch (error) {
            throw new Error(`Invalid JSON: ${error.message}`);
        }
    }

    /**
     * Process a file
     */
    async processFile(inputPath, options = {}) {
        try {
            const content = await readFile(inputPath, 'utf8');
            let output;

            if (options.validateOnly) {
                const validation = this.validateJSON(content);
                return {
                    file: inputPath,
                    valid: validation.valid,
                    error: validation.error
                };
            }

            if (options.minify) {
                output = this.minifyJSON(content);
            } else if (options.sort) {
                output = this.sortJSON(content, options.indent);
            } else {
                output = this.formatJSON(content, options.indent);
            }

            if (options.output) {
                await writeFile(options.output, output, 'utf8');
            }

            return {
                file: inputPath,
                formatted: output,
                valid: true
            };
        } catch (error) {
            return {
                file: inputPath,
                valid: false,
                error: error.message
            };
        }
    }
}

// CLI Interface
const yargs = require('yargs/yargs');
const { hideBin } = require('yargs/helpers');

const argv = yargs(hideBin(process.argv))
    .option('file', {
        alias: 'f',
        type: 'string',
        description: 'Input JSON file',
        demandOption: true
    })
    .option('output', {
        alias: 'o',
        type: 'string',
        description: 'Output file (default: overwrites input)'
    })
    .option('indent', {
        alias: 'i',
        type: 'number',
        description: 'Indentation spaces',
        default: 2
    })
    .option('minify', {
        type: 'boolean',
        description: 'Minify JSON output'
    })
    .option('sort', {
        type: 'boolean',
        description: 'Sort object keys alphabetically'
    })
    .option('validate', {
        alias: 'v',
        type: 'boolean',
        description: 'Validate JSON without formatting'
    })
    .option('in-place', {
        type: 'boolean',
        description: 'Format file in place (overwrite)'
    })
    .argv;

async function main() {
    const formatter = new JSONFormatter();
    const options = {
        indent: argv.indent,
        minify: argv.minify,
        sort: argv.sort,
        validateOnly: argv.validate
    };

    // Determine output file
    if (argv.output) {
        options.output = argv.output;
    } else if (argv.inPlace || !argv.output) {
        options.output = argv.file;
    }

    try {
        // Check if input file exists
        await access(argv.file, fs.constants.F_OK);

        const result = await formatter.processFile(argv.file, options);

        if (options.validateOnly) {
            if (result.valid) {
                console.log(`✅ ${argv.file} - Valid JSON`);
            } else {
                console.log(`❌ ${argv.file} - Invalid JSON: ${result.error}`);
                process.exit(1);
            }
        } else {
            if (result.valid) {
                if (options.output === argv.file) {
                    console.log(`✅ Formatted: ${argv.file} (in-place)`);
                } else {
                    console.log(`✅ Formatted: ${argv.file} → ${options.output}`);
                }
                
                if (!options.output) {
                    // Print to stdout
                    console.log('\n' + result.formatted);
                }
            } else {
                console.log(`❌ Error processing ${argv.file}: ${result.error}`);
                process.exit(1);
            }
        }
    } catch (error) {
        if (error.code === 'ENOENT') {
            console.log(`❌ File not found: ${argv.file}`);
        } else {
            console.log(`❌ Error: ${error.message}`);
        }
        process.exit(1);
    }
}

// If running directly
if (require.main === module) {
    main();
}

module.exports = JSONFormatter;
