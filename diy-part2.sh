#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Modify default IP
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate

# Modify default theme
#sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Modify hostname
#sed -i 's/OpenWrt/P3TERX-Router/g' package/base-files/files/bin/config_generate


#!/bin/bash
set -e
set -x
DTS_FILE="target/linux/ramips/dts/mt7621_xiaomi_mi-router-cr6606.dts"
MK_FILE="target/linux/ramips/image/mt7621.mk"

# 自动创建dts目录+空文件，消除文件不存在报错
mkdir -p target/linux/ramips/dts
touch "$DTS_FILE"

# 1. 覆盖写入W6180完整DTS
cat > "$DTS_FILE" << 'EOF'
// SPDX-License-Identifier: GPL-2.0-or-later OR MIT
/dts-v1/;
#include "mt7621.dtsi"
#include <dt-bindings/gpio/gpio.h>
#include <dt-bindings/input/input.h>
/ {
	compatible = "maiwardi,w6180", "mediatek,mt7621-soc";
	model = "Maiwardi W6180";
	aliases {
		led-boot = &led_power;
		led-failsafe = &led_power;
		led-running = &led_power;
		led-upgrade = &led_power;
		label-mac-device = &gmac0;
	};
	chosen {
		bootargs = "console=ttyS0,115200n8 mtdparts=spi0.0:192k(u-boot),64k(env),64k(factory),31488k(firmware) root=/dev/mtdblock3 rootfstype=squashfs,jffs2";
	};
	leds {
		compatible = "gpio-leds";
		led_power: power {
			label = "power";
			gpios = <&gpio 14 GPIO_ACTIVE_HIGH>;
		};
		led_wan: wan {
			label = "wan";
			gpios = <&gpio 16 GPIO_ACTIVE_HIGH>;
		};
		led_2g: 2g {
			label = "2.4g";
			gpios = <&gpio 13 GPIO_ACTIVE_HIGH>;
		};
		led_5g: 5g {
			label = "5g";
			gpios = <&gpio 15 GPIO_ACTIVE_HIGH>;
		};
	};
	keys {
		compatible = "gpio-keys";
		reset {
			label = "reset";
			gpios = <&gpio 8 GPIO_ACTIVE_LOW>;
			linux,code = <KEY_RESTART>;
		};
	};
};
&nand {
	status = "disabled";
};
&nand_ecc {
	status = "disabled";
};
&spi0 {
	status = "okay";
	flash@0 {
		compatible = "jedec,spi-nor";
		reg = <0>;
		spi-max-frequency = <50000000>;
		partitions {
			compatible = "fixed-partitions";
			#address-cells = <1>;
			#size-cells = <1>;
			partition@0 {
				label = "u-boot";
				reg = <0x000000 0x030000>;
				read-only;
			};
			partition@30000 {
				label = "env";
				reg = <0x030000 0x010000>;
			};
			partition@40000 {
				label = "factory";
				reg = <0x040000 0x010000>;
				read-only;
				nvmem-layout {
					compatible = "fixed-layout";
					#address-cells = <1>;
					#size-cells = <1>;
					eeprom_factory_0: eeprom@0 {
						reg = <0x0 0xe00>;
					};
					macaddr_factory_0: macaddr@4 {
						reg = <0x4 0x6>;
					};
					macaddr_factory_8000: macaddr@8000 {
						reg = <0x8000 0x6>;
					};
				};
			};
			partition@50000 {
				label = "firmware";
				reg = <0x050000 0x1FA0000>;
				compatible = "openwrt,firmware";
				linux,rootfs;
			};
		};
	};
};
&gmac0 {
	nvmem-cells = <&macaddr_factory_0>;
	nvmem-cell-names = "mac-address";
	status = "okay";
};
&gmac1 {
	nvmem-cells = <&macaddr_factory_8000>;
	nvmem-cell-names = "mac-address";
	status = "okay";
};
&pcie {
	status = "okay";
};
&switch0 {
	mediatek,port-map = "00001110";
	ports {
		port@0 {
			status = "okay";
			label = "wan";
			phy-mode = "rgmii";
		};
		port@1 {
			status = "okay";
			label = "lan1";
			phy-mode = "rgmii";
		};
		port@2 {
			status = "okay";
			label = "lan2";
			phy-mode = "rgmii";
		};
		port@3 {
			status = "disabled";
		};
		port@4 {
			status = "disabled";
		};
	};
};
&state_default {
	gpio {
		groups = "jtag", "uart3", "wdt";
		function = "gpio";
	};
};
EOF
