#!/bin/bash
set -e
set -x
BASE_TARGET="target/linux/ramips"
DTS_DIR="${BASE_TARGET}/dts"
DTS_FILE="${DTS_DIR}/mt7621_maiwardi_w6180.dts"
MK_FILE="${BASE_TARGET}/image/mt7621.mk"

mkdir -p "${DTS_DIR}"
mkdir -p "${BASE_TARGET}/image"
if [ ! -d "${DTS_DIR}" ]; then
    echo "ERROR DTS目录创建失败！"
    exit 1
fi

cat > "${DTS_FILE}" << 'EOF'
// SPDX-License-Identifier: GPL-2.0-or-later OR MIT
/dts-v1/;
#include "mt7621.dtsi"
#include <dt-bindings/gpio/gpio.h>
#include <dt-bindings/input/input.h>
/ {
	compatible = "maiwardi,w6180", "mediatek,mt7621-soc";
	model = "Maiwardi W6180";
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
		/* 方案 A: 使用 root=/dev/root 自动探测 rootfs，无需手动指定偏移 */
		bootargs = "console=ttyS0,115200n8 root=/dev/mtdblock3 rootfstype=squashfs,jffs2";
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
			uboot: partition@0 {
				label = "u-boot";
				reg = <0x000000 0x030000>;
				read-only;
			};
			env: partition@30000 {
				label = "env";
				reg = <0x030000 0x010000>;
			};
			factory: partition@40000 {
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
			firmware: partition@50000 {
				label = "firmware";
				reg = <0x050000 0x1FB0000>;
				compatible = "openwrt,firmware";
                openwrt,offset = <0x400000>;   /* 对应 KERNEL_SIZE=4M */
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
	mediatek,mt7530;
	#address-cells = <1>;
	#size-cells = <0>;
	ports {
		port@0 {
			reg = <0>;
			label = "wan";
			phy-mode = "rgmii";
			phy-handle = <&phy0>;
		};
		port@1 {
			reg = <1>;
			label = "lan1";
			phy-mode = "rgmii";
			phy-handle = <&phy1>;
		};
		port@2 {
			reg = <2>;
			label = "lan2";
			phy-mode = "rgmii";
			phy-handle = <&phy2>;
		};
		port@3 {
			reg = <3>;
			status = "disabled";
		};
		port@4 {
			reg = <4>;
			status = "disabled";
		};
	};
	mdio-bus {
		#address-cells = <1>;
		#size-cells = <0>;
		phy0: phy@0 { reg = <0>; };
		phy1: phy@1 { reg = <1>; };
		phy2: phy@2 { reg = <2>; };
		phy3: phy@3 { reg = <3>; status = "disabled"; };
		phy4: phy@4 { reg = <4>; status = "disabled"; };
	};
};
&state_default {
	gpio {
		groups = "jtag", "uart3", "wdt";
		function = "gpio";
	};
};
EOF

if [ ! -f "${DTS_FILE}" ]; then
    echo "ERROR DTS文件写入失败！文件不存在"
    exit 1
fi
echo "DTS文件生成成功: ${DTS_FILE}"

# 删除可能存在的旧设备定义，避免冲突（确保新规则生效）
sed -i '/maiwardi_w6180/d' "$MK_FILE"

# 追加新设备定义（标准 OpenWrt 格式，非 trx）
cat >> "${MK_FILE}" << 'MK_EOF'
define Device/maiwardi_w6180
  DEVICE_VENDOR := Maiwardi
  DEVICE_MODEL := W6180
  DEVICE_DTS := mt7621_maiwardi_w6180
  IMAGE_SIZE := 32448k
  KERNEL_SIZE := 4194304             # 固定内核区域为 4MB
  IMAGES += factory.bin sysupgrade.bin
  IMAGE/factory.bin := append-kernel | append-rootfs | pad-rootfs
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
  DEVICE_PACKAGES := mt76da-firmware kmod-mt76-connac mtk-wifi-da kmod-m25p80
endef
TARGET_DEVICES += maiwardi_w6180
MK_EOF

# 验证定义是否写入成功（方便在编译日志中检查）
echo "===== mt7621.mk 中 maiwardi_w6180 定义 ====="
grep -A10 "maiwardi_w6180" "$MK_FILE" || echo "未找到定义！"
echo "=================== 全部脚本执行完毕 ==================="
