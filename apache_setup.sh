#!/usr/bin/env bash


################################################################################
###                             APACHE SETUP SCRIPT                          ###
### author          :jstauffer                                               ###
### date            :2017:05:12                                              ###
################################################################################


##############################
#          VARIABLES         #
##############################

# Basis for installation.. Recommended that environment is built in /usr/local/
DESTINATION="/usr/local/"

# Initial download location for all retrieved files
DOWNLOADS_PATH="${HOME}/Downloads/"

# Addresses for downloads
APACHE_DOWNLOAD="http://apache.mirrors.tds.net//httpd/httpd-2.4.29.tar.bz2"
TOMCAT_DOWNLOAD="http://download.nextag.com/apache/tomcat/tomcat-8/v8.5.27/bin/apache-tomcat-8.5.27.tar.gz"
APACHE_PORTABLE_RUNTIME_DOWNLOAD="http://mirrors.gigenet.com/apache//apr/apr-1.6.3.tar.gz"
APACHE_PORTABLE_RUNTIME_UTIL_DOWNLOAD="http://apache.mirrors.tds.net//apr/apr-util-1.6.1.tar.gz"
OPENSSL_DOWNLOAD="https://www.openssl.org/source/openssl-1.0.2m.tar.gz"
MOD_JK_DOWNLOAD="http://mirror.cc.columbia.edu/pub/software/apache/tomcat/tomcat-connectors/jk/tomcat-connectors-1.2.42-src.tar.gz"

# Directory names for installations (Should match name of downloaded file except for file type)
APACHE_NAME="httpd-2.4.29"
APACHE2_NAME="apache2"
TOMCAT_NAME="apache-tomcat-8.5.27"
OPENSSL_NAME="openssl-1.0.2m"
MOD_JK_NAME="tomcat-connectors-1.2.42-src"
APR_NAME="apr-1.6.3"
APR_UTIL_NAME="apr-util-1.6.1"

# Where installations will live. should be built dynamically given the above variables
APACHE_HOME=$DESTINATION$APACHE_NAME
APACHE2_HOME=$DESTINATION$APACHE2_NAME
TOMCAT_HOME=$DESTINATION$TOMCAT_NAME
SSL_HOME=$DESTINATION"openssl"

# Codes for colored logging output
ERROR_RED='\e[38;5;88m'
INFO_BLUE='\e[94m'
NC='\033[0m' # No Color


##############################
#          FUNCTIONS         #
##############################

install_tomcat() {
    # Check if tomcat has already been downloaded
    if [ ! -f "${DOWNLOADS_PATH}${TOMCAT_NAME}.tar.gz" ]; then
        info "Downloading Tomcat"
        # Downloading tomcat from apache site
        wget -A.tar.gz ${TOMCAT_DOWNLOAD} -O "${DOWNLOADS_PATH}${TOMCAT_NAME}.tar.gz"
    fi
    # Check if tomcat has already been installed
    if [ ! -d ${TOMCAT_HOME} ]; then
        info "Installing Tomcat"
        # Extracting tomcat to final destination
        sudo tar -xvzf "${DOWNLOADS_PATH}${TOMCAT_NAME}.tar.gz" -C $DESTINATION
        # Remove old tomcat library if it exists
        sudo rm -rf /Library/Tomcat
        # Make symbolic link for tomcat library
        sudo ln -s /usr/local/${TOMCAT_NAME} /Library/Tomcat
        # Make user the owner of the tomcat library
        sudo chown -R $USER /Library/Tomcat
        # Make user the owner of the tomcat home directory
        sudo chown -R $USER $DESTINATION/$TOMCAT_NAME
        # Make tomcat executable
        sudo chmod +x /Library/Tomcat/bin/*.sh
        # Copy configuration files into tomcat
        cp $HOME/resources/tomcat_conf/context.xml ${TOMCAT_HOME}/conf/context.xml
        cp $HOME/resources/tomcat_conf/setenv.sh ${TOMCAT_HOME}/bin/setenv.sh
    fi
    info "Tomcat installation complete"
}

install_apr() {
    # Check if apr has already been installed
    if [ -d ${APACHE_HOME} ]; then
        info "Installing the Apache portable runtime"
        # Download apr from apache site
        wget -A.tar.bz2 ${APACHE_PORTABLE_RUNTIME_DOWNLOAD} -O "${DOWNLOADS_PATH}${APR_NAME}.tar.bz2"
        # Download apr-util from apache site
        wget -A.tar.bz2 ${APACHE_PORTABLE_RUNTIME_UTIL_DOWNLOAD} -O "${DOWNLOADS_PATH}${APR_UTIL_NAME}.tar.bz2"
        # Extract apr and apr-util into apache srclib
        tar -xjf "${DOWNLOADS_PATH}${APR_NAME}.tar.bz2" -C ${APACHE_HOME}/srclib/
        tar -xjf "${DOWNLOADS_PATH}${APR_UTIL_NAME}.tar.bz2" -C ${APACHE_HOME}/srclib/
        # Apache won't recognize apr and apr-util unless versions are stripped from the directory names
        mv ${APACHE_HOME}/srclib/${APR_NAME} ${APACHE_HOME}/srclib/apr
        mv ${APACHE_HOME}/srclib/${APR_UTIL_NAME} ${APACHE_HOME}/srclib/apr-util
        info "Completed installing apache portable runtime"
	    return 0
    else
        err "Apache must be installed before apr can be installed"
	    return 1
    fi
}

install_mod_jk() {
    info "Building Tomcat connectors"
    # Check if modjk has already been downloaded
    if [ ! -f "${DOWNLOADS_PATH}${MOD_JK_NAME}.tar.gz" ]; then
        # Downloading modjk from apache site and storing in downloads
        wget -A.tar.gz ${MOD_JK_DOWNLOAD} -O "${DOWNLOADS_PATH}${MOD_JK_NAME}.tar.gz"
    fi
    # extracting
    tar -xvzf "${DOWNLOADS_PATH}${MOD_JK_NAME}.tar.gz" -C ${DOWNLOADS_PATH}
    # Configure modjk
    (cd ${DOWNLOADS_PATH}${MOD_JK_NAME}/native; \
        sudo ./configure --with-apxs=/usr/local/apache2/bin/apxs; \
        sudo make; \
        sudo cp apache-2.0/mod_jk.so /usr/local/apache2/modules/)
}

install_apache() {
    info "Installing apache"
    # Don't download apache tar if it has already been downloaded'
    if [ ! -f "${DOWNLOADS_PATH}${APACHE_NAME}.tar.bz2" ]; then
        info "Downloading apache"
        # Download httpd from apache website and put in downloads folder
        wget -A.tar.bz2 ${APACHE_DOWNLOAD} -O "${DOWNLOADS_PATH}${APACHE_NAME}.tar.bz2"
    fi
    # Check if apache has already been built
    if [ ! -d ${APACHE_HOME} ]; then
        info "Extracting apache to ${APACHE_HOME}"
        # Make home directory for httpd
        sudo mkdir -p ${APACHE_HOME}
        # Make user own apache home directory
        sudo chown $USER ${APACHE_HOME}
        # Extract apache tar to new apache home directory
        tar -xjf "${DOWNLOADS_PATH}${APACHE_NAME}.tar.bz2" -C ${APACHE_HOME}
        # after extracting there are two http directories so easiest thing to do is to move
        # everything thing down one dir and then get rid of the nested httpd directory so that
        # owner is preserved rather than just extracting httpd straight to /usr/local/
        cp -rf ${APACHE_HOME}/${APACHE_NAME}/* ${APACHE_HOME} && rm -rf ${APACHE_HOME}${APACHE_NAME}
    fi
    (install_apr; install_ssl)
    (configure_pcre)
    if [ ! -d ${APACHE2_HOME} ]; then
        (cd ${APACHE_HOME}; \
            sudo ${APACHE_HOME}/configure \
                --prefix=/usr/local/apache2 \
                --with-pcre=/usr/local/pcre/ \
                --with-included-apr \
                --with-ssl=/usr/local/openssl \
                --enable-ssl \
                --enable-so \
                --enable-deflate)
        sudo make -C ${APACHE_HOME}
        sudo make install -C ${APACHE_HOME}
    fi
	if [ -d ${APACHE2_HOME} ] ; then
        configure_apache
	else
		err "==============================================="
		err "Could not complete due to prerequisite failures"
		err "==============================================="
		return 1
	fi
}

install_ssl() {
    info "Installing openssl"
    # Check if openssl is already installed
    if [ ! -d ${SSL_HOME} ]; then
        # Download openssl tar from openssl mirror
	    wget -A.tar.gz ${OPENSSL_DOWNLOAD} -O "${DOWNLOADS_PATH}${OPENSSL_NAME}.tar.gz"
	    info "Extracting openssl to ${DOWNLOADS_PATH}${OPENSSL_NAME}"
        # Extract openssl tar
	    tar -xvzf "${DOWNLOADS_PATH}${OPENSSL_NAME}.tar.gz" -C ${DOWNLOADS_PATH}
        # Configure openssl in subshell so that everything executes in the directory passed to cd
	    (cd ${DOWNLOADS_PATH}${OPENSSL_NAME}; \
            sudo ./Configure darwin64-x86_64-cc \
                --prefix=/usr/local/openssl \
                --openssldir=/usr/local/openssl; \
            sudo make; \
            sudo make install)
    else
        info "Openssl is already installed"
    fi
	return 0
}

configure_apache() {
    info "Building apache configuration"

    # Copy all apache configuration files from resources folder to apache conf
    sudo chown -R $USER ${APACHE2_HOME}/conf/
	cp $HOME/resources/apache_conf/* ${APACHE2_HOME}/conf/
	#Set Apache username to current user in httpd.conf
    sed -i -e "s/{username}/${USER}/g" ${APACHE2_HOME}/conf/httpd.conf
    # Setup alias for easy invocation of apache
    echo 'alias apache="sudo /usr/local/apache2/bin/apachectl"' >> $HOME/.bash_aliases
	echo '. ~/.bash_aliases' >> $HOME/.bash_profile
    # Source bash_aliases so that 'apache' alias is available immediately
    sleep 1
    source $HOME/.bash_aliases
    info "Type 'apache start' to fire up apache"
}

configure_pcre() {
    # Check if pcre is already installed
    if [[ $( which -s pcre-config ) ]] ; then
        # Configure pcre with /usr/local prefix
        pcre-config --prefix=/usr/local/pcre
    else
        # use brew to install pcre and then configure
        HOMEBREW_NO_AUTO_UPDATE=1 brew install pcre
        pcre-config --prefix=/usr/local/pcre
    fi
}

main(){
    info "APACHE INSTALL"
    install_apache
    install_tomcat
    install_mod_jk
    return 0
}

##############################
#          LOGGING           #
##############################
err() {
    printf "$ERROR_RED[$(date +'%Y-%m-%dT%H:%M:%S%z')] ERROR : $@$NC\n" >&2
}

info() {
    printf "$INFO_BLUE[$(date +'%Y-%m-%dT%H:%M:%S%z')] INFO : $@$NC\n" >&2
}

main
