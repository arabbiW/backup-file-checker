#!/bin/bash

CONFIG_FILE="./servers.conf"
LOG_DIR="./logs"

mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/Summary:$(date '+%Y%m%d-%H:%M').log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo " BACKUP FILE COMPARISON"

TOTAL=0
PASS=0
FAIL=0
ERROR=0

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Read configuration using file descriptor 3
exec 3< "$CONFIG_FILE"

while IFS='|' read -r NAME SSH_HOST LOCAL_PATH S3_PATH BACKUP_DATE <&3
do

    # Skip blank lines
    [[ -z "$NAME" ]] && continue

    # Skip comments
    [[ "$NAME" =~ ^[[:space:]]*# ]] && continue

    TOTAL=$((TOTAL + 1))

    echo "============================================================"
    echo "SERVER : $NAME $SSH_HOST"

    S3_FULL_PATH="${S3_PATH}/${BACKUP_DATE}"
    LOCAL_FULL_PATH="${LOCAL_PATH}/${BACKUP_DATE}"
    
    s3_files=$(
        aws s3 ls "$S3_FULL_PATH/" --recursive |
        awk '{
            n=split($4, path, "/");
            print path[n]
        }' |
        sort
    )

    if [[ $? -ne 0 || -z "$s3_files" ]]; then
        echo "ERROR: Unable to get S3 file list."
        ERROR=$((ERROR + 1))
        continue
    fi

    # Get local file list
    # echo "Getting local file list..."
    local_files=$(
        ssh -n \
            -o BatchMode=yes \
            -o ConnectTimeout=10 \
            "$SSH_HOST" \
            "find '$LOCAL_FULL_PATH' -type f -printf '%f\n'" |
        sort
    )

    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        echo "ERROR: Unable to connect to $SSH_HOST or read directory."
        ERROR=$((ERROR + 1))
        continue
    fi

    
    # Comparing local files against S3
    missing_from_s3=$(
        comm -23 \
            <(printf '%s\n' "$local_files") \
            <(printf '%s\n' "$s3_files")
    )

    local_count=$(printf '%s\n' "$local_files" | grep -c .)
    s3_count=$(printf '%s\n' "$s3_files" | grep -c .)
    missing_count=$(printf '%s\n' "$missing_from_s3" | grep -c .)

    echo
    echo "Local files : $local_count"
    echo "S3 files    : $s3_count"
    echo

    if [[ "$missing_count" -eq 0 ]]; then

        echo "RESULT: PASS"
        PASS=$((PASS + 1))

    else

        echo "RESULT: FAIL"
        echo
        echo "LOCAL files NOT matching S3 filename:"
        echo "--------------------------------------"

        printf '%s\n' "$missing_from_s3"

        echo
        echo "Missing from S3: $missing_count"

        FAIL=$((FAIL + 1))
    fi

done

exec 3<&-
echo "============================================================"
 echo "Log file: $LOG_FILE"
 echo "Completed: $(date)"
