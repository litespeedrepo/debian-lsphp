#!/bin/bash
target_server='repo-dev.litespeedtech.com'
prod_server='rpms.litespeedtech.com'
source ./functions.sh #2>/dev/null
echo " Check if the user is root "
if [ $(id -u) != "0" ]; then
    echo "Error: The user is not root "
    echo "Please run this script as root"
    exit 1
fi
PHP_V=84
product=$1
dists=$2
input_archs=$3
#build_flag=$4
#release_flag=$5

if [ -z "${version}" ]; then
    version="$(grep ${product}= VERSION.txt | awk -F '=' '{print $2}')"
fi  

if [ "${product}" == 'lsphp' ]; then
    product="${product}"${PHP_V}
else
    product=lsphp${PHP_V}-"${product}"
fi

lsapi_version=8.1
if [ $dists = "all" ]; then
        echo " convert dists value "
            dists="noble jammy focal bookworm bullseye buster"
        echo " the new value for dists is $dists "
fi

if [ -z "${revision}" ]; then
    TMP_DIST=$(echo $dists | awk '{ print $1 }') ### Check first dist and use it as the revision number
    echo ${product} | grep '-' >/dev/null
    if [ $? = 1 ]; then 
        revision=$(curl -isk https://${prod_server}/debian/pool/main/$TMP_DIST/ | grep ${product}_${version} \
          | awk -F '-' '{print $3}' | awk -F '+' '{print $1}' | tail -1)
    else
        revision=$(curl -isk https://${prod_server}/debian/pool/main/$TMP_DIST/ | grep ${product}_${version} \
          | awk -F '-' '{print $4}' | awk -F '+' '{print $1}' | tail -1)      
    fi      
    if [[ $revision == ?(-)+([[:digit:]]) ]]; then
        revision=$((revision+1))
    else
        echo "$revision is not a number, set value to 1"
        revision=1
    fi      
fi

archs=$input_archs

check_input
set_paras
set_build_dir
prepare_source
pbuild_packages
echo "##################################################"
echo " The package building process has finished ! "
echo "##################################################"
echo "########### Build Result Content #################"

for dist in $dists; do
    ls -lR $BUILD_RESULT_DIR/$dist;
done

echo " ################# End of Result #################"

for dist in $dists; do
    ls -lR $BUILD_RESULT_DIR/$dist | grep ${product}_${version}-${revision}+${dist}_.*.deb >/dev/null
    if [ ${?} != 0 ] ; then
        echo "${product}_${version}-${revision}+${dist}_.*.deb is not found!"
        exit 1   
    fi
done

upload_to_server

echo $(date)