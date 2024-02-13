#!/bin/bash

# Get the version argument
version=$1

# Check if the version argument is provided
if [ -z "$version" ]; then
    echo "Error: No version argument provided."
    echo "Please provide a version argument or 'all' to download all versions."
    exit 1
fi

# Check if the script should be run for all versions
if [ "$version" == "all" ]; then
    echo "This script will download all available source code & checksum bundles of Perl from CPAN."
    echo "It will then extract them and remove the original tarballs and checksum files."
    echo "This is a long process and will take a lot of time and disk space, as well as place load on the cpan servers."
    echo ""
    read -p "Are you certain you wish to do this? (y/n): " choice
    if [ "$choice" != "y" ]; then
        exit 1
    fi
fi

# Check if curl is available
if ! command -v curl &> /dev/null; then
    echo "curl could not be found. Please install curl and try again."
    exit 1
fi

# Check if sha256sum is available
if ! command -v sha256sum &> /dev/null; then
    echo "sha256sum could not be found. Please install sha256sum and try again."
    exit 1 
fi

# Change to the appropriate directory
cd asset/src/perl

# URL of the index
url="https://www.cpan.org/src/5.0/"

# Fetch the index page
index_page=$(curl -s "$url")

# Extract all links from the index page
links=$(echo "$index_page" | grep -oP 'href="\K[^"]+')

# A place to check we found anything at all
perlfound=0

# Loop through the links
for link in $links; do
    # If the link starts with 'perl' and ends with '.tar.gz'
    if [[ $link == perl*.tar.gz ]] && { [ "$version" == "all" ] || [[ $link == "perl-$version.tar.gz" ]]; }; then
        # Initialize retry count
        retry_count=0

        # Mark we found something
        perlfound=1
        
        # Retry loop
        while [ $retry_count -lt 3 ]; do
            # Download the file to the current directory
            curl -s -O "$url$link"
            
            # Download the corresponding SHA-256 checksum file
            sha_link="${link}.sha256.txt"
            curl -s -O "$url$sha_link"
            
            # Create a properly formatted .sha256.txt file
            checksum=$(cat "${link}.sha256.txt")
            echo "$checksum  $link" > "${link}.sha256.txt"
            
            # Validate the downloaded .tar.gz file
            echo "Validating $link..."
            if sha256sum -c "${link}.sha256.txt"; then
                echo "$link validated successfully."
                break
            else
                echo "$link validation failed. Retrying..."
                ((retry_count++))
            fi
        done
        
        # If validation failed after 3 retries
        if [ $retry_count -eq 3 ]; then
            echo "Failed to validate $link after 3 retries. Stopping further downloads."
            exit 1
        fi

        # Extraction
        echo "Download of $link and its checksum completed successfully, extracting..."
        extract_success=0
        tar -xzf "$link" && rm "$link" "${link}.sha256.txt" && extract_success=1
        
        if [ $extract_success -eq 1 ]; then
            echo "Extraction of $link completed successfully."
        else
            echo "Extraction of $link failed."
        fi

        echo ""
    fi
done

exit $((1 - perlfound))
