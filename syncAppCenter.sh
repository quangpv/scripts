OWNER_NAME="quangpv.uit-gmail.com"
APP_NAME="ExampleApp"
API_TOKEN="285b46aefa30a4724e0f7cc8ed640d252aa25944"
DISTRIBUTION_GROUP="Collaborators"
FILE_NAME="$APP_NAME.apk"
buildFlavor=""
buildMode="debug"
PROJECT_DIR=$(dirname $(pwd))
RELEASE_FILE_LOCATION="$PROJECT_DIR/app/build/outputs/apk/debug/app-debug.apk"

function buildApp() {
  $PROJECT_DIR/gradlew -p "$PROJECT_DIR" "assemble$buildFlavor$buildMode" || exit 1
}

PACKAGE_ASSET_ID=""
URL_ENCODED_TOKEN=""
ID=""
function createUpload() {
  echo "Create Upload"
  uploadInfo=$(curl -s -X POST "https://api.appcenter.ms/v0.1/apps/$OWNER_NAME/$APP_NAME/uploads/releases" -H "accept: application/json" -H "X-API-Token: $API_TOKEN" -H "Content-Type: application/json" | python3 -m json.tool)
  ID=$(echo "$uploadInfo" | jq -r '.id')
  PACKAGE_ASSET_ID=$(echo "$uploadInfo" | jq -r '.package_asset_id')
  URL_ENCODED_TOKEN=$(echo "$uploadInfo" | jq -r '.url_encoded_token')
}

CHUNK_SIZE=0
function createMetadata() {
  echo "Create Metadata"
  FILE_SIZE_BYTES=$(wc -c "$RELEASE_FILE_LOCATION" | awk '{print $1}')
  APP_TYPE='application/vnd.android.package-archive' # iOS uses `application/octet-stream` instead.

  METADATA_URL="https://file.appcenter.ms/upload/set_metadata/$PACKAGE_ASSET_ID?file_name=$FILE_NAME&file_size=$FILE_SIZE_BYTES&token=$URL_ENCODED_TOKEN&content_type=$APP_TYPE"

  metadata=$(curl -s -d POST -H "Content-Type: application/json" -H "Accept: application/json" -H "X-API-Token: $API_TOKEN" "$METADATA_URL" | python3 -m json.tool)
  CHUNK_SIZE=$(echo "$metadata" | jq -r '.chunk_size')
}

function splitFile() {
  echo "Split file"
  split -b $CHUNK_SIZE "$RELEASE_FILE_LOCATION" temp/split
}

function uploadChunks() {
  echo "Upload Chunks"

  BLOCK_NUMBER=0

  for i in temp/*; do
    BLOCK_NUMBER=$(($BLOCK_NUMBER + 1))
    CONTENT_LENGTH=$(wc -c "$i" | awk '{print $1}')

    UPLOAD_CHUNK_URL="https://file.appcenter.ms/upload/upload_chunk/$PACKAGE_ASSET_ID?token=$URL_ENCODED_TOKEN&block_number=$BLOCK_NUMBER"

    curl -X POST "$UPLOAD_CHUNK_URL" --data-binary "@$i" -H "Content-Length: $CONTENT_LENGTH" -H "Content-Type: $CONTENT_TYPE" 1>/dev/null
  done
}

function markAsUploadFinished() {
  echo "Finish Upload"
  FINISHED_URL="https://file.appcenter.ms/upload/finished/$PACKAGE_ASSET_ID?token=$URL_ENCODED_TOKEN"
  curl -s -d POST -H "Content-Type: application/json" -H "Accept: application/json" -H "X-API-Token: $API_TOKEN" "$FINISHED_URL" 1>/dev/null

  COMMIT_URL="https://api.appcenter.ms/v0.1/apps/$OWNER_NAME/$APP_NAME/uploads/releases/$ID"
  curl -s -H "Content-Type: application/json" -H "Accept: application/json" -H "X-API-Token: $API_TOKEN" \
    --data '{"upload_status": "uploadFinished","id": "$ID"}' \
    -X PATCH \
    "$COMMIT_URL" 1>/dev/null
}

RELEASE_ID=null
function fetchReleaseId() {
  echo "Fetch Release Id"
  count=0
  while [ $RELEASE_ID == null ]; do
    sleep 1
    RELEASE_STATUS_URL="https://api.appcenter.ms/v0.1/apps/$OWNER_NAME/$APP_NAME/uploads/releases/$ID"
    POLL_RESULT=$(curl -s -H "Content-Type: application/json" -H "Accept: application/json" -H "X-API-Token: $API_TOKEN" "$RELEASE_STATUS_URL")
    RELEASE_ID=$(echo "$POLL_RESULT" | jq -r '.release_distinct_id')

    if [[ $RELEASE_ID != null ]]; then
      break
    fi
    if [[ $count == 5 ]]; then
      echo "Failed to find release from appcenter"
      exit 1
    fi
    count=$(($count + 1))
  done

  echo "Release Id = $RELEASE_ID"
}

function distributeRelease() {
  echo "Distribute to group $DISTRIBUTION_GROUP"
  DISTRIBUTE_URL="https://api.appcenter.ms/v0.1/apps/$OWNER_NAME/$APP_NAME/releases/$RELEASE_ID"

  curl -s -H "Content-Type: application/json" -H "Accept: application/json" -H "X-API-Token: $API_TOKEN" \
    --data '{"destinations": [{ "name": "'"$DISTRIBUTION_GROUP"'"}] }' \
    -X PATCH \
    "$DISTRIBUTE_URL" 1>/dev/null
}

buildApp
createUpload
createMetadata
splitFile
uploadChunks
markAsUploadFinished
fetchReleaseId
distributeRelease
