#!/bin/sh
DIR=$(dirname "$0")
TAG=$(sed -nE '/^project/{s/.* ([0-9.]+).*/\1/p;q}' CMakeLists.txt)-$(git rev-parse --short HEAD)
git -C "$DIR" tag "$TAG"
git -C "$DIR" push origin "$TAG"
