#!/bin/bash
if [ -z $(git tag) ]
then
  echo "Using default tag"
  TAG="1.0.0"
elif [ -z "$(git tag -l --points-at HEAD)" ]
then
  echo "git tags"
  git tag
  LATEST_VERISON=$(git tag| grep -o "[0-9][0-9]*.[0-9][0-9]*.[0-9][0-9]*" | sort -Vr | head -n1)
  echo "Latest Version: $LATEST_VERISON"
  NEXT_VERSION=$(echo $LATEST_VERISON | cut -d '.' -f 1).$(echo $LATEST_VERISON | cut -d '.' -f 2).$(expr $( echo $LATEST_VERISON | cut -d '.' -f 3) + 1)
  echo "NEXT_VERSION: $NEXT_VERSION"
  TAG=$NEXT_VERSION
else
  echo "HEAD tags"
  git tag -l --points-at HEAD
  CURRENT_VERISON=$(git tag -l --points-at HEAD| grep -o "[0-9][0-9]*.[0-9][0-9]*.[0-9][0-9]*" | sort -Vr | head -n1)
  echo $CURRENT_VERISON
  TAG="$CURRENT_VERISON-$(date +"%F-%H-%M")"
fi
git tag $TAG
git push --tags
