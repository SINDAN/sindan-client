#!/bin/bash
# sindan.sh
# version 6
VERSION="6.0.1"

# directory of the files shared by all platforms
COMMON_DIR=$(cd "$(dirname "$0")/../common" && pwd)

# read configuration file
cd $(dirname $0)
. ./sindan.conf

# read function files
# The files shared by all platforms are in ../common.
cd $(dirname $0)
. "$COMMON_DIR"/sindan_funcb.sh
. ./sindan_func0.sh
. ./sindan_func1.sh
. ./sindan_func2_os.sh
. "$COMMON_DIR"/sindan_func2.sh
. "$COMMON_DIR"/sindan_func3.sh
. ./sindan_func4_os.sh
. "$COMMON_DIR"/sindan_func4.sh
. "$COMMON_DIR"/sindan_func5.sh
. "$COMMON_DIR"/sindan_func6.sh

#
# main
#

####################
## Preparation
# Requirements of this platform, checked by sindan_prepare.sh
OS_REQUIRED_PARAMS=""
OS_REQUIRED_CMDS="gtimeout"
. "$COMMON_DIR"/sindan_prepare.sh

# How this platform differs in Phase 1 (see common/sindan_phase1.sh):
# yes: take the WLAN environment before the interface is restarted
# no: take it from the WLAN information after the interface is up
WLAN_ENVIRONMENT_FIRST="no"

####################
## Phase 0 (shared by all platforms)
. "$COMMON_DIR"/sindan_phase0.sh

####################
## Phase 1 (shared by all platforms)
. "$COMMON_DIR"/sindan_phase1.sh

####################
## Phase 2 (shared by all platforms)
. "$COMMON_DIR"/sindan_phase2.sh

####################
## Phase 3 to 7 (shared by all platforms)
. "$COMMON_DIR"/sindan_phase3_7.sh
