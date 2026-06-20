#!/bin/bash
set -e
set -x

# 设备文件路径定义
DTS_PATH="target/linux/ramips/dts/mt7621_maiwardi_w6180.dts"
MK_PATH="target/linux/ramips/image/mt7621.mk"

# 新建DTS目录
mkdir -p target/linux/ramips/dts

# 写入W6180完整设备树（移除nand_ecc，解决Label not found报错）
cat > "$DTS_PATH" << 'EOF'
// SPDX-License-Identifier: GPL-2.0-or-later OR MIT
/dts-v1/;
#include "mt7621.dtsi"
#include <dt-bindings/gpio/gpio.h>
#include <dt-bindings/input/input.h>

/ {
	compatible = "maiwardi,w6180", "mediatek,mt7621-soc";
	model = "Maiwardi W6180";

	// 256MB内存声明
	memory@0 {
		device_type = "memory";
		reg = <0x0 0x10000000>;
	};

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

// 仅屏蔽nand控制器，删除nand_ecc节点（修复报错核心）
&nand {
	status = "disabled";
};

&spi0 {
	status = "okay";
	flash@0 {
		compatible = "jedec,spi-nor";
		reg = <0>;
		spi-max-frequency = <50000000>;
		broken-flash-reset;
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

// MT7905N 无线pcie节点，适配mt76da闭源驱动
&pcie1 {
	wifi@0,0 {
		compatible = "mediatek,mt7905";
		reg = <0x0000 0 0 0 0>;
		nvmem-cells = <&eeprom_factory_0>;
		nvmem-cell-names = "eeprom";
	};
};

&switch0 {
	mediatek,port-map = "llllw";
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

# 在mt7621.mk末尾追加W6180设备定义，菜单可识别设备
cat >> "$MK_PATH" << 'MK_EOF'
define Device/maiwardi_w6180
  DEVICE_VENDOR := Maiwardi
  DEVICE_MODEL := W6180
  DEVICE_DTS := mt7621_maiwardi_w6180
  IMAGE_SIZE := 32448k
  DEVICE_PACKAGES := mt76da-firmware kmod-mt76-connac mtk-wifi-da kmod-m25p80
endef
TARGET_DEVICES += maiwardi_w6180
MK_EOF

echo "===== DTS & mt7621.mk 写入完成 ====="
echo "设备名称：maiwardi_w6180"
echo "闪存总大小：32MB IMAGE_SIZE=32448k"
echo "已移除nand_ecc节点，修复dtc Label找不到报错"
