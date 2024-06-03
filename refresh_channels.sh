#!/bin/bash

set -e

# Prefixes the ManagedOSVersion name with flavor value, if any
function format_managed_os_version_name() {
    local flavor=$1
    local tag=$2
    if [ -z "$flavor" ]; then
        echo "v${tag}"
    else
        echo "${flavor}-v${tag}"
    fi
}

# Prints one OS JSON array entry
function append_os_entry() {
    local file=$1
    local os_version_name=$2
    local version=$3
    local image_uri=$4
    local display_name=$5
    cat >> "$file" << EOF
    {
        "metadata": {
            "name": "$os_version_name"
        },
        "spec": {
            "version": "v$version",
            "type": "container",
            "metadata": {
                "upgradeImage": "$image_uri",
                "displayName": "$display_name"
            }
        }
    },
EOF
}

# Prints one ISO JSON array entry
function append_iso_entry() {
    local file=$1
    local os_version_name=$2
    local version=$3
    local image_uri=$4
    local display_name=$5
    cat >> "$file" << EOF
    {
        "metadata": {
            "name": "$os_version_name"
        },
        "spec": {
            "version": "v$version",
            "type": "iso",
            "metadata": {
                "uri": "$image_uri",
                "displayName": "$display_name"
            }
        }
    },
EOF
}

watches=$(yq e -o=j -I=0 '.watches[]' config.yaml)

# Loop through all watches
while IFS=\= read watch; do
    # Parse one entry
    flavor=$(echo "$watch" | yq e '.flavor')
    file_name=$(echo "$watch" | yq e '.fileName')
    display_name=$(echo "$watch" | yq e '.displayName')
    os_repo=$(echo "$watch" | yq e '.osRepo')
    iso_repo=$(echo "$watch" | yq e '.isoRepo')

    # Start writing the channel file by opening a JSON array
    file="channels/$file_name.json"
    echo "Creating $file_name"
    echo "[" > $file

    # Process OS container tags
    os_tags=($(skopeo list-tags docker://$os_repo | jq '.Tags[]' | grep -v '.att\|.sig\|latest' | sed 's/"//g'))
    for tag in "${os_tags[@]}"; do
        # Omit version (non-build) tags
        if [[ $tag =~ ^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$ ]]; then
            continue
        fi
        managed_os_version_name=$(format_managed_os_version_name "$flavor" "$tag")
        append_os_entry "$file" "$managed_os_version_name" "$tag" "$os_repo:$tag" "$display_name OS"
    done

    # Process ISO container tags (if applicable)
    if [ "$iso_repo" != "N/A" ]; then
        iso_tags=($(skopeo list-tags docker://$iso_repo | jq '.Tags[]' | grep -v '.att\|.sig\|latest' | sed 's/"//g'))
        for tag in "${iso_tags[@]}"; do
            # Omit version (non-build) tags
            if [[ $tag =~ ^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$ ]]; then
                continue
            fi
            managed_os_version_name=$(format_managed_os_version_name "$flavor" "$tag")
            append_iso_entry "$file" "$managed_os_version_name" "$tag" "$iso_repo:$tag" "$display_name ISO"
        done
    fi

    # Delete trailing ',' from array. (technically last written char on the file)
    sed -i '$ s/.$//' $file

    # Close the JSON Array
    echo "]" >> $file

    # Validate the JSON file
    cat $file | jq empty
done <<END
$watches
END
