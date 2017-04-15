#!/bin/bash -ex

distro=$(awk -F= '/^ID=/ {print $2}' /etc/*release | tr -d \")

case ${distro} in
    debian|ubuntu)
        apt-get install -y --no-install-recommends \
            ca-certificates \
            curl \
            python
        ;;
    centos)
        :
        ;;
    *)
        echo "Unknown distro: ${distro}"
        exit 1
        ;;
esac

$(dirname $0)/fetch_wheels.py

mkdir /tmp/packages
tar xf /tmp/wheels.tar.gz -C /tmp/packages/ --strip-components=2 root/packages

git init /tmp/${PROJECT}
git --git-dir /tmp/${PROJECT}/.git fetch ${PROJECT_REPO} ${PROJECT_REF}
git --work-tree /tmp/${PROJECT} --git-dir /tmp/${PROJECT}/.git checkout FETCH_HEAD

curl -sSL https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python get-pip.py
rm get-pip.py

pip install --no-cache-dir --no-index --no-compile --find-links /tmp/packages --constraint /tmp/packages/upper-constraints.txt \
        /tmp/${PROJECT} \
        pymysql \
        python-memcached \
        uwsgi

groupadd -g 42424 ${PROJECT}
useradd -u 42424 -g ${PROJECT} -M -d /var/lib/${PROJECT} -s /usr/sbin/nologin -c "${PROJECT} user" ${PROJECT}

mkdir -p /etc/${PROJECT} /var/log/${PROJECT} /var/lib/${PROJECT} /var/cache/${PROJECT}
chown ${PROJECT}:${PROJECT} /etc/${PROJECT} /var/log/${PROJECT} /var/lib/${PROJECT} /var/cache/${PROJECT}

case ${distro} in
    debian|ubuntu)
        apt-get purge -y --auto-remove \
            ca-certificates \
            curl \
            git
        rm -rf /var/lib/apt/lists/*
        ;;
    centos)
        yum -y autoremove git
        yum clean all
        ;;
    *)
        echo "Unknown distro: ${distro}"
        exit 1
        ;;
esac

pip uninstall wheel pip -y
rm -rf /tmp/* /root/.cache
find /usr/ -type f -name "*.pyc" -delete
