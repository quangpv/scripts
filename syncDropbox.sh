#!/usr/bin/env sh

projectDir=$(dirname $(pwd))

#buildFlavor="pro"
#buildMode="release"

buildFlavor="dev"
buildMode="debug"

$projectDir/gradlew -p $projectDir "assemble$buildFlavor$buildMode" || exit 1

suffixFile="$buildFlavor-$buildMode.apk"

outputFolderPath="$projectDir/app/build/outputs/apk/$buildFlavor/$buildMode"
outputFile="app-$suffixFile"

exportName="flexio-$suffixFile"
sourcePath="$outputFolderPath/$outputFile"

python3 "uploader.py" $sourcePath $exportName

revealFolder() {
  open "$outputFolderPath"
}

case $1 in
"y")
  revealFolder
  ;;
"Y")
  revealFolder
  ;;
esac
