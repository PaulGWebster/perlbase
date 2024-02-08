#!/bin/bash
# This script will recreate the original image from the split chunks.
for directory in asset/*; do
    if [ -d "$directory" ] && [ "$directory" != "asset/src" ]; then
        dirname=$(basename "$directory")
        echo "Processing $dirname"
        cat "$directory"/*.img.* > "asset/$dirname.img"
        # Prompt the user to load the image
        read -p "Do you want to load the image? (y/n): " choice
        if [ "$choice" == "y" ]; then
            cat "asset/$dirname.img" | docker load
        fi
    fi
done
