import sys

try:
    import dropbox
except:
    import os

    os.system("pip3 install dropbox")
    import dropbox

from dropbox.files import WriteMode
from dropbox.exceptions import ApiError, AuthError

TOKEN = 'ZCpe2RAE8SAAAAAAAAAAXTgj5xssxGr-LKH9U1wtUp0n6q-laOP4pTWOT8Mxh8on'


class SyncDropBox:
    def __init__(self, token):
        self.__token = token
        self.__db = self.__auth()

    def __auth(self):
        print("Creating a Dropbox object...")
        dbx = dropbox.Dropbox(TOKEN)
        try:
            dbx.users_get_current_account()
        except AuthError:
            sys.exit("ERROR: Invalid access token; try re-generating an "
                     "access token from the app console on the web.")
        return dbx

    def upload(self, local_file, remote_file):
        remote_path = "/%s" % remote_file
        with open(local_file, 'rb') as f:
            print("Uploading " + local_file + " to Dropbox as " + remote_path + "...")
            try:
                self.__db.files_upload(f.read(), remote_path, mode=WriteMode('overwrite'))
            except ApiError as err:
                if (err.error.is_path() and
                        err.error.get_path().reason.is_insufficient_space()):
                    sys.exit("ERROR: Cannot back up; insufficient space.")
                elif err.user_message_text:
                    print(err.user_message_text)
                    sys.exit()
                else:
                    print(err)
                    sys.exit()
        try:
            shared_link_metadata = self.__db.sharing_create_shared_link_with_settings(remote_path)
        except ApiError as err:
            shared_link_metadata = err.args[1]._value._value
        return shared_link_metadata.url.replace("dl=0", "raw=1")


if __name__ == '__main__':
    local_path = sys.argv[1]
    remote_path = sys.argv[2]

    db = SyncDropBox(TOKEN)
    share_link = db.upload(local_path, remote_path)
    print(share_link)
    print("Done!")
