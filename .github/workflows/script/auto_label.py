import requests
import json
import os
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--labels", type=str)
args = parser.parse_args()

issue_number = os.getenv("NUMBER")
TOKEN = os.getenv("TOKEN")


def get_issues_label_list():
    url = 'https://api.github.com/repos/VincyZhang/intel-extension-for-transformers/issues/%s/labels' % issue_number
    headers = {"Accept": "application/vnd.github+json",
               "Authorization": "Bearer %s" % TOKEN,
               "X-GitHub-Api-Version": "2022-11-28"}
    response_raw = requests.get(url, headers=headers)
    response = response_raw.json()
    label_list = response.get()
    return label_list


def add_label_in_list():
    print(args.content)
    content_list = args.content.split(",")
    label_list = get_issues_label_list()
    add_label_list = []
    for content in content_list:
        if content in label_list:
            add_label_list.append(content)
    if add_label_list:
        add_label(add_label_list)


def add_label(label_list: list):
    url = 'https://api.github.com/repos/VincyZhang/intel-extension-for-transformers/issues/%s/labels' % issue_number
    headers = {"Accept": "application/vnd.github+json",
               "Authorization": "Bearer %s" % TOKEN,
               "X-GitHub-Api-Version": "2022-11-28"}
    data = {"labels":label_list}
    response_raw = requests.post(url, headers=headers, data=json.dumps(data))
    
    print(response_raw.json())

if __name__ == '__main__':
    add_label_in_list()
    