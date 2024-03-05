import requests
import json
import os
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--stage", type=str, required=True)
args = parser.parse_args()

issue_number = os.getenv("NUMBER")
TOKEN = os.getenv("TOKEN")
os.environ["no_proxy"] = "intel.com,.intel.com,localhost,127.0.0.1"
os.environ["NO_PROXY"] = "intel.com,.intel.com,localhost,127.0.0.1"

def get_issues_description():
    url = 'https://api.github.com/repos/VincyZhang/intel-extension-for-transformers/issues/%s' % issue_number
    headers = {"Accept": "application/vnd.github+json",
               "Authorization": "Bearer %s" % TOKEN,
               "X-GitHub-Api-Version": "2022-11-28"}
    response_raw = requests.post(url, headers=headers)
    response = response_raw.json()
    body = response.get("body")
    title = response.get("title")
    creator = response.get("user").get("login")
    print(body)
    print(title)
    print(creator)
    return body

def get_issues_comment():
    url = 'https://api.github.com/repos/VincyZhang/intel-extension-for-transformers/issues/%s/comments' % issue_number
    headers = {"Accept": "application/vnd.github+json",
               "Authorization": "Bearer %s" % TOKEN,
               "X-GitHub-Api-Version": "2022-11-28"}
    response_raw = requests.get(url, headers=headers)
    response = response_raw.json()
    user_content = get_issues_description()
    user_content = user_content.replace("If you need help, please @NeuralChatBot", "")
    messages = [{"role": "system", "content": "You are a helpful assistant."},
                {"role": "user", "content": user_content }]
    for item in response:
        body = item.get("body")
        body = body.replace("If you need help, please @NeuralChatBot", "")
        if body == "@NeuralChatBot" or body == "" or not body:
            continue
        else:
            body = body.replace("@NeuralChatBot", "")
        owner = item.get("user").get("login")
        if owner in ["VincyZhang"] and ("NeuralChatBot" in body):
            print(body)
            user_content += body
            messages.append({"role": "user", "content": body })
        elif owner in ["NeuralChatBot", "VincyZhang"]:
            print(body)
            messages.append({"role": "assistant", "content": body })
        else:
            print(body)
            messages.append({"role": "assistant", "content": body })
    print(user_content)
    print(messages)
    return messages


def request_neuralchat_bot(user_content: str):
    url = 'http://127.0.0.1:8000/v1/chat/completions'
    headers = {'Content-Type': 'application/json'}
    data = {"model": "Intel/neural-chat-7b-v3-1", "messages": [
              {"role": "system", "content": "You are a helpful assistant."},
              {"role": "user", "content": user_content}]}
    response_raw = requests.post(url, headers=headers, data=json.dumps(data))
    response = response_raw.json()
    output = response.get("choices")
    if len(output) <= 0:
        print("get response failed")
        return
    output = output[0].get("message").get("content")
    print(output)
    return output


def request_neuralchat_bot_with_history(messages: list):
    url = 'http://127.0.0.1:8000/v1/chat/completions'
    headers = {'Content-Type': 'application/json'}
    data = {"model": "Intel/neural-chat-7b-v3-1",
            "messages": messages
            }
    print(json.dumps(data))
    response_raw = requests.post(url, headers=headers, data=json.dumps(data))
    response = response_raw.json()
    output = response.get("choices")
    if len(output) <= 0:
        print("get response failed")
        return
    output = output[0].get("message").get("content")
    print(output)
    return output

def update_comment(resp: str):
    url = 'https://api.github.com/repos/VincyZhang/intel-extension-for-transformers/issues/%s/comments' % issue_number
    headers = {"Accept": "application/vnd.github+json",
               "Authorization": "Bearer %s" % TOKEN,
               "X-GitHub-Api-Version": "2022-11-28"}
    data = {"body": resp}
    response_raw = requests.post(url, headers=headers, data=json.dumps(data))
    
    print(response_raw.json())

if __name__ == '__main__':
    if args.stage == "create":
        content = get_issues_description()
        output = request_neuralchat_bot(content)
        output += "\nIf you need help, please @NeuralChatBot"
        print(output)
        update_comment(output)
    elif args.stage == "comment":
        messages = get_issues_comment()
        output = request_neuralchat_bot_with_history(messages)
        print(output)
        update_comment(output)