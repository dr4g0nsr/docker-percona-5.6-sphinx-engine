#!/bin/bash -e

APT_GET_UPDATE=false

apt_get_update() {
  if [ "$APT_GET_UPDATE" == false ] ; then
    sudo apt-get update
    APT_GET_UPDATE=true
  fi
}

install_package() {
  if [ ! -z "$1" ] && [ $(dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -c "ok installed") -eq 0 ] ; then
     apt_get_update
     sudo apt-get install -y "$1"
  fi
}

usage() {
  echo "You can specify the (sphinx / percona) versions manually or we can automatically detect them."
  echo "---"
  echo "Automatic Usage: $0 -a true"
  echo "---"
  echo "Manual Usage:    $0 -s sphinx-version -p percona-version -d percona-deb-version [-o org-prefix]"
  echo "Manual Example:  $0 -s 2.1.6 -p 5.5.36-34.1 -d 5.5.36-rel34.1-642.wheezy -o my_org" 1>&2;
  exit 1; 
}

# set default prefix for package version
ORG_PREFIX='wheezy'
AUTO_OPTS=false

# get options
while getopts s:p:d:o:a: option
do
  case "${option}"
  in
    a) AUTO_OPTS=${OPTARG};;
    s) SPHINX_VER=${OPTARG};;
    p) PERCONA_VER=${OPTARG};;
    d) PERCONA_DEB_VER=${OPTARG};;
    o) ORG_PREFIX=${OPTARG};;
    *) usage;;
  esac
done

if [ "${AUTO_OPTS}" == true ] ; then

  install_package "apt-show-versions"
  echo "Finding sphinxsearch version."
  SPHINX_VER=$(apt-show-versions | grep sphinxsearch | grep -Po '\d+\.\d+\.\d+')
  if [ -z "$SPHINX_VER" ] ; then
    echo "Error: Unable to auto-detect sphinxsearch version."
    exit 2
  fi
  echo "Finding percona version."
  PERCONA_VER=$(apt-show-versions | grep percona-server | head -n1)
  if [ -z "$PERCONA_VER" ] ; then
    echo "Error: Unable to auto-detect percona version."
    exit 3
  fi
  # 5.5_5.5.35-rel33.0-611.quantal
  # 5.5.36-rel34.1-642.wheezy
  # 5.6_5.6.32-78.0.debian
  # 5.6.19-67.0-618.trusty
  # 5.6.32-78.0-1.xenial
  # 5.6.22-rel71.0-0ubuntu4.1
  PERCONA_DEB_VER=$(echo "$PERCONA_VER" | grep -Po '\d+\.(\d+_)?\d+\.\d+[^\s]+')
  PERCONA_VER=$(echo "$PERCONA_DEB_VER" | grep -oPi '^.+-' | sed -e 's/-$//' | sed -e 's/rel//')
  ORG_PREFIX=$(echo "$PERCONA_DEB_VER" | sed -e 's/rel//' | grep -Poi "[a-z]+[0-9.]*" | grep -oi "[a-z]*")
fi

# Check if options are empty
if [ -z "${SPHINX_VER}" ] || [ -z "${PERCONA_VER}" ] || [ -z "${PERCONA_DEB_VER}" ] ; then
  usage
fi

PERCONA_SHORT_VER=`echo ${PERCONA_VER} | cut -c 1-3`

WORK_DIR="${PWD}"
BUILD_DIR="${WORK_DIR}/_build"
INSTALL_DIR="${WORK_DIR}/_install"
PKG_DIR="${WORK_DIR}/_pkg"
# I know about nproc, but in openvz it fails.
CPU_COUNT=`grep processor /proc/cpuinfo | wc -l`

# configure and build ha_sphinx module
cp -R ${BUILD_DIR}/sphinx-${SPHINX_VER}-release/mysqlse ${BUILD_DIR}/percona-server-${PERCONA_VER}/storage/sphinx
cd ${BUILD_DIR}/percona-server-${PERCONA_VER}
cmake -DCMAKE_INSTALL_PREFIX=/usr/local/mysql \
      -DBUILD_CONFIG=mysql_release \
      -DMYSQL_UNIX_ADDR=/var/run/mysqld/mysqld.sock \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DCMAKE_CXX_FLAGS="-m64 -O3 -felide-constructors -fno-exceptions -fno-rtti" \
      -DWITH_LIBWRAP=ON \
      -DWITH_SSL=bundled \
      -DSYSTEM_TYPE="debian-linux-gnu" \
      -DINSTALL_LAYOUT=DEB \
      -DINSTALL_PLUGINDIR=lib/mysql/plugin \
      -DWITH_EMBEDDED_SERVER=OFF \
      -DWITH_ARCHIVE_STORAGE_ENGINE=ON \
      -DWITH_BLACKHOLE_STORAGE_ENGINE=ON \
      -DWITH_FEDERATED_STORAGE_ENGINE=ON \
      -DWITH_EXTRA_CHARSETS=all
cd ${BUILD_DIR}/percona-server-${PERCONA_VER}/storage/sphinx
# Change default max return size to 256MB over standard 16MB
sed -i 's#16\*1024\*1024#256\*1024\*1024#i' ${BUILD_DIR}/percona-server-${PERCONA_VER}/storage/sphinx/ha_sphinx.cc
make -j${CPU_COUNT}
make install
cd ${BUILD_DIR}/percona-server-${PERCONA_VER}
make -j${CPU_COUNT}
make install