#!/bin/bash

set -e

watches=$(yq e -o=j -I=0 '.watches[]' config.yaml)

# Loop through all watches
while IFS=\= read watch; do
    # Parse one entry
    flavor=$(echo "$watch" | yq e '.flavor')
    fileName=$(echo "$watch" | yq e '.fileName')
    displayName=$(echo "$watch" | yq e '.displayName')
    osRepo=$(echo "$watch" | yq e '.osRepo')
    isoRepo=$(echo "$watch" | yq e '.isoRepo')

    # Fetch the OS Image tags
    osTags=($(skopeo list-tags docker://$osRepo | jq '.Tags[]' | grep -v '.att\|.sig\|latest' | sed 's/"//g'))

    # Start writing the channel file
    file="channels/$fileName.json"
    echo "Creating $fileName"
    echo "[" > $file
    for tag in "${osTags[@]}"; do
        if [ -z $flavor ]; then
            name="v${tag}"
        else
            name="${flavor}-v${tag}"
        fi
        cat << EOF >> $file
    {
        "metadata": {
            "name": "$name"
        },
        "spec": {
            "version": "v$tag",
            "type": "container",
            "metadata": {
                "upgradeImage": "$osRepo:$tag",
                "displayName": "$displayName OS"
            }
        }
    },
EOF
    done

    ## Fetch the ISO Image tags (if applicable)
    if [ $isoRepo != "N/A" ]; then
        isoTags=($(skopeo list-tags docker://$isoRepo | jq '.Tags[]' | grep -v '.att\|.sig\|latest' | sed 's/"//g'))
        for tag in "${isoTags[@]}"; do
            if [ -z $flavor ]; then
                name="v${tag}"
            else
                name="${flavor}-v${tag}"
            fi
            cat << EOF >> $file
    {
        "metadata": {
            "name": "$name"
        },
        "spec": {
            "version": "v$tag",
            "type": "iso",
            "metadata": {
                "uri": "$isoRepo:$tag",
                "displayName": "$displayName ISO"
            }
        }
    },
EOF
        done
    fi

    # Delete trailing ',' from array. (technically last written char on the file)
    sed -i '$ s/.$//' $file

    # Close the JSON Array
    echo "]" >> $file

    # Validate the JSON file
    cat $file | jq empty
done <<EOF
$watches
EOF
