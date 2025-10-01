#!/bin/bash

# Automated Backup Script
# Creates compressed backups of directories and databases

# Configuration
BACKUP_NAME="backup_$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="/var/backups"
RETENTION_DAYS=7
COMPRESSION="tar.gz"  # tar.gz, zip, or bzip2

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
LOG_FILE="$BACKUP_DIR/backup.log"

# Function to log messages
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -d, --dir DIR1,DIR2,...    Directories to backup"
    echo "  -m, --mysql                Backup MySQL databases"
    echo "  -p, --postgres             Backup PostgreSQL databases"
    echo "  -c, --compression TYPE     Compression type: gzip, bzip2, zip"
    echo "  -o, --output DIR           Output directory"
    echo "  -r, --retention DAYS       Retention days (default: 7)"
    echo "  -v, --verbose              Verbose output"
    echo "  -h, --help                 Show this help"
    exit 1
}

# Function to check prerequisites
check_prerequisites() {
    local missing_tools=()
    
    # Check for compression tools
    case "$COMPRESSION" in
        "tar.gz"|"tgz")
            if ! command -v tar &> /dev/null || ! command -v gzip &> /dev/null; then
                missing_tools+=("tar/gzip")
            fi
            ;;
        "tar.bz2"|"tbz2")
            if ! command -v tar &> /dev/null || ! command -v bzip2 &> /dev/null; then
                missing_tools+=("tar/bzip2")
            fi
            ;;
        "zip")
            if ! command -v zip &> /dev/null; then
                missing_tools+=("zip")
            fi
            ;;
    esac
    
    # Check for database tools if needed
    if [ "$BACKUP_MYSQL" = true ] && ! command -v mysqldump &> /dev/null; then
        missing_tools+=("mysqldump")
    fi
    
    if [ "$BACKUP_POSTGRES" = true ] && ! command -v pg_dump &> /dev/null; then
        missing_tools+=("pg_dump")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_message "ERROR" "Missing required tools: ${missing_tools[*]}"
        exit 1
    fi
}

# Function to create backup directory
create_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        log_message "INFO" "Creating backup directory: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
        
        if [ $? -ne 0 ]; then
            log_message "ERROR" "Failed to create backup directory: $BACKUP_DIR"
            exit 1
        fi
    fi
}

# Function to backup directories
backup_directories() {
    if [ -z "$DIRS_TO_BACKUP" ]; then
        return 0
    fi
    
    log_message "INFO" "Starting directory backups..."
    
    local backup_file="$BACKUP_DIR/${BACKUP_NAME}_files.$COMPRESSION"
    local temp_dir="/tmp/backup_$$"
    
    mkdir -p "$temp_dir"
    
    # Copy directories to temp location
    IFS=',' read -ra DIR_ARRAY <<< "$DIRS_TO_BACKUP"
    for dir in "${DIR_ARRAY[@]}"; do
        if [ -d "$dir" ]; then
            log_message "INFO" "Backing up directory: $dir"
            cp -r "$dir" "$temp_dir/" 2>/dev/null
            
            if [ $? -ne 0 ]; then
                log_message "WARNING" "Failed to backup some files in: $dir"
            fi
        else
            log_message "WARNING" "Directory not found: $dir"
        fi
    done
    
    # Create compressed archive
    case "$COMPRESSION" in
        "tar.gz"|"tgz")
            tar -czf "$backup_file" -C "$temp_dir" . 2>/dev/null
            ;;
        "tar.bz2"|"tbz2")
            tar -cjf "$backup_file" -C "$temp_dir" . 2>/dev/null
            ;;
        "zip")
            (cd "$temp_dir" && zip -rq "$backup_file" .) 2>/dev/null
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        local file_size=$(du -h "$backup_file" | cut -f1)
        log_message "SUCCESS" "Directory backup created: $backup_file ($file_size)"
    else
        log_message "ERROR" "Failed to create directory backup archive"
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
}

# Function to backup MySQL databases
backup_mysql() {
    if [ "$BACKUP_MYSQL" != true ]; then
        return 0
    fi
    
    log_message "INFO" "Starting MySQL database backups..."
    
    # MySQL configuration (you might want to move this to a config file)
    MYSQL_USER="${MYSQL_USER:-root}"
    MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"
    MYSQL_HOST="${MYSQL_HOST:-localhost}"
    
    # Get list of databases
    local databases
    if [ -n "$MYSQL_PASSWORD" ]; then
        databases=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" -e "SHOW DATABASES;" 2>/dev/null | grep -v Database | grep -v information_schema | grep -v performance_schema)
    else
        databases=$(mysql -u "$MYSQL_USER" -h "$MYSQL_HOST" -e "SHOW DATABASES;" 2>/dev/null | grep -v Database | grep -v information_schema | grep -v performance_schema)
    fi
    
    if [ -z "$databases" ]; then
        log_message "WARNING" "No MySQL databases found or connection failed"
        return 1
    fi
    
    local backup_file="$BACKUP_DIR/${BACKUP_NAME}_mysql.sql.$COMPRESSION"
    local temp_file="/tmp/mysql_backup_$$.sql"
    
    # Backup all databases
    for db in $databases; do
        log_message "INFO" "Backing up MySQL database: $db"
        
        if [ -n "$MYSQL_PASSWORD" ]; then
            mysqldump -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" --single-transaction --routines --triggers "$db" >> "$temp_file" 2>/dev/null
        else
            mysqldump -u "$MYSQL_USER" -h "$MYSQL_HOST" --single-transaction --routines --triggers "$db" >> "$temp_file" 2>/dev/null
        fi
        
        if [ $? -ne 0 ]; then
            log_message "WARNING" "Failed to backup MySQL database: $db"
        fi
        
        echo "--" >> "$temp_file"
        echo "" >> "$temp_file"
    done
    
    # Compress the backup
    case "$COMPRESSION" in
        "tar.gz"|"tgz")
            gzip -c "$temp_file" > "$backup_file"
            ;;
        "tar.bz2"|"tbz2")
            bzip2 -c "$temp_file" > "$backup_file"
            ;;
        "zip")
            zip -q "$backup_file" "$temp_file"
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        local file_size=$(du -h "$backup_file" | cut -f1)
        log_message "SUCCESS" "MySQL backup created: $backup_file ($file_size)"
    else
        log_message "ERROR" "Failed to compress MySQL backup"
    fi
    
    rm -f "$temp_file"
}

# Function to backup PostgreSQL databases
backup_postgres() {
    if [ "$BACKUP_POSTGRES" != true ]; then
        return 0
    fi
    
    log_message "INFO" "Starting PostgreSQL database backups..."
    
    # PostgreSQL configuration
    PG_USER="${PG_USER:-postgres}"
    PG_HOST="${PG_HOST:-localhost}"
    
    # Get list of databases
    local databases
    databases=$(psql -U "$PG_USER" -h "$PG_HOST" -l -t 2>/dev/null | cut -d'|' -f1 | sed 's/ //g' | grep -v template | grep -v postgres)
    
    if [ -z "$databases" ]; then
        log_message "WARNING" "No PostgreSQL databases found or connection failed"
        return 1
    fi
    
    local backup_file="$BACKUP_DIR/${BACKUP_NAME}_postgresql.sql.$COMPRESSION"
    local temp_file="/tmp/postgresql_backup_$$.sql"
    
    # Backup all databases
    for db in $databases; do
        if [ -n "$db" ]; then
            log_message "INFO" "Backing up PostgreSQL database: $db"
            
            pg_dump -U "$PG_USER" -h "$PG_HOST" -d "$db" --clean >> "$temp_file" 2>/dev/null
            
            if [ $? -ne 0 ]; then
                log_message "WARNING" "Failed to backup PostgreSQL database: $db"
            fi
            
            echo "--" >> "$temp_file"
            echo "" >> "$temp_file"
        fi
    done
    
    # Compress the backup
    case "$COMPRESSION" in
        "tar.gz"|"tgz")
            gzip -c "$temp_file" > "$backup_file"
            ;;
        "tar.bz2"|"tbz2")
            bzip2 -c "$temp_file" > "$backup_file"
            ;;
        "zip")
            zip -q "$backup_file" "$temp_file"
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        local file_size=$(du -h "$backup_file" | cut -f1)
        log_message "SUCCESS" "PostgreSQL backup created: $backup_file ($file_size)"
    else
        log_message "ERROR" "Failed to compress PostgreSQL backup"
    fi
    
    rm -f "$temp_file"
}

# Function to cleanup old backups
cleanup_old_backups() {
    log_message "INFO" "Cleaning up backups older than $RETENTION_DAYS days..."
    
    local deleted_count=0
    local current_time=$(date +%s)
    local retention_seconds=$((RETENTION_DAYS * 24 * 60 * 60))
    
    for backup_file in "$BACKUP_DIR"/*.{tar.gz,tbz2,zip,sql.gz,sql.bz2,sql.zip} 2>/dev/null; do
        if [ -f "$backup_file" ]; then
            local file_age=$(($current_time - $(stat -c %Y "$backup_file")))
            
            if [ $file_age -gt $retention_seconds ]; then
                rm -f "$backup_file"
                if [ $? -eq 0 ]; then
                    log_message "INFO" "Deleted old backup: $(basename "$backup_file")"
                    ((deleted_count++))
                fi
            fi
        fi
    done
    
    log_message "INFO" "Cleanup completed: $deleted_count old backups deleted"
}

# Function to calculate backup size
calculate_backup_size() {
    local total_size=0
    
    for backup_file in "$BACKUP_DIR"/${BACKUP_NAME}_*; do
        if [ -f "$backup_file" ]; then
            local size=$(stat -c %s "$backup_file" 2>/dev/null || stat -f %z "$backup_file")
            total_size=$((total_size + size))
        fi
    done
    
    # Convert to human readable
    if [ $total_size -ge 1073741824 ]; then
        echo "$(echo "scale=2; $total_size/1073741824" | bc) GB"
    elif [ $total_size -ge 1048576 ]; then
        echo "$(echo "scale=2; $total_size/1048576" | bc) MB"
    elif [ $total_size -ge 1024 ]; then
        echo "$(echo "scale=2; $total_size/1024" | bc) KB"
    else
        echo "${total_size} B"
    fi
}

# Main execution
main() {
    log_message "INFO" "Starting backup process: $BACKUP_NAME"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--dir)
                DIRS_TO_BACKUP="$2"
                shift 2
                ;;
            -m|--mysql)
                BACKUP_MYSQL=true
                shift
                ;;
            -p|--postgres)
                BACKUP_POSTGRES=true
                shift
                ;;
            -c|--compression)
                COMPRESSION="$2"
                shift 2
                ;;
            -o|--output)
                BACKUP_DIR="$2"
                shift 2
                ;;
            -r|--retention)
                RETENTION_DAYS="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                log_message "ERROR" "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    # Validate inputs
    if [ -z "$DIRS_TO_BACKUP" ] && [ "$BACKUP_MYSQL" != true ] && [ "$BACKUP_POSTGRES" != true ]; then
        log_message "ERROR" "No backup sources specified. Use -d, -m, or -p options."
        usage
    fi
    
    # Check prerequisites
    check_prerequisites
    
    # Create backup directory
    create_backup_dir
    
    # Perform backups
    backup_directories
    backup_mysql
    backup_postgres
    
    # Cleanup old backups
    cleanup_old_backups
    
    # Summary
    local total_size=$(calculate_backup_size)
    log_message "SUCCESS" "Backup process completed successfully!"
    log_message "INFO" "Total backup size: $total_size"
    log_message "INFO" "Backup files stored in: $BACKUP_DIR"
}

# Run main function with all arguments
main "$@"
