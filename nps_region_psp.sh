#!/bin/bash

# AUTHOR sigmaboy <j.sigmaboy@gmail.com>

# get directory where the scripts are located
SCRIPT_DIR="$(dirname "$(readlink -f "$(which "${0}")")")"
#SCRIPT_DIR="/media/wd3red3/Ps-Vita/no-pay-station-games"

# source shared functions
. "${SCRIPT_DIR}/functions.sh"

check_region() {
    local REGION="${1}"
    if ! echo "${REGION}" | grep -q -E -i '^US$|^ASIA$|^EU$|^JP$'
    then
        echo ""
        echo "Error"
        echo "Region is not valid."
        echo "Choose from US, JP, ASIA, EU"
        echo "Check your region parameter."
        exit 1
    fi
}

check_type() {
    local TYPE="${1}"
    if ! echo "${TYPE}" | grep -q -E -i '^game$|^update$|^dlc$|^changelog$|^all$'
    then
        echo ""
        echo "Error:"
        echo "Type is not valid."
        echo "Choose from game, update, dlc or changelog"
        echo "Check your type parameter."
        exit 1
    fi
}

# make color codes human readable
GREEN="\033[0;32m"
CYAN="\033[0;36m"
RED="\033[0;31m"
PURPLE="\033[0;35m"
BROWN="\033[0;33m"
LIGHT_GRAY="\033[0;37m"
LIGHT_BLUE="\033[1;34m"
LIGHT_GREEN="\033[1;32m"
LIGHT_CYAN="\033[1;36m"
LIGHT_RED="\033[1;31m"
LIGHT_PURPLE="\033[1;35m"
YELLOW="\033[1;33m"
WHITE="\033[1;37m"
BOLD="\033[1m"
RESET="\033[0m" #0m restores to the terminal's default colour

check_return_code() {
    local NUMBER="${1}"
    local TYPE="${2}"

    case ${NUMBER} in
        2)
        echo ""
        echo -e "${LIGHT_GREEN}INFO${RESET}:"
        if [ "${TYPE}" == "update" ] || [ "${TYPE}" == "changelog" ]
        then
            echo "No Update available for \"${TITLE_ID}\"."
        else
            echo "No DLCs available for \"${TITLE_ID}\"."
        fi
        echo "Proceed to next download."
        echo ""
        ;;
        3)
        echo ""
        echo -e "${LIGHT_GREEN}INFO${RESET}:"
        echo "Game \"${TITLE_ID}\" is physical only."
        echo "Proceed to next download."
        ;;
        4)
        echo ""
        echo -e "${YELLOW}Warning${RESET}:"
        echo "Key or link not available for \"${TITLE_ID}\"'s ${TYPE}."
        ;;
        5)
        echo ""
        echo -e "${YELLOW}WARNING${RESET}:"
        echo "A t7z archive for the \"${TITLE_ID}\" of"
        echo "type ${TYPE} is already present."
        echo "Proceed to next download."
        ;;
        0)
        echo ""
        echo -e "${LIGHT_GREEN}SUCCESS${RESET}:"
        echo "${TYPE} from \"${TITLE_ID}\" successfully downloaded"
        echo "and compressed."
        echo "Proceed to next download."
        ;;
        *)
        echo ""
        echo -e "${RED}ERROR${RESET}:"
        echo "Game with the following media ID: \"${TITLE_ID}\""
        echo "cannot be downloaded."
        echo "Proceed to next download."
        ;;
    esac
}

### check if nps tsv file directory exists
test_nps_dir() {
    local NPS_DIR="${1}"
    if [ ! -d "${NPS_DIR}" ]
    then
        echo "Directory containing *.tsv files missing (\"${NPS_DIR}\"). Check your path parameter."
        my_usage
        exit 1
    fi
}

### usage function
my_usage(){
    echo ""
    echo "Parameters:"
    echo "--region|-r <REGION>             valid regions: US JP ASIA EU"
    echo "--nps-dir|-d <DIR>               path to the directory containing the tsv files"
    echo "--torrent|-c <ANNOUNCE URL>      Enables torrent creation. Needs announce url"
    echo "--source|-s <SOURCE TAG>         Enables source flag. Needs source tag as argument"
    echo ""
    echo "The \"--source\" and \"--torrent\" parameter are optional. All other"
    echo "parameters are required. The source parameter"
    echo "is required for private torrent trackers only"
    echo ""
    echo "Usage:"
    echo "${0} --region <REGION> --nps-dir </path/to/nps/directory> [--torrent \"http://announce.url\"] [--source <SOURCE_TAG>]"
}

# setting variable defaults
SOURCE_ENABLE=0
CREATE_TORRENT=0
UPDATE_ALL=0
DOWNLOAD_ALL=0

while [ ${#} -ge 1 ]
do
    opt=${1}
    shift
    case ${opt} in
        -c|--torrent)
            test -n "${1}"
            exit_if_fail "\"-c\" used without torrent announce URL"
            check_announce_url "${1}"
            ANNOUNCE_URL="${1}"
            CREATE_TORRENT=1
            shift
            ;;
        -s|--source)
            test -n "${1}"
            exit_if_fail "\"-s\" used without source flag argument used"
            SOURCE_TAG="${1}"
            SOURCE_ENABLE=1
            shift
            ;;
        -d|--nps-dir)
            test -n "${1}"
            exit_if_fail "\"-d\" used without directory path argument used"
            test_nps_dir "${1}"
            NPS_DIR="${1}"
            shift
            ;;
        -r|--region)
            test -n "${1}"
            exit_if_fail "\"-r\" used without region argument used"
            check_region "${1}"
            REGION="${1}"
            shift
            ;;
        *)
            echo "Invalid parameter used."
            my_usage
            echo ""
            exit 1
            ;;
    esac
done

my_mktorrent(){
    local TORRENT_SOURCE="${1}"
    if [ "${SOURCE_ENABLE}" -eq 0 ]
    then
        mktorrent -l 26 -dpa "${ANNOUNCE_URL}" "${TORRENT_SOURCE}"
    else
        mktorrent -l 26 -dpa "${ANNOUNCE_URL}" -s "${SOURCE_TAG}" "${TORRENT_SOURCE}"
    fi
}

# check if necessary binaries are available
MY_BINARIES="pkg2zip mktorrent sed"
check_binaries "${MY_BINARIES}"

### check if every parameter is set
if [ -z "${REGION}" ] || [ -z "${NPS_DIR}" ]
then
    echo "ERROR: Not every necessary option specified."
    my_usage
    exit 1
fi

NPS_ABSOLUTE_PATH="$(readlink -f "${NPS_DIR}")"

tsv_file="PSP_GAMES.tsv"
PARAMS="${NPS_ABSOLUTE_PATH}/${tsv_file}"
download_script="${SCRIPT_DIR}/nps_psp.sh"
        
### check if the game file is available to call download scripts
if [ ! -e "${NPS_ABSOLUTE_PATH}/PSP_GAMES.tsv" ]
then
    echo "*.tsv file \"PSP_GAMES.tsv\" in path \"${NPS_DIR}\" missing."
    echo "This is needed to identify every game of a region."
    exit 1
fi

### check if the tsv file is available to call download scripts
if [ -n "${tsv_file}" ]
then
    if [ ! -e "${NPS_ABSOLUTE_PATH}/${tsv_file}" ]
    then
        echo "*.tsv file \"${tsv_file}\" in path \"${NPS_DIR}\" missing."
        exit 1
    fi
fi

case "${REGION}" in
    "US")
        REGION_COLLECTION="US"
        ;;
    "EU")
        REGION_COLLECTION="PAL"
        ;;
    "JP")
        REGION_COLLECTION="NTSC-J"
        ;;
    "ASIA")
        REGION_COLLECTION="NTSC-C"
        ;;
esac

COLLECTION_NAME="Sony - PlayStation Portable (${REGION_COLLECTION})"

MY_PATH=$(pwd)
test ! -d "${MY_PATH}/${COLLECTION_NAME}" && mkdir "${MY_PATH}/${COLLECTION_NAME}"
cd "${MY_PATH}/${COLLECTION_NAME}"

### Download every available title id of a specific region
# yeah this grep pattern is really ugly but only gnu grep allows "grep -P" to search for tabs without modifications
echo "about to loop through the tsv file"
echo "path = ${NPS_ABSOLUTE_PATH}"
echo "region = ${REGION}"
for TITLE_ID in $(grep $'\t'"${REGION}"$'\t' "${NPS_ABSOLUTE_PATH}/PSP_GAMES.tsv" | awk '{ print $1 }');
do
    echo "--------------------------------------------";
    echo "Downloading and packing \"${TITLE_ID}\"...";
    echo "script dir =  \"${SCRIPT_DIR}\"...";

        ${SCRIPT_DIR}/nps_psp.sh "${NPS_ABSOLUTE_PATH}/PSP_GAMES.tsv" "${TITLE_ID}"
        rm ${TITLE_ID}.txt
   #     check_return_code ${?} "game"
    #    GAME_NAME="$(cat "${TITLE_ID}.txt")"
     #   GAME_NAME="$(region_rename "${GAME_NAME}")"

    #DESTDIR="${GAME_NAME}" ${SCRIPT_DIR}/nps_update.sh "${TITLE_ID}"
    
    ### remove temporary game name file
    #test -f ${TITLE_ID}.txt && rm "${TITLE_ID}.txt"
done;

echo "done looping through the tsv file"
cd "${MY_PATH}"

### Creating the torrent files if set
if [ ${CREATE_TORRENT} -eq 1 ]
then
    echo "Creating torrent file for \"${COLLECTION_NAME}\""
    my_mktorrent "${COLLECTION_NAME}"
fi


### Run post scripts
if [ -x ./nps_region_post.sh ]
then
    ./nps_region_post.sh "${COLLECTION_NAME}"
fi
