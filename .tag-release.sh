#!/bin/bash

echo "Tagging $GITHUB_SHA as $TAG"
curl -X post -d @- https://api.github.com/repos/$GITHUB_REPOSITORY/git/tags \
  -H "Authorization: token $GITHUB_TOKEN" << EOF
{"tag_name":"$TAG_NAME", "target_commitish":"$GITHUB_SHA"}
EOF
