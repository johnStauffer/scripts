#!/usr/bin/env bash

################################################################################
###                              MAVEN SETUP SCRIPT                          ###
### author          :jstauffer                                               ###
### date            :2017:06:08                                              ###
################################################################################


##############################
#          VARIABLES         #
##############################

# Basis for installation.. Recommended that environment is built in /usr/local/
DESTINATION="/usr/local/"

# Initial download location for all retrieved files
DOWNLOADS_PATH="${HOME}/Downloads/"

# Download address
MAVEN_DOWNLOAD="http://mirrors.ocf.berkeley.edu/apache/maven/maven-3/3.5.2/binaries/apache-maven-3.5.2-bin.tar.gz"

# Directory names for installations (Should match name of downloaded file except for file type)
MAVEN_NAME="apache-maven-3.5.2-bin"

# Where installations will live. should be built dynamically given the above variables
MAVEN_HOME=$DESTINATION$MAVEN_NAME

# Codes for colored logging output
ERROR_RED='\e[38;5;88m'
INFO_BLUE='\e[94m'
NC='\033[0m' # No Color


##############################
#          FUNCTIONS         #
##############################

download_maven() {
	if [ ! -f "${DOWNLOADS_PATH}${MAVEN_NAME}.tar.gz" ]; then
		info "Downloading Maven"
		wget -A.tar.gz $MAVEN_DOWNLOAD -O "${DOWNLOADS_PATH}${MAVEN_NAME}.tar.gz"
	fi
	if [ ! -d $MAVEN_HOME ]; then
		info "Extracting Maven"
		sudo tar -xvzf  "${DOWNLOADS_PATH}${MAVEN_NAME}.tar.gz" -C $DESTINATION
	fi
}

configure_env_variables() {
	echo "export M2_HOME=/usr/local/apache-maven/${MAVEN_NAME}" >> $HOME/.bash_profile
	echo "export M2=$M2_HOME/bin" >> $HOME/.bash_profile
}

main() {
	download_maven
	configure_env_variables
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
