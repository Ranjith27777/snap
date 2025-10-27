#!/bin/bash

PROJECT_FILE=$1
MONTH=$(date +%B | tr '[:upper:]' '[:lower:]')
YEAR=$(date +%Y)

if [[ -z "$PROJECT_FILE" ]]; then
  echo "Usage: $0 <project-list-file>"
  exit 1
fi

echo "Reading project file: $PROJECT_FILE"
echo "-----------------------------------------------------"
cat "$PROJECT_FILE"
echo "-----------------------------------------------------"

while read -r PROJECT; do
  [[ -z "$PROJECT" ]] && continue

  echo "****** Processing project ****** : $PROJECT"

  VMS=$(gcloud compute instances list \
    --project="$PROJECT" \
    --format="value(name,zone)")

  echo "   [DEBUG] VMs found (if any):"
  echo "$VMS"

  if [[ -z "$VMS" ]]; then
    echo "⚠️ No VMs found in $PROJECT"
    continue
  fi

  while read -r VM ZONE; do
    echo "VM: $VM (zone: $ZONE)"

    DISKS=$(gcloud compute instances describe "$VM" \
      --project="$PROJECT" \
      --zone="$ZONE" \
      --format="value(disks[].deviceName)")

    echo "      [DEBUG] Disks detected: $DISKS"

    if [[ -z "$DISKS" ]]; then
      echo "⚠️ No disks found for VM $VM"
      continue
    fi
    
    REGION=$(gcloud compute disks describe "$DISK" \
      --project="$PROJECT" \
      --zone="$ZONE" \
      --format="value(region)")

    if [[ -z "$REGION" ]]; then
      REGION=$(echo "$ZONE" | sed 's/-[a-z]$//')   
    else
      REGION=$(basename "$REGION")                 
    fi

    IFS=';' read -ra DISK_ARRAY <<< "$DISKS"
    for DISK in "${DISK_ARRAY[@]}"; do
      CLEAN_DISK=$(echo "$DISK" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')

      SNAPSHOT_NAME="${CLEAN_DISK}-${MONTH}-${YEAR}-patch"
      echo "  ===== > Creating snapshot: $SNAPSHOT_NAME"

      gcloud compute disks snapshot "$DISK" \
        --project="$PROJECT" \
        --zone="$ZONE" \
        --storage-location="$REGION" \
        --snapshot-names="$SNAPSHOT_NAME"
    done
  done <<< "$VMS"
done < "$PROJECT_FILE"

echo "====================================================="
echo "Snapshot process completed for all projects and zones."
echo "====================================================="
