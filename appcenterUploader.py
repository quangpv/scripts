import os.path
import sys
from time import sleep

import requests as http_request

requests = http_request.Session()

api_endpoint = 'https://api.appcenter.ms/v0.1/apps'
file_endpoint = 'https://file.appcenter.ms/upload/set_metadata'
app_type = 'application/vnd.android.package-archive'

owner_name = ""
app_name = ""
file_location = ""
api_token = ""
file_name = f"{app_name}.apk"
collaborators = []
release_notes = ""

headers = {
    "Content-Type": "application/json",
    "accept": "application/json",
}


def split_file(size):
    with open(file_location, 'rb') as f:
        while content := f.read(size):
            yield content


def create_upload():
    print("Create Upload")
    result = requests.post(f'{api_endpoint}/{owner_name}/{app_name}/uploads/releases', headers=headers).json()
    return result


def url_of(url, params):
    if params.keys().__len__() == 0:
        return url
    query: str = ""
    for key in params:
        query = f"{query}&{key}={params[key]}"
    query = query[1:]
    return f"{url}?{query}"


def create_metadata(metadata: any):
    print("Create File Metadata")
    file_size = os.path.getsize(file_location)
    params = {
        'file_name': file_name,
        'file_size': file_size,
        "token": metadata['url_encoded_token'],
        'content_type': app_type
    }

    url = url_of(f"https://file.appcenter.ms/upload/set_metadata/{metadata['package_asset_id']}", params)
    result = requests.post(url, headers=headers).json()
    metadata['chunk_size'] = result['chunk_size']
    metadata['file_size'] = file_size
    return metadata


def upload_file(metadata):
    print("Upload file")
    block_number = 0
    file_size = metadata['file_size']
    chunk_size = metadata['chunk_size']
    chunks = split_file(chunk_size)
    total_block = file_size / chunk_size

    for chunk in chunks:
        block_number = block_number + 1
        chunk_size = len(chunk)
        url = f"https://file.appcenter.ms/upload/upload_chunk/{metadata['package_asset_id']}"

        requests.post(
            url_of(url, {
                'token': metadata['url_encoded_token'],
                'block_number': block_number
            }),
            headers={
                'Content-Length': str(chunk_size),
                'Content-Type': app_type
            }, data=chunk)
        print("Uploading ", round(min(max(float(block_number) / total_block, 0), 1) * 100, 2), '%')

    requests.post(url_of(f'https://file.appcenter.ms/upload/finished/{metadata["package_asset_id"]}', {
        'token': metadata['url_encoded_token'],
    }), headers=headers)

    package_id = metadata['id']
    data = {"upload_status": "uploadFinished", "id": package_id}
    requests.patch(
        f'https://api.appcenter.ms/v0.1/apps/{owner_name}/{app_name}/uploads/releases/{package_id}',
        json=data,
        headers=headers,
    )
    return metadata


def await_release(metadata):
    url = f"https://api.appcenter.ms/v0.1/apps/{owner_name}/{app_name}/uploads/releases/{metadata['id']}"
    max_wait = 15
    waiting = 0
    while waiting < max_wait:
        sleep(1)
        release_result = requests.get(url, headers=headers).json()
        key = 'release_distinct_id'
        if key in release_result:
            release_id = release_result[key]
            if release_id is not None:
                return release_id
        if 'upload_status' in release_result:
            print("Upload status", release_result['upload_status'])
        waiting += 1
    raise Exception("Not found release id")


def distribute(metadata):
    release_id = await_release(metadata)
    print("Distribute publish to groups")
    url = f"https://api.appcenter.ms/v0.1/apps/{owner_name}/{app_name}/releases/{release_id}"
    cols = []
    for col in collaborators:
        cols.append({"name": col})
    data = {
        "destinations": cols,
        'release_notes': release_notes
    }
    result = requests.patch(url, json=data, headers=headers).json()
    if 'message' in result:
        print(result['message'])


def require(field, fail):
    if field is None or field.strip().__len__() == 0:
        raise f"{fail()} is required"


def deserialize(data):
    deserialized = []
    for col in data.split(","):
        row = col.strip()
        if row.__len__() > 0:
            deserialized.append(col)
    return deserialized


def serialize(data):
    return ' '.join([str(elem) for elem in data])


if __name__ == '__main__':
    owner_name = sys.argv[1]
    app_name = sys.argv[2]
    api_token = sys.argv[3]
    file_location = sys.argv[4]
    arg_collaborators = sys.argv[5]
    release_notes = sys.argv[6:]

    require(owner_name, lambda: "Owner name")
    require(app_name, lambda: "App name")
    require(api_token, lambda: "Api token")
    require(file_location, lambda: "File location")
    require(arg_collaborators, lambda: "Collaborators")

    collaborators = deserialize(arg_collaborators)
    release_notes = serialize(release_notes)

    headers["X-API-Token"] = api_token
    # print(owner_name, app_name, api_token, file_location, collaborators, release_notes)
    distribute(upload_file(create_metadata(create_upload())))
    requests.close()
