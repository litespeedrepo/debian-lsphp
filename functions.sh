#!/bin/bash
#set -x
#set -v
#source ~/.bashrc
cur_path=$(pwd)

check_input(){
    echo " ###########   Check_input  ############# "
    echo " Product name is $product "
    echo " Version number is $version "
    echo " Build revision is $revision "
    echo " Required archs are $archs "
    echo " Required dists are $dists "
}

set_paras(){
    PHP_EXTENSION=$(echo "${product}" | sed 's/^[^-]*-//g')
    if [[ "${PHP_EXTENSION}" =~ 'lsphp' ]]; then
        PHP_EXTENSION=''
    fi
    PHP_VERSION_NUMBER=$(echo "${product}" | sed 's/[^0-9]*//g')
    if [[ "$product" =~ 'lsphp' ]] && [[ "${PHP_EXTENSION}" != '' ]] && ! [[ "${PHP_EXTENSION}" =~ 'lsphp' ]] ; then
        if [[ "${PHP_VERSION_NUMBER}" -lt '74' ]]; then
            echo "PHP extensions are just for 7.4+"
            exit 1
        fi
        PRODUCT_DIR=${cur_path}/build/"${PHP_EXTENSION}"
        BUILD_DIR=$PRODUCT_DIR/"lsphp${PHP_VERSION_NUMBER}-$version-$revision"
    else
        PRODUCT_DIR=${cur_path}/build/$product
        BUILD_DIR=$PRODUCT_DIR/"$version-$revision"
    fi
    BUILD_RESULT_DIR=$BUILD_DIR/build-result
}

set_build_dir(){
    if [ ! -d "$BUILD_DIR" ]; then
        mkdir -p $BUILD_DIR
        mkdir -p $BUILD_DIR/build-result
    else
        echo " find build directory exists "
        clear_or_not=n
        read -p "do you want to clear it before continuing? y/n:  " -t 15 clear_or_not
        if [ x$clear_or_not == xy ]; then
            echo " now clean the build directory "
            rm -rf $BUILD_DIR/*
            echo " build directory cleared "
        else
            echo " the build directory will not be completely cleared "
            echo " the existing build-result folder will be kept "
            echo " only related files will be overwritten "
            echo " but the source will be downloaded again "
            cd $BUILD_DIR/
            rm -rf `ls $BUILD_DIR | grep -v build-result`
        fi
    fi
    for dist in $dists; do
        mkdir -p $BUILD_DIR/build-result/$dist
    done
}


prepare_source(){
    cd $BUILD_DIR
    case "$product" in
    lsphp84)
        source_url="http://us2.php.net/distributions/php-$version.tar.gz"
        wget $source_url
        tar xzf php-$version.tar.gz

        source_folder_name=php8.4-$version
        mv php-$version $source_folder_name

        SOURCE_DIR=$BUILD_DIR/$source_folder_name
        source_url=https://www.litespeedtech.com/packages/lsapi/php-litespeed-${lsapi_version}.tgz
        wget ${source_url}
        tar -xzf php-litespeed-${lsapi_version}.tgz
        cp -af litespeed-${lsapi_version}/*.c litespeed-${lsapi_version}/*.h  ${SOURCE_DIR}/sapi/litespeed/

        # add patches folder to the source
        cp -a ${PRODUCT_DIR}/patches ${SOURCE_DIR}/
        ls -la $SOURCE_DIR/patches

        # apply patches only once and then remove patches folder
        cd $SOURCE_DIR
        echo `pwd`
        echo "now applying the patches"
        quilt push -a --trace
        rm -rf patches .pc

        cd ..
        #prepare the patched source as orig.tar.xz file
        tar -cJf php8.4_${version}.orig.tar.xz ${source_folder_name}
        ;;
    lsphp${PHP_VERSION_NUMBER}-${PHP_EXTENSION})
        if [ ${PHP_EXTENSION} == 'ioncube' ] ; then
            #source_url='https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz'
            if [[ ${archs} == 'arm64' ]] ; then
                source_url="http://downloads2.ioncube.com/loader_downloads/ioncube_loaders_lin_aarch64_${version}.tar.gz"
            else
                source_url="http://downloads2.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64_${version}.tar.gz"
            fi
            wget ${source_url}
            tar -xzf ioncube_loaders_lin_*_${version}.tar.gz
            source_folder_name="ioncube"
        elif [ ${PHP_EXTENSION} == 'pear' ] ; then
            source_url="http://download.pear.php.net/package/PEAR-${version}.tgz"
            wget --quiet ${source_url}
            tar -xzf "PEAR-${version}.tgz"
            mv package.xml "PEAR-${version}/package2.xml"
            rm -f package.sig
            mkdir -p "PEAR-${version}/submodules"

            XML_UTIL_VER='1.4.5'
            STRUCTURES_GRAPH_VER='1.1.1'
            CONSOLE_GETOPT_VER='1.4.3'
            ARCHIVE_TAR_VER='1.4.14'
            PEAR_MANPAGES_VER='1.10.0'
            SUB_MODULES=('XML_Util' 'Structures_Graph' 'Console_Getopt' 'Archive_Tar' 'PEAR_Manpages')
            for SUB_MODULE in ${SUB_MODULES[@]}; do
                if [[ ${SUB_MODULE} == 'XML_Util' ]]; then
                    PEAR_SUB_VERSION="${XML_UTIL_VER}"
                elif [[ ${SUB_MODULE} == 'Structures_Graph' ]]; then
                    PEAR_SUB_VERSION="${STRUCTURES_GRAPH_VER}"
                elif [[ ${SUB_MODULE} == 'Console_Getopt' ]]; then
                    PEAR_SUB_VERSION="${CONSOLE_GETOPT_VER}"
                elif [[ ${SUB_MODULE} == 'Archive_Tar' ]]; then
                    PEAR_SUB_VERSION="${ARCHIVE_TAR_VER}"
                elif [[ ${SUB_MODULE} == 'PEAR_Manpages' ]]; then
                    PEAR_SUB_VERSION="${PEAR_MANPAGES_VER}"
                fi
                wget --quiet http://download.pear.php.net/package/${SUB_MODULE}-${PEAR_SUB_VERSION}.tgz
                tar -xf "${SUB_MODULE}-${PEAR_SUB_VERSION}.tgz"
                if [[ ${SUB_MODULE} == 'PEAR_Manpages' ]]; then
                    mv "${SUB_MODULE}-${PEAR_SUB_VERSION}/man5" "PEAR-${version}/"
                    mv "${SUB_MODULE}-${PEAR_SUB_VERSION}/man1" "PEAR-${version}/"
                    mv package.xml "PEAR-${version}/package-manpages.xml"
                    rm -rf "${SUB_MODULE}-${PEAR_SUB_VERSION}"
                else
                    mv "${SUB_MODULE}-${PEAR_SUB_VERSION}/" "PEAR-${version}/submodules/${SUB_MODULE}/"
                    mv package.xml "PEAR-${version}/submodules/${SUB_MODULE}/"
                fi
                if [[ -f package.sig ]]; then
                    rm package.sig
                fi
                rm -f "${SUB_MODULE}-${PEAR_SUB_VERSION}.tgz"
            done
            cp "PEAR-${version}/package2.xml" package2.xml
            cp "PEAR-${version}/package2.xml" package.xml
            source_folder_name="PEAR-${version}"
        elif [ ${PHP_EXTENSION} == 'imagick-git' ] ; then
            source_url="https://github.com/Imagick/imagick/archive/refs/heads/master.tar.gz"
            wget ${source_url}
            tar -xzf "master.tar.gz"
            mv imagick-master "${PHP_EXTENSION}-${version}"
            source_folder_name="${PHP_EXTENSION}-${version}"
        elif [ ${PHP_EXTENSION} == 'memcached-git' ] ; then
            source_url="https://github.com/php-memcached-dev/php-memcached/archive/refs/heads/master.tar.gz"
            wget --no-check-certificate ${source_url}
            tar -xzf "master.tar.gz"
            mv php-memcached-master "${PHP_EXTENSION}-${version}"
            source_folder_name="${PHP_EXTENSION}-${version}"
        elif [ ${PHP_EXTENSION} == 'msgpack' ] ; then
            source_url="https://pecl.php.net/get/${PHP_EXTENSION}-${version}.tgz"
            wget ${source_url}
            tar -xzf "${PHP_EXTENSION}-${version}.tgz"
            source_folder_name="${PHP_EXTENSION}-${version}"
        else
            source_url="https://pecl.php.net/get/${PHP_EXTENSION}-${version}.tgz"
            wget ${source_url}
            tar -xzf "${PHP_EXTENSION}-${version}.tgz"
            source_folder_name="${PHP_EXTENSION}-${version}"
        fi
            SOURCE_DIR="${BUILD_DIR}/${source_folder_name}"
            tar -cJf ${product}_${version}.orig.tar.xz ${source_folder_name}
        ;;    
    *)
        echo "Currently this product is not supported"
        ;;
  esac
  echo " source folder name is $source_folder_name "
}

pbuild_packages(){
    echo " now building packages "
    cd $SOURCE_DIR
    for arch in `echo $archs`; do
        for dist in `echo $dists`; do
          TAIL_EDGE=''
          if [ -d ${SOURCE_DIR}/debian ] ; then
              rm -rf ${SOURCE_DIR}/debian
          fi
          # Autoswitch the php info for php extensions before compiling
          if [[ "${product}" =~ 'lsphp' ]] && [[ "${PHP_EXTENSION}" != '' ]]; then
              PHP_VERSION_DOT="${PHP_VERSION_NUMBER:0:1}.${PHP_VERSION_NUMBER:1:1}"         
              if [[ "${PHP_VERSION_NUMBER}" == '74' ]]; then
                  PHP_VERSION_DATE='20190902'
              elif [[ "${PHP_VERSION_NUMBER}" == '80' ]]; then
                  PHP_VERSION_DATE='20200930'
              elif [[ "${PHP_VERSION_NUMBER}" == '81' ]]; then
                  PHP_VERSION_DATE='20210902'
              elif [[ "${PHP_VERSION_NUMBER}" == '82' ]]; then
                  PHP_VERSION_DATE='20220829'
              elif [[ "${PHP_VERSION_NUMBER}" == '83' ]]; then
                  PHP_VERSION_DATE='20230831'                  
              elif [[ "${PHP_VERSION_NUMBER}" == '84' ]]; then
                  PHP_VERSION_DATE='20240924'                  
              fi
          fi          
          cp -a ${PRODUCT_DIR}${TAIL_EDGE}/debian $SOURCE_DIR/
          echo " copy changelog template to debian folder "
          cp -af ${PRODUCT_DIR}${TAIL_EDGE}/debian/changelog $SOURCE_DIR/debian/changelog
          echo " now substitute variables in changelog "
          sed -i -e "s/#VERSION#/${version}/g" $SOURCE_DIR/debian/changelog
          sed -i -e "s/#BUILD_REVISION#/${revision}/g" $SOURCE_DIR/debian/changelog
          sed -i -e "s/#DIST#/${dist}/g" $SOURCE_DIR/debian/changelog
          sed -i -e "s/#DATE#/`date +"%a, %d %b %Y %T"`/g" $SOURCE_DIR/debian/changelog
          sed -i -e "s/#PHP_VERSION#/${PHP_VERSION_NUMBER}/g" $SOURCE_DIR/debian/changelog
          echo " changelog preparation done "

          export DISTRO_TEST=${distro}
          DIST=${dist} ARCH=${arch} pbuilder --update
          pdebuild --debbuildopts -j8 --architecture ${arch} --buildresult ../build-result/${dist} --pbuilderroot "sudo DIST=${dist} ARCH=${arch}" -- --hookdir $HOME
        done
    done
}

upload_to_server(){
    cd $BUILD_DIR/build-result
    REP_LOC='/var/www/html'
    for dist in `echo $dists`; do
        echo "Uploading pkg to dev - distribution ${dist}"
        eval `ssh-agent -s`
        echo "${BUILD_KEY}" | ssh-add - > /dev/null 2>&1
        scp -oStrictHostKeyChecking=no $BUILD_DIR/build-result/${dist}/*.deb root@${target_server}:${REP_LOC}/debian/pool/main/${dist}/ #>/dev/null 2>&1
    done
}

#sign_release(){
#    for dist in `echo $dists`; do
#        echo "Sign Release for distribution ${dist}"
#        ssh -oStrictHostKeyChecking=no root@rpms.litespeedtech.com -t "/var/www/gen_pkg_release.sh ${build_flag} ${dist}"
#    done
#}