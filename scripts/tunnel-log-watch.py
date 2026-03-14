from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import time
import os
import sys
import shutil
import re
import json
import requests

try:
    debug = int(os.environ['DEBUG'])
except:
    debug = 1

try:
    email = os.environ['DEV_EMAIL']
except:
    if debug == 1:
        print("==> ")
        print("==> NOTE: COULD NOT DETERMINE VALUE OF DEV_EMAIL ENVIRONMENT VARIABLE")
        print("==> ")
        sys.exit()

parts = email.split("@")
emailUser = parts[0]
emailDomain = parts[1]

try:
    startDevTunnelT = os.environ['START_DEV_TUNNEL']
except:
    if debug == 1:
        print("==> ")
        print("==> NOTE: COULD NOT DETERMINE VALUE OF START_DEV_TUNNEL ENVIRONMENT VARIABLE")
        print("==> ")
        sys.exit()

startDevTunnel = startDevTunnelT.lower() in ('true', '1', 'yes')

try:
    devWsName = os.environ['DEVWORKSPACE_NAME']
except:
    if debug == 1:
        print("==> ")
        print("==> NOTE: COULD NOT DETERMINE VALUE OF DEVWORKSPACE_NAME ENVIRONMENT VARIABLE")
        print("==> ")

try:
    emailApiUrl = os.environ['EMAIL_API_URL']
except:
    if debug == 1:
        print("==> ")
        print("==> NOTE: COULD NOT DETERMINE VALUE OF EMAIL_API_URL ENVIRONMENT VARIABLE")
        print("==> ")
        sys.exit()

try:
    replyToUser = os.environ['REPLY_TO_USER']
except:
    if debug == 1:
        print("==> ")
        print("==> NOTE: COULD NOT DETERMINE VALUE OF REPLY_TO_USER ENVIRONMENT VARIABLE")
        print("==> ")
        sys.exit()

try:
    replyToDomain = os.environ['REPLY_TO_DOMAIN']
except:
    if debug == 1:
        print("==> ")
        print("==> NOTE: COULD NOT DETERMINE VALUE OF REPLY_TO_DOMAIN ENVIRONMENT VARIABLE")
        print("==> ")
        sys.exit()

try:
    logWatchPath = os.environ['LOG_WATCH_PATH']
except:
    logWatchPath = '/tmp/log-watch-test/'

class LogFileChangeHandler(FileSystemEventHandler):
    def on_modified(self, event):
        if event.src_path.endswith('curr.log'):
            print(f'Log file {event.src_path} has been modified.')
            diff = ""
            diff = get_diff(logWatchPath, curr_log, last_log)
            if(diff):
                process_diff(diff)

def process_diff(diff):
    print("-----------------------------")
    print("the difference is: ")
    print(diff)
    message = diff[0]
    print(f"log message: {message}")

    # Match both GitHub and Microsoft auth messages:
    #   GitHub:    "...log into https://github.com/login/device and use code E8C3-4D28"
    #   Microsoft: "...open the page https://login.microsoft.com/device and enter the code BPRE4PCZE to authenticate."
    url_match = re.search(r'(https?://\S+)', message)
    code_match = re.search(r'code\s+(\S+)', message)

    if url_match and code_match:
        auth_url = url_match.group(1)
        auth_code = code_match.group(1).rstrip('.')
        print(f"### sending code to {emailUser} @ {emailDomain} ###")
        data = {
            "body": f"""
                <html>
                Enter code <b>{auth_code}</b> at <a href='{auth_url}'>{auth_url}</a> to allow the <b>{devWsName}</b> workspace to be used as a code tunnel.
                </html>
                """,
            "recips": [
                {
                    "user":f"{emailUser}",
                    "domain":f"{emailDomain}"
                }
            ],
            "subject": f"Devspaces - Authenticate code tunnel request for workspace {devWsName}",
            "replyToUser":replyToUser,
            "replyToDomain":replyToDomain
        }
        header = {
            'Content-Type': 'application/json'
        }
        print(data)
        dataSend = json.dumps(data)
        response = requests.post(emailApiUrl, data=dataSend, headers=header)
        print(response.text)
    print("-----------------------------")


def init_last_log(path, last_log):
    os.makedirs(path, exist_ok=True)
    f = open(path + last_log, "w")    
    f.close()

def get_diff(path, curr_log, last_log):
    curr_lines = []
    last_lines = []
    diff = []

    last_log_f = open(path + last_log, "r")    
    last_lines = last_log_f.readlines()    
    last_log_f.close()

    try:
        curr_log_f = open(path + curr_log, "r")    
        curr_lines = curr_log_f.readlines()
        curr_log_f.close()
    except:
        return

    diff  = [i for i in curr_lines if i not in last_lines]

    # update last_log
    shutil.copy(path + curr_log, path + last_log)

    return diff


def watch_log_folder(path):
    event_handler = LogFileChangeHandler()
    observer = Observer()
    observer.schedule(event_handler, path, recursive=False)
    observer.start()

    try:
        while True:
            time.sleep(1)            
    except KeyboardInterrupt:
        observer.stop()
    observer.join()

if __name__ == "__main__":

    if not startDevTunnel:
        print("START_DEV_TUNNEL is False - do not start tunnel-log-watch")
        sys.exit()
        
    curr_log = 'curr.log'
    last_log = 'last.log'

    init_last_log(logWatchPath, last_log)

    diff = ""
    diff = get_diff(logWatchPath, curr_log, last_log)
    if(diff):
        process_diff(diff)

    watch_log_folder(logWatchPath)
