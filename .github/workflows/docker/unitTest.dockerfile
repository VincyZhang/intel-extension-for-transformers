#
# Copyright (c) 2022 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
ARG UBUNTU_VER=20.04
FROM ubuntu:${UBUNTU_VER} as devel

# See http://bugs.python.org/issue19846
ENV LANG C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends --fix-missing \
    python3 \
    python3-pip \
    python3-dev \
    python3-distutils \
    autoconf \
    build-essential \
    git \
    libgl1-mesa-glx \
    libglib2.0-0 \
    numactl \
    time \
    wget \
    bc \
    cloc \
    vim

RUN ln -sf $(which python3) /usr/bin/python

RUN python -m pip --no-cache-dir install --upgrade pip
RUN python -m pip install --no-cache-dir setuptools

RUN pip list

WORKDIR /

