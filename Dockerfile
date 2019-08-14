FROM ubuntu:16.04
MAINTAINER jerome.petazzoni@docker.com

# Let's start with some basic stuff.
RUN apt-get update -qq && apt-get install -qqy \
    apt-transport-https \
    ca-certificates \
    openjdk-8-jdk \
    curl \
    gcc \
    libc-dev \
    ruby \
    ruby-dev \
    git \
    libffi-dev \
    make \
    musl-dev \
    lxc \
    iptables \
    tk-dev \
    && rm -rf /var/lib/apt/lists/*

#=================
# JAVA
#================
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64

ENV PATH $JAVA_HOME/bin:$PATH

#================
# PYTHON
#=================
ENV PATH /usr/local/bin:$PATH

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

ENV GPG_KEY 0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D
ENV PYTHON_VERSION 3.6.9

RUN set -ex \
        \
        && wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" \
        && wget -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc" \
        && export GNUPGHOME="$(mktemp -d)" \
        && gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY" \
        && gpg --batch --verify python.tar.xz.asc python.tar.xz \
        && { command -v gpgconf > /dev/null && gpgconf --kill all || :; } \
        && rm -rf "$GNUPGHOME" python.tar.xz.asc \
        && mkdir -p /usr/src/python \
        && tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
        && rm python.tar.xz

RUN cd /usr/local/bin \
        && ln -s idle3 idle \
        && ln -s pydoc3 pydoc \
        && ln -s python3 python \
        && ln -s python3-config python-config

RUN cd /usr/bin \
        && ln -s python3 python

ENV PYTHON_PIP_VERSION 19.1.1

RUN set -ex; \
        \
        wget -O get-pip.py 'https://bootstrap.pypa.io/get-pip.py'; \
        \
        python get-pip.py \
                --disable-pip-version-check \
                --no-cache-dir \
                "pip==$PYTHON_PIP_VERSION" \
        ; \
        rm -f get-pip.py
#================
# Molecule
#================

RUN apt-get update -y \
    && apt-get install -y software-properties-common \
    && add-apt-repository ppa:jonathonf/python-3.6 \
    && apt-get update \
    && apt-get install -y python3-dev

RUN pip install molecule


#================
# Jenkins
#================

# Add user jenkins to the image
RUN adduser --disabled-password jenkins
# Set password for the jenkins user (you may want to alter this).
RUN echo "jenkins:jenkins" | chpasswd \
    && mkdir /home/jenkins/.m2 \
    && chown -R jenkins:jenkins /home/jenkins/.m2/ \
    && echo "jenkins ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
    && echo "alias docker='sudo docker '" >> /home/jenkins/.bashrc \
    && mkdir -p /var/run/sshd \
    && ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa \
    && ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa

EXPOSE 22

#================
# DOCKER
#================

# Install Docker from Docker Inc. repositories.
RUN curl -sSL https://get.docker.com/ | sh
RUN pip install docker-compose
# Install the magic wrapper.
ADD ./wrapdocker /usr/local/bin/wrapdocker
RUN chmod +x /usr/local/bin/wrapdocker
RUN ln -s /usr/local/bin/wrapdocker /usr/bin/wrapdocker
RUN usermod -aG docker jenkins
# Define additional metadata for our image.
VOLUME /var/lib/docker
ENTRYPOINT ["wrapdocker"]
CMD []
