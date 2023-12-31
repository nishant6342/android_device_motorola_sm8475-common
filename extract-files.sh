#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

ONLY_COMMON=
ONLY_TARGET=
KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        --only-common )
                ONLY_COMMON=true
                ;;
        --only-target )
                ONLY_TARGET=true
                ;;
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
        system_ext/etc/permissions/moto-telephony.xml)
            sed -i "s#/system/#/system_ext/#" "${2}"
            ;;
        system_ext/lib/vendor.qti.hardware.qccsyshal@1.2-halimpl.so)
            "${PATCHELF}" --replace-needed "libprotobuf-cpp-full.so" "libprotobuf-cpp-full-v33.so" "${2}"
            ;;
        system_ext/lib64/vendor.qti.hardware.qccsyshal@1.2-halimpl.so)
            "${PATCHELF}" --replace-needed "libprotobuf-cpp-full.so" "libprotobuf-cpp-full-v33.so" "${2}"
            ;;
        vendor/etc/media_cape/video_system_specs.json \
        |vendor/etc/media_ukee/video_system_specs.json \
        |vendor/etc/media_taro/video_system_specs.json)
            sed -i "/max_retry_alloc_output_timeout/ s/2000/0/" "${2}"
            ;;
        vendor/etc/vintf/manifest/vendor.dolby.media.c2@1.0-service.xml)
            sed -ni '/default1/!p' "${2}"
            ;;
        vendor/lib/libcamximageformatutils.so)
            ${PATCHELF} --replace-needed "vendor.qti.hardware.display.config-V2-ndk_platform.so" "vendor.qti.hardware.display.config-V2-ndk.so" "${2}"
            ;;
        vendor/lib64/libcamximageformatutils.so)
            ${PATCHELF} --replace-needed "vendor.qti.hardware.display.config-V2-ndk_platform.so" "vendor.qti.hardware.display.config-V2-ndk.so" "${2}"
            ;;
        vendor/bin/hw/android.hardware.security.keymint-service-qti)
            ${PATCHELF} --replace-needed "android.hardware.security.keymint-V1-ndk_platform.so" "android.hardware.security.keymint-V1-ndk.so" "${2}"
            ${PATCHELF} --replace-needed "android.hardware.security.secureclock-V1-ndk_platform.so" "android.hardware.security.secureclock-V1-ndk.so" "${2}"
            ${PATCHELF} --replace-needed "android.hardware.security.sharedsecret-V1-ndk_platform.so" "android.hardware.security.sharedsecret-V1-ndk.so" "${2}"
            ${PATCHELF} --add-needed "android.hardware.security.rkp-V1-ndk.so" "${2}"
            ;;
        vendor/lib/libqtikeymint.so)
            ${PATCHELF} --replace-needed "android.hardware.security.keymint-V1-ndk_platform.so" "android.hardware.security.keymint-V1-ndk.so" "${2}"
            ${PATCHELF} --replace-needed "android.hardware.security.secureclock-V1-ndk_platform.so" "android.hardware.security.secureclock-V1-ndk.so" "${2}"
            ${PATCHELF} --replace-needed "android.hardware.security.sharedsecret-V1-ndk_platform.so" "android.hardware.security.sharedsecret-V1-ndk.so" "${2}"
            ${PATCHELF} --add-needed "android.hardware.security.rkp-V1-ndk.so" "${2}"
            ;;
        vendor/lib64/libqtikeymint.so)
            ${PATCHELF} --replace-needed "android.hardware.security.keymint-V1-ndk_platform.so" "android.hardware.security.keymint-V1-ndk.so" "${2}"
            ${PATCHELF} --replace-needed "android.hardware.security.secureclock-V1-ndk_platform.so" "android.hardware.security.secureclock-V1-ndk.so" "${2}"
            ${PATCHELF} --replace-needed "android.hardware.security.sharedsecret-V1-ndk_platform.so" "android.hardware.security.sharedsecret-V1-ndk.so" "${2}"
            ${PATCHELF} --add-needed "android.hardware.security.rkp-V1-ndk.so" "${2}"
            ;;
        vendor/lib64/vendor.qti.hardware.qxr-V1-ndk_platform.so)
            ${PATCHELF} --replace-needed "android.hardware.common-V2-ndk_platform.so" "android.hardware.common-V2-ndk.so" "${2}"
            ;;
        vendor/bin/init.qti.media.sh)
            sed -i "s#build_codename -le \"12\"#build_codename -le \"13\"#" "${2}"
            ;;
        # rename moto modified primary audio to not conflict with source built
        vendor/lib/hw/audio.primary.taro-moto.so | vendor/lib64/hw/audio.primary.taro-moto.so)
            "${PATCHELF}" --set-soname audio.primary.taro-moto.so "${2}"
            ;;
        vendor/lib64/vendor.qti.gnss-service.so)
            "${PATCHELF}" --replace-needed "android.hardware.gnss-V1-ndk_platform.so" "android.hardware.gnss-V1-ndk.so" "${2}"
            ;;
        vendor/lib64/libdlbdsservice.so | vendor/lib64/soundfx/libswdap.so)
            "${PATCHELF}" --replace-needed "libstagefright_foundation.so" "libstagefright_foundation-v33.so" "${2}"
            ;;
    esac
}

if [ -z "${ONLY_TARGET}" ]; then
    # Initialize the helper for common device
    setup_vendor "${DEVICE_COMMON}" "${VENDOR}" "${ANDROID_ROOT}" true "${CLEAN_VENDOR}"

    extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

if [ -z "${ONLY_COMMON}" ] && [ -s "${MY_DIR}/../${DEVICE}/proprietary-files.txt" ]; then
    # Reinitialize the helper for device
    source "${MY_DIR}/../${DEVICE}/extract-files.sh"
    setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

    extract "${MY_DIR}/../${DEVICE}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

"${MY_DIR}/setup-makefiles.sh"
