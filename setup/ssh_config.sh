#!/bin/bash

# Path to SSH config file
SSH_CONFIG="${HOME}/.ssh/config"

# Content to add
INCLUDE_LINE="Include ~/.mmdot/homelab_ssh_config"
HOST_BLOCK="Host *
    Include ~/.mmdot/homelab_ssh_config"

# Create .ssh directory if it doesn't exist
mkdir -p "${HOME}/.ssh"

# Create config file if it doesn't exist
if [ ! -f "$SSH_CONFIG" ]; then
    touch "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
fi

# Check if the include directive already exists
if grep -q "Include.*\.mmdot/homelab_ssh_config" "$SSH_CONFIG"; then
    echo "Homelab SSH config include already exists in $SSH_CONFIG"
    exit 0
fi

# Check if "Host *" section exists
if grep -q "^Host \*" "$SSH_CONFIG"; then
    # Host * exists, check if it already has the include under it
    if awk '/^Host \*$/,/^Host / {if (/Include.*\.mmdot\/homelab_ssh_config/) exit 0} END {exit 1}' "$SSH_CONFIG"; then
        echo "Homelab SSH config include already exists under 'Host *'"
        exit 0
    fi
    
    # Add Include directive right after "Host *"
    sed -i.bak '/^Host \*/a\
    Include ~/.mmdot/homelab_ssh_config
' "$SSH_CONFIG"
    echo "Added Include directive under existing 'Host *' section in $SSH_CONFIG"
else
    # No "Host *" section exists, add the entire block at the beginning
    # Create temporary file with new content
    {
        echo "$HOST_BLOCK"
        echo ""
        cat "$SSH_CONFIG"
    } > "${SSH_CONFIG}.tmp"
    
    # Replace original with temporary file
    mv "${SSH_CONFIG}.tmp" "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
    echo "Added 'Host *' section with Include directive to $SSH_CONFIG"
fi

echo "Done!"
