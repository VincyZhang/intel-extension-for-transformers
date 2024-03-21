import requests
import json
import os
import argparse
import logging
import pandas as pd

TOKEN = os.getenv("TOKEN")
NEURALCHAT_SERVER = os.getenv("NEURALCHAT_SERVER")
GITHUB_WORKSPACE = os.getenv("GITHUB_WORKSPACE")

parser = argparse.ArgumentParser()
parser.add_argument("--stage", type=str, required=True)
parser.add_argument("--codeowner", type=str, default=GITHUB_WORKSPACE + "/.github/workflows/script/owner.xlsx")
parser.add_argument("--label", type=str)
args = parser.parse_args()

issue_number = os.getenv("NUMBER")
comment_id = os.getenv("COMMEND_ID")
developers = os.getenv("maintain_list")
developers_list = developers.split(",")
os.environ["no_proxy"] = "intel.com,.intel.com,localhost,127.0.0.1"
os.environ["NO_PROXY"] = "intel.com,.intel.com,localhost,127.0.0.1"
logging.getLogger().setLevel(logging.INFO)

def get_comment_content():
    url = 'https://api.github.com/repos/VincyZhang/intel-extension-for-transformers/issues/comments/%s' % comment_id
    headers = {"Accept": "application/vnd.github+json",
               "Authorization": "Bearer %s" % TOKEN,
               "X-GitHub-Api-Version": "2022-11-28"}
    response_raw = requests.get(url, headers=headers)
    try:
        response = response_raw.json()
        body = response.get("body", "")
        if body:
            logging.info("Get Issue %s Description: %s. END" % (issue_number, body))
        return body
    except:
        logging.error("Get Comment Content Failed")

def get_issues_description():
    url = 'https://api.github.com/repos/VincyZhang/intel-extension-for-transformers/issues/%s' % issue_number
    headers = {"Accept": "application/vnd.github+json",
               "Authorization": "Bearer %s" % TOKEN,
               "X-GitHub-Api-Version": "2022-11-28"}
    response_raw = requests.get(url, headers=headers)
    try:
        response = response_raw.json()
        body = response.get("body", "")
        title = response.get("title", "")
        creator = response.get("user", "").get("login", "")
        if body:
            logging.info("Get Issue %s Description: %s. END" % (issue_number, body))
        if title:
            logging.info("Get Issue %s Title: %s. END" % (issue_number, title))
        if creator:
            logging.info("Get Issue %s Creator: %s. END" % (issue_number, creator))
        return body
    except:
        logging.error("Get Issues Descriptions Failed")
    

def get_issues_comment():
    url = 'https://api.github.com/repos/VincyZhang/intel-extension-for-transformers/issues/%s/comments' % issue_number
    headers = {"Accept": "application/vnd.github+json",
               "Authorization": "Bearer %s" % TOKEN,
               "X-GitHub-Api-Version": "2022-11-28"}
    response_raw = requests.get(url, headers=headers)
    try:
        response = response_raw.json()
        user_content = get_issues_description()
        if not user_content:
            logging.warning("Issues Descriptions Is Empty")
        else:
            user_content = filter_comment(user_content)
        messages = [{"role": "system", "content": "You are a code assistant. Please answer the user's issue accurately. If you cannot answer, please explain politely."},
                    {"role": "user", "content": user_content }]
        for item in response:
            body = item.get("body", "")
            if body == "@NeuralChatBot" or body == "" or not body:
                continue
            else:
                body = filter_comment(body)
            owner = item.get("user", "").get("login", "")
            if owner not in developers_list:
                logging.info("This Comment is From User %s : %s END" % (owner, body))
                messages.append({"role": "user", "content": body })
            elif owner == "NeuralChat":
                logging.info("This Comment is From NeuralChat: %s END" % body)
                messages.append({"role": "assistant", "content": body })
            else:
                logging.info("This Comment is From Developer %s : %s END" % (owner, body))
                messages.append({"role": "assistant", "content": body })
        logging.info("Final Messages is: %s " % str(messages))
        return messages
    except:
        logging.error("Get Issues Comment Failed")
    

def filter_comment(user_content: str):
    comment_list = ["If you need help, please @NeuralChatBot",
                    "@NeuralChatBot"]
    for comment in comment_list:
        user_content = user_content.replace(comment, "")
    return user_content

def request_neuralchat_bot(user_content: str, url_post: str):
    url = 'http://%s:8000/v1/chat/%s' % (NEURALCHAT_SERVER, url_post)
    headers = {'Content-Type': 'application/json'}
    messages = [{"role": "system", "content": "You are a code assistant. Please answer the user's issue accurately. If you cannot answer, please explain politely."}, 
                {"role": "user", "content": user_content}]
    data = {"model": "deepseek-ai/deepseek-coder-6.7b-instruct", 
            "messages": messages
            }
    logging.info("Request NeuralChat Bot The First Time: %s" % json.dumps(data))
    try:
        response_raw = requests.post(url, headers=headers, data=json.dumps(data))
        response = response_raw.json()
        if url_post == "auto-reply":
            output = response.get("choices", "")
            if len(output) <= 0:
                logging.error("Get NeuralChatBot Response Failed with Empty Choice")
                return
            output = output[0].get("message", "").get("content", "")
            if not output:
                logging.error("Get Empty NeuralChatBot Response")
            else:
                logging.info("Get NeuralChatBot Response: %s" % output)
                return output
        elif url_post == "auto-assign":
            output = response.get("owner", "")
            if not output:
                logging.error("Get NeuralChatBot Response Failed with Empty Choice")
                return
            logging.info("Get NeuralChatBot Assignee: %s" % output)
            return output
    except:
        logging.error("Request NeuralChatBot Failed")


def request_neuralchat_bot_with_history(messages: list, url_post: str):
    url = 'http://%s:8000/v1/chat/%s' % (NEURALCHAT_SERVER, url_post)
    headers = {'Content-Type': 'application/json'}
    data = {"model": "deepseek-ai/deepseek-coder-6.7b-instruct",
            "messages": messages
            }
    logging.info("Request NeuralChat Bot with Context History: %s" % json.dumps(data))
    try:
        response_raw = requests.post(url, headers=headers, data=json.dumps(data))
        response = response_raw.json()
        output = response.get("choices", "")
        if len(output) <= 0:
            logging.error("Get NeuralChatBot Response Failed with Empty Choice")
            return
        output = output[0].get("message", "").get("content", "")
        if not output:
            logging.error("Get Empty NeuralChatBot Response")
            return
        else:
            logging.info("Get NeuralChatBot Response with Context History: %s" % output)
        return output
    except:
        logging.error("Request NeuralChatBot with Context History Failed")

def update_comment(resp: str):
    url = 'https://api.github.com/repos/VincyZhang/intel-extension-for-transformers/issues/%s/comments' % issue_number
    headers = {"Accept": "application/vnd.github+json",
               "Authorization": "Bearer %s" % TOKEN,
               "X-GitHub-Api-Version": "2022-11-28"}
    data = {"body": resp}
    logging.info("Update Comment for Issue %s with %s" % (issue_number, json.dumps(data)))
    try:
        response_raw = requests.post(url, headers=headers, data=json.dumps(data))
        logging.info(response_raw.json())
    except:
        logging.error("Update Comment for Issue %s Failed" % issue_number)

def get_repo_label():
    url = 'https://api.github.com/repos/VincyZhang/intel-extension-for-transformers/labels'
    headers = {"Accept": "application/vnd.github+json",
               "Authorization": "Bearer %s" % TOKEN,
               "X-GitHub-Api-Version": "2022-11-28"}
    response_raw = requests.get(url, headers=headers)
    response = response_raw.json()
    label_list = []
    for label_content in response:
        try:
            label_name = label_content.get("name")
            label_list.append(label_name)
        except:
            logging.error("Get Label Lists Failed")
    return label_list

def get_issue_label():
    url = 'https://api.github.com/repos/VincyZhang/intel-extension-for-transformers/issues/%s/labels' % issue_number
    headers = {"Accept": "application/vnd.github+json",
               "Authorization": "Bearer %s" % TOKEN,
               "X-GitHub-Api-Version": "2022-11-28"}
    response_raw = requests.get(url, headers=headers)
    response = response_raw.json()
    label_list = []
    for label_content in response:
        try:
            label_name = label_content.get("name")
            label_list.append(label_name)
        except:
            logging.error("Get Label Lists Failed")
    return label_list

def check_if_owner_assinable(owner: str):
    url = 'https://api.github.com/repos/VincyZhang/intel-extension-for-transformers/assignees/%s' % owner
    headers = {"Accept": "application/vnd.github+json",
               "Authorization": "Bearer %s" % TOKEN,
               "X-GitHub-Api-Version": "2022-11-28"}
    response_raw = requests.get(url, headers=headers)
    logging.info(response_raw)
    if response_raw == "204":
        return True
    return False

def assign_owner(owner: str):
    if not check_if_owner_assinable(owner):
        owner = "VincyZhang"
    url = 'https://api.github.com/repos/VincyZhang/intel-extension-for-transformers/issues/%s/assignees' % issue_number
    headers = {"Accept": "application/vnd.github+json",
                "Authorization": "Bearer %s" % TOKEN,
                "X-GitHub-Api-Version": "2022-11-28"}
    data = {"assignees": [owner]}
    try:
        response_raw = requests.post(url, headers=headers, data=json.dumps(data))
        logging.info(response_raw.json())
    except:
        logging.error("Assign %s for Issue %s Failed" % (owner, issue_number))
    
def request_for_auto_reply():
    content = get_issues_description()
    if not content:
        logging.error("Get Issues Descriptions Failed")
        exit(1)
    output = request_neuralchat_bot(content, "auto-reply")
    if not output:
        logging.error("Request NeuralChatBot Failed")
        exit(1)
    output += "\nIf you need help, please @NeuralChatBot"
    update_comment(output)

def request_for_auto_assign():
    content = get_issues_description()
    if not content:
        logging.error("Get Issues Descriptions Failed")
        exit(1)
    #if not os.path.exists(args.codeowner):
    #    logging.error("code owner list not exiest, please provide the correct file path. Current input is %s" % args.codeowner)
    #df = pd.read_excel(args.codeowner)
    #logging.info("read from owner list: ")
    #logging.info(df)
    #logging.info(type(df))
    output = request_neuralchat_bot(content, "auto-assign")
    logging.info("assign to %s" % output)
    if not output:
        logging.error("Request NeuralChatBot Failed")
        exit(1)
    assign_owner(output)

def request_for_auto_reply_with_history():
    messages = get_issues_comment()
    if not messages:
        logging.error("Get Issues Comments Failed")
        exit(1)
    output = request_neuralchat_bot_with_history(messages, "auto-reply")
    if not output:
        logging.error("Request NeuralChatBot with Context History Failed")
        exit(1)
    update_comment(output)

if __name__ == '__main__':
    if args.stage == "create":
        labels = get_issue_label()
        if "bug" in labels or "feature" in labels:
            logging.info("request_for_auto_assign")
            request_for_auto_assign()
        elif "questions" in labels or "environmental error" in labels:
            logging.info("request_for_auto_reply")
            request_for_auto_reply()
        
    elif args.stage == "update":
        content = get_comment_content()
        if "@NeuralChatBot" not in content:
            logging.info("User Not Asking Help from NeuralChatBot, Skip")
            exit(0)
        logging.info("request_for_auto_reply_with_history")
        request_for_auto_reply_with_history()

    elif args.stage == "label":
        new_label = args.label
        if new_label == "bug" or new_label == "feature":
            logging.info("request_for_auto_assign")
            request_for_auto_assign()
        elif new_label == "questions" or new_label == "environmental error":
            logging.info("request_for_auto_reply")
            request_for_auto_reply()
        
