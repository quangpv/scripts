OWNER_NAME="quangpv.uit-gmail.com"
API_TOKEN_DEV="f0dd0d30499b0df6a1b8aa3306d94640c1e63aea"
API_TOKEN_PRO="d63b7f6cc79c0242a5dcba452f7fcb490edabe43"
COLLABORATORS="Collaborators,Public"
RELEASE_NOTES="Release for testing"

buildFlavor="dev"
#buildFlavor="pro"

buildMode="debug"
#buildMode="release"

API_TOKEN=$API_TOKEN_DEV
PROJECT_DIR=$(dirname $(pwd))
FILE_LOCATION="$PROJECT_DIR/app/build/outputs/apk/debug/app-debug.apk"

APP_SUFFIX="$(tr '[:lower:]' '[:upper:]' <<<${buildFlavor:0:1})${buildFlavor:1}"
APP_NAME="Flexio-$APP_SUFFIX"

if [[ $buildFlavor == "pro" ]]; then
  API_TOKEN=$API_TOKEN_PRO
fi

if [[ -n $buildFlavor ]]; then
  FILE_LOCATION="$PROJECT_DIR/app/build/outputs/apk/$buildFlavor/debug/app-$buildFlavor-debug.apk"
fi

$PROJECT_DIR/gradlew -p "$PROJECT_DIR" "assemble$buildFlavor$buildMode" || exit 1

python3 appcenterUploader.py $OWNER_NAME $APP_NAME $API_TOKEN $FILE_LOCATION $COLLABORATORS $RELEASE_NOTES

echo "https://install.appcenter.ms/users/$OWNER_NAME/apps/$APP_NAME/distribution_groups/public"