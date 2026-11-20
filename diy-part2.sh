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

# 修复 helloworld 新版 GN 在 Ubuntu 22.04 上的 host 编译兼容问题
GN_MAKEFILE="feeds/helloworld/gn/Makefile"

if [ -f "$GN_MAKEFILE" ] && ! grep -q 'CC=gcc-12 CXX=g++-12 AR=ar' "$GN_MAKEFILE"; then
    sed -i '/$(PYTHON).*build\/gen.py/ s|$(PYTHON)|CC=gcc-12 CXX=g++-12 AR=ar $(PYTHON)|' "$GN_MAKEFILE"
fi

# 移除 openwrt feeds 自带的核心包
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,ipt2socks}
cp -r feeds/passwall_packages/{xray-core,v2ray-geodata,sing-box,ipt2socks} feeds/packages/net/
rm -rf feeds/luci/applications/{luci-app-passwall,luci-app-passwall2}
cp -r feeds/passwall/luci-app-passwall feeds/luci/applications
cp -r feeds/passwall2/luci-app-passwall2 feeds/luci/applications

# 更新 golang 1.27 版本
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang -b 27.x feeds/packages/lang/golang

# 自动更新 FRP 到官方最新稳定版
FRP_DIR="feeds/packages/net/frp"
FRP_MAKEFILE="$FRP_DIR/Makefile"

FRP_VERSION="$(
    git ls-remote --tags --refs https://github.com/fatedier/frp.git \
    | sed -n 's#.*refs/tags/v\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)$#\1#p' \
    | sort -V \
    | tail -1
)"

curl -fL "https://codeload.github.com/fatedier/frp/tar.gz/v${FRP_VERSION}" \
    -o /tmp/frp.tar.gz

FRP_HASH="$(sha256sum /tmp/frp.tar.gz | cut -d' ' -f1)"

sed -i -E "s/^PKG_VERSION:=.*/PKG_VERSION:=${FRP_VERSION}/" "$FRP_MAKEFILE"
sed -i -E "s/^PKG_HASH:=.*/PKG_HASH:=${FRP_HASH}/" "$FRP_MAKEFILE"

# FRP 0.68.0+ 官方支持 noweb
if grep -q '^GO_PKG_TAGS:=' "$FRP_MAKEFILE"; then
    sed -i -E 's/^GO_PKG_TAGS:=.*/GO_PKG_TAGS:=noweb/' "$FRP_MAKEFILE"
else
    sed -i '/^GO_PKG_BUILD_PKG:=/a GO_PKG_TAGS:=noweb' "$FRP_MAKEFILE"
fi

# 当前旧版 OpenWrt recipe 会强制执行 npm/Web 编译，
# noweb 模式下改为只执行 Go 编译
sed -i '/^define Build\/Compile$/,/^endef$/c\
define Build/Compile\
	$(call GoPackage/Build/Compile)\
endef' "$FRP_MAKEFILE"

rm -f /tmp/frp.tar.gz
