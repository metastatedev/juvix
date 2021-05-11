#!/bin/sh

make format

git config user.email "ci@heliax.dev"
git config user.name "Drone CI"

REMOTE=$(git remote get-url origin | cut -c 9-)
PUSH_URL="https://${GITHUB_TOKEN}@${REMOTE}"

git --version
echo $DRONE_SOURCE_BRANCH
git symbolic-ref --short -q HEAD
git status
git remote -v


if [ -z "$(git status src/ library/ test/ --untracked-files=no --porcelain)" ]; then
  exit 0
else
  echo "Committing differences..."
  git checkout $DRONE_SOURCE_BRANCH
  git remote set-url origin $PUSH_URL
  git add -u
  git commit -m "run formatter [CI SKIP]"
  git push --verbose
  exit $?
fi