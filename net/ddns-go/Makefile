# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2023 ImmortalWrt.org

include $(TOPDIR)/rules.mk

PKG_NAME:=ddns-go
PKG_VERSION:=6.15.0
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)_$(PKG_VERSION)_linux_arm64.tar.gz
PKG_SOURCE_URL:=https://github.com/jeessy2/ddns-go/releases/download/v$(PKG_VERSION)/
PKG_HASH:=1ff41db81ab842737f3d7027e6820b22d711f9b1366054d340b282d84aac2d69
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=Tianling Shen <cnsztl@immortalwrt.org>

include $(INCLUDE_DIR)/package.mk

define Package/ddns-go
  SECTION:=net
  CATEGORY:=Network
  SUBMENU:=IP Addresses and Names
  TITLE:=Simple and easy-to-use Dynamic DNS client
  URL:=https://github.com/jeessy2/ddns-go
  DEPENDS:=+ca-bundle
  USERID:=ddns-go:ddns-go
endef

define Package/ddns-go/description
  A simple and easy-to-use Dynamic DNS client with IPv6 support.
endef

define Package/ddns-go/conffiles
/etc/config/ddns-go
/etc/ddns-go/config.yaml
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(TAR) -C $(PKG_BUILD_DIR) -zxf $(DL_DIR)/$(PKG_SOURCE)
endef

define Build/Compile
endef

define Package/ddns-go/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ddns-go $(1)/usr/bin/ddns-go
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/ddns-go.conf $(1)/etc/config/ddns-go
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/ddns-go.init $(1)/etc/init.d/ddns-go
	$(INSTALL_DIR) $(1)/etc/ddns-go
endef

$(eval $(call BuildPackage,ddns-go))
