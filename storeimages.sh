#!/bin/bash
# This script will split the base.img file into 5MB chunks and store them in the base directory.
for fullfilepath in asset/*.img; do
    file=$(basename "$fullfilepath")
    filename="${file%.*}"
    echo "Processing $file"
    mkdir -p "asset/$filename"
    rm -Rf "asset/$filename/*"
    split -a 3 -b 5M "$fullfilepath" "asset/$filename/$filename.img."
done
