#!/bin/bash

set -e

osImage="registry.suse.com/suse/sle-micro/5.5"
osTags=($(skopeo list-tags docker://$osImage | jq '.Tags[]' | grep -v '.att\|.sig\|latest' | sed 's/"//g'))

isoImage="registry.suse.com/suse/sle-micro-iso/5.5"
isoTags=($(skopeo list-tags docker://$isoImage | jq '.Tags[]' | grep -v '.att\|.sig\|latest' | sed 's/"//g'))

file="./default.json"

echo "[" > $file
for tag in "${osTags[@]}"; do
    cat << EOF >> $file
    {
        "metadata": {
            "name": "v$tag"
        },
        "spec": {
            "version": "v$tag",
            "type": "container",
            "metadata": {
                "upgradeImage": "$osImage:$tag",
                "displayName": "Elemental OS"
            }
        }
    },
EOF
done
for tag in "${isoTags[@]}"; do
    cat << EOF >> $file
    {
        "metadata": {
            "name": "v$tag"
        },
        "spec": {
            "version": "v$tag",
            "type": "iso",
            "metadata": {
                "uri": "$isoImage:$tag",
                "displayName": "Elemental ISO"
            }
        }
    },
EOF
done
sed -i '$ s/.$//' $file
echo "]" >> $file

cat $file | jq empty

