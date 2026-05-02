#!/bin/ash

readonly KP_BL2_LEN_SPI=0x40000
readonly KP_FIP_OFF_SPI=0x1D0000
readonly KP_SYS_OFF_SPI=0x2D0000
readonly KP_HDR_OFF_SPI=0x40000
readonly KP_SYS_MTD_PART_SPI=firmware
readonly KP_FIP_VER_OFF_SPI="$((0x6ff00))"

readonly KP_BL2_LEN_NAND=0x100000
readonly KP_SYS_MTD_PART_NAND=ubi
readonly KP_FIP_OFF_NAND=0x580000
readonly KP_SYS_OFF_NAND=0x780000
readonly KP_HDR_OFF_NAND=0x100000
readonly KP_FIP_VER_OFF_NAND="$((0x1fff00))"

readonly KP_BL2_LEN_EMMC=0x4400
readonly KP_FIP_VER_OFF_EMMC="$((0xaff00))"

readonly KP_UBOOT_NAME="FIP"
