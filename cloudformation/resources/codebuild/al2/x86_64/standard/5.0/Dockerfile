
  # checkov:skip=CKV_DOCKER_2: Will be used as CodeBuild base image and not for running containers
FROM public.ecr.aws/amazonlinux/amazonlinux:2023 AS core

# Install git, SSH, and other utilities
RUN set -ex \
    && yum install -y -q openssh-clients \
    && mkdir ~/.ssh \
    && mkdir -p /opt/tools \
    && mkdir -p /codebuild/image/config \
    && touch ~/.ssh/known_hosts \
    && ssh-keyscan -t rsa,dsa,ed25519,ecdsa -H github.com >> ~/.ssh/known_hosts \
    && ssh-keyscan -t rsa,dsa,ed25519,ecdsa -H bitbucket.org >> ~/.ssh/known_hosts \
    && chmod 600 ~/.ssh/known_hosts \
    && rpm --import https://download.mono-project.com/repo/xamarin.gpg \
    && curl https://download.mono-project.com/repo/centos7-stable.repo | tee /etc/yum.repos.d/mono-centos7-stable.repo \
    && yum groupinstall -y -q "Development tools" \
    && yum install -y -q \
    ImageMagick asciidoc bzip2-devel cvs cvsps \
    docbook-dtds docbook-style-xsl e2fsprogs expat-devel expect fakeroot \
    glib2-devel groff gzip icu iptables jq krb5-server libargon2-devel \
    libcurl-devel libdb-devel libedit-devel libevent-devel libffi-devel \
    libicu-devel libjpeg-devel libpng-devel libserf sqlite-devel \
    libtidy-devel libunwind libwebp-devel libxml2-devel libxslt libxslt-devel \
    libyaml-devel libzip-devel mariadb105-devel mercurial mlocate \
    ncurses-devel oniguruma-devel openssl openssl-devel perl perl-FindBin perl-DBD-SQLite \
    perl-DBI perl-HTTP-Date perl-TimeDate perl-YAML-LibYAML \
    procps-ng python-configobj readline-devel rsync sgml-common \
    subversion-perl tar tcl tk vim wget which xfsprogs xmlto xorg-x11-server-Xvfb xz-devel \
    amazon-ecr-credential-helper git-lfs acl \
    && rm /etc/yum.repos.d/mono-centos7-stable.repo

RUN useradd codebuild-user

#=======================End of layer: core  =================

FROM core AS tools

# Install AWS SAM CLI
# RUN wget -nv https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-x86_64.zip -O /tmp/samcli.zip \
#     && unzip -q /tmp/samcli.zip -d /opt \
#     && /opt/install --update -i /usr/local/sam-cli -b /usr/local/bin \
#     && rm /tmp/samcli.zip /opt/install \
#     && rm -rf /opt/aws-sam-cli-src \
#     && sam --version

# Install AWS CLI v2
# https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html
RUN curl https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscliv2.zip \
    && unzip -q /tmp/awscliv2.zip -d /opt \
    && /opt/aws/install --update -i /usr/local/aws-cli -b /usr/local/bin \
    && rm /tmp/awscliv2.zip \
    && rm -rf /opt/aws \
    && aws --version

# Install Git
RUN set -ex \
    && GIT_VERSION=2.45.2 \
    && GIT_TAR_FILE=git-$GIT_VERSION.tar.gz \
    && GIT_SRC=https://github.com/git/git/archive/v${GIT_VERSION}.tar.gz  \
    && curl -L -o $GIT_TAR_FILE $GIT_SRC \
    && tar zxf $GIT_TAR_FILE \
    && cd git-$GIT_VERSION \
    && make -j4 prefix=/usr \
    && make install prefix=/usr \
    && cd .. && rm -rf git-$GIT_VERSION \
    && rm -rf $GIT_TAR_FILE /tmp/*

# Install stunnel
RUN set -ex \
    && STUNNEL_VERSION=5.71 \
    && STUNNEL_TAR=stunnel-$STUNNEL_VERSION.tar.gz \
    && STUNNEL_SHA256="f023aae837c2d32deb920831a5ee1081e11c78a5d57340f8e6f0829f031017f5" \
    && curl -o $STUNNEL_TAR https://www.stunnel.org/archive/5.x/$STUNNEL_TAR && echo "$STUNNEL_SHA256 $STUNNEL_TAR" | sha256sum --check && tar xfz $STUNNEL_TAR \
    && cd stunnel-$STUNNEL_VERSION \
    && ./configure \
    && make -j4 \
    && make install \
    && openssl genrsa -out key.pem 2048 \
    && openssl req -new -x509 -key key.pem -out cert.pem -days 1095 -subj "/C=US/ST=Washington/L=Seattle/O=Amazon/OU=Codebuild/CN=codebuild.amazon.com" \
    && cat key.pem cert.pem >> /usr/local/etc/stunnel/stunnel.pem \
    && cd .. && rm -rf stunnel-${STUNNEL_VERSION}*

# Configure SSM
RUN set -ex \
    && yum install -y -q https://s3.amazonaws.com/amazon-ssm-us-east-1/latest/linux_amd64/amazon-ssm-agent.rpm


# Install gh
# See instruction: https://github.com/cli/cli/blob/trunk/docs/install_linux.md#fedora-centos-red-hat-enterprise-linux-dnf
RUN yum -y install 'dnf-command(config-manager)' \
    && yum config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo \
    && yum -y install gh --repo gh-cli
#=======================End of stage: tools  =================

FROM tools AS runtimes


# #****************      NODEJS     *****************************************************

ENV N_SRC_DIR="$SRC_DIR/n"
ENV NODE_22_VERSION="22.2.0"

RUN git clone https://github.com/tj/n $N_SRC_DIR \
    && cd $N_SRC_DIR && make install

RUN n $NODE_22_VERSION && npm install --save-dev -g -f grunt \
    && npm install --save-dev -g -f grunt-cli \
    && npm install --save-dev -g -f webpack \
    && npm install --save-dev -g -f yarn \
    && n $NODE_20_VERSION && npm install --save-dev -g -f grunt \
    && npm install --save-dev -g -f grunt-cli \
    && npm install --save-dev -g -f webpack \
    && npm install --save-dev -g -f yarn \
    && dnf install -y -v libuv-1.44* \
    && n $NODE_22_VERSION && npm install --save-dev -g -f grunt \
    && npm install --save-dev -g -f grunt-cli \
    && npm install --save-dev -g -f webpack \
    && npm install --save-dev -g -f yarn \
    && cd / && rm -rf $N_SRC_DIR \
    && rm -rf /tmp/* && rm -rf ~/.npm/_logs/
#****************      END NODEJS     **************************************************

#**************** PYTHON ***************************************************************

#Install pyenv
RUN curl -s -S -L https://raw.githubusercontent.com/pyenv/pyenv-installer/master/bin/pyenv-installer | bash
ENV PATH="/root/.pyenv/shims:/root/.pyenv/bin:$PATH"

ENV PYTHON_311_VERSION="3.11.9" \
    PYTHON_312_VERSION="3.12.4" \
    PYTHON_310_VERSION="3.10.14" \
    PYTHON_39_VERSION="3.9.19" \
    PYTHON_PIP_VERSION=24.0 \
    PYYAML_VERSION=5.4.1 \
    PYTHON_CONFIGURE_OPTS="--enable-shared --enable-loadable-sqlite-extensions"

#Python312
RUN set -ex \
    && pyenv install $PYTHON_312_VERSION \
    && pyenv global $PYTHON_312_VERSION \
    && pip3 install --no-cache-dir --upgrade --force-reinstall "pip==$PYTHON_PIP_VERSION" \
    && pip3 install wheel \
    && pip3 install --no-cache-dir --upgrade 'setuptools==67.7.2' boto3 pipenv virtualenv \
    && pip3 install --no-build-isolation "Cython<3" "PyYAML==$PYYAML_VERSION" \
    && pip3 uninstall cython --yes


#**************** END PYTHON *****************************************************

# #======================= End of stage: runtimes  =================

FROM runtimes AS al2_v5

# Activate runtime versions specific to image version.
RUN n $NODE_18_VERSION
RUN pyenv global $PYTHON_312_VERSION

# Configure SSH
COPY ssh_config /root/.ssh/config
COPY runtimes.yml /codebuild/image/config/runtimes.yml
COPY amazon-ssm-agent.json /etc/amazon/ssm/amazon-ssm-agent.json

USER codebuild-user
#=======================End of layer: al2_v5  =================
