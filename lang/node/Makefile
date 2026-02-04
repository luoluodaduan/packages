# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.

include $(TOPDIR)/rules.mk

PKG_NAME:=node
PKG_VERSION:=v20.12.2
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://nodejs.org/dist/$(PKG_VERSION)
PKG_HASH:=bc57ee721a12cc8be55bb90b4a9a2f598aed5581d5199ec3bd171a4781bfecda
PATCH_DIR:=./patches/v20.x
NODEJS_BIN_SUM:=f8f9b6877778ed2d5f920a5bd853f0f8a8be1c42f6d448c763a95625cbbb4b0d

PKG_MAINTAINER:=Hirokazu MORIKAWA <morikw2@gmail.com>
PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE
PKG_CPE_ID:=cpe:/a:nodejs:node.js

HOST_BUILD_DEPENDS:=python3/host
HOST_BUILD_PARALLEL:=1

PKG_BUILD_DEPENDS:=python3/host
PKG_BUILD_PARALLEL:=1
PKG_INSTALL:=1
PKG_ASLR_PIE:=0

include $(INCLUDE_DIR)/host-build.mk
include $(INCLUDE_DIR)/package.mk

define Package/node
  SECTION:=lang
  CATEGORY:=Languages
  SUBMENU:=Node.js
  TITLE:=Node.js is a platform built on Chrome's JavaScript runtime
  URL:=https://nodejs.org/
  DEPENDS:=@HAS_FPU @(i386||x86_64||arm||aarch64) \
    +libstdcpp +libopenssl +zlib +libnghttp2 \
    +libatomic +NODEJS_ICU_SYSTEM:icu
endef

define Package/node/description
  Node.js® is a JavaScript runtime built on Chrome's V8 JavaScript engine. Node.js uses
  an event-driven, non-blocking I/O model that makes it lightweight and efficient. Node.js'
  package ecosystem, npm, is the largest ecosystem of open source libraries in the world.
endef

define Package/node-npm
  SECTION:=lang
  CATEGORY:=Languages
  SUBMENU:=Node.js
  TITLE:=NPM stands for Node Package Manager
  URL:=https://www.npmjs.com/
  DEPENDS:=+node
endef

define Package/node-npm/description
  NPM is the package manager for Node.js
endef

define Package/node/config
  if PACKAGE_node
  menu "Configuration"
    choice
      prompt "i18n features (ICU support)"
      default NODEJS_ICU_SMALL

      config NODEJS_ICU_NONE
        bool "Disable (Reduce size)"

      config NODEJS_ICU_SMALL
        bool "small-icu (English only, standard)"

      config NODEJS_ICU_SYSTEM
        bool "system-icu (Full language support, requires 64bit)"
        depends on ARCH_64BIT
        select PACKAGE_icu
    endchoice

    config NODEJS_HOST_BIN
      bool "Use official nodejs binary for HOST build (Linux only)"
      default n
  endmenu
  endif
endef

NODEJS_CPU:=$(subst aarch64,arm64,$(subst x86_64,x64,$(subst i386,ia32,$(ARCH))))

ifneq ($(CONFIG_ARCH_64BIT),y)
FORCE_32BIT:=-m32
endif

MAKE_VARS+= \
  DESTCPU=$(NODEJS_CPU) \
  NO_LOAD='cctest.target.mk embedtest.target.mk node_mksnapshot.target.mk overlapped-checker.target.mk \
    mkcodecache.target.mk tools/v8_gypfiles/torque_base.target.mk tools/v8_gypfiles/v8_init.target.mk' \
  LD_LIBRARY_PATH=$(STAGING_DIR_HOSTPKG)/share/icu/current/lib

HOST_MAKE_VARS+=NO_LOAD='cctest.target.mk embedtest.target.mk overlapped-checker.target.mk'

CONFIGURE_VARS:= \
  CC="$(TARGET_CC) $(TARGET_OPTIMIZATION)" \
  CXX="$(TARGET_CXX) $(TARGET_OPTIMIZATION)" \
  CC_host="$(HOSTCC) $(FORCE_32BIT)" \
  CXX_host="$(HOSTCXX) $(FORCE_32BIT)"

CONFIGURE_ARGS:= \
  --dest-cpu=$(NODEJS_CPU) \
  --dest-os=linux \
  --cross-compiling \
  --shared-zlib \
  --shared-openssl \
  --shared-nghttp2 \
  --with-intl=$(if $(CONFIG_NODEJS_ICU_SMALL),small-icu,$(if $(CONFIG_NODEJS_ICU_SYSTEM),system-icu,none)) \
  --prefix=/usr

ifeq ($(CONFIG_NODEJS_ICU_SYSTEM),y)
  CONFIGURE_ARGS+= --shared-icu
endif

ifeq ($(NODEJS_CPU),arm)
  ifneq ($(findstring +neon,$(CONFIG_CPU_TYPE)),)
    CONFIGURE_ARGS+= --with-arm-fpu=neon
  else ifneq ($(findstring +vfpv4,$(CONFIG_CPU_TYPE)),)
    CONFIGURE_ARGS+= --with-arm-fpu=vfpv4
  else ifneq ($(findstring +vfpv3-d16,$(CONFIG_CPU_TYPE)),)
    CONFIGURE_ARGS+= --with-arm-fpu=vfpv3-d16
  else ifneq ($(findstring +vfpv3,$(CONFIG_CPU_TYPE)),)
    CONFIGURE_ARGS+= --with-arm-fpu=vfpv3
  else ifneq ($(findstring +vfp,$(CONFIG_CPU_TYPE)),)
    CONFIGURE_ARGS+= --with-arm-fpu=vfp
  else
    CONFIGURE_ARGS+= --with-arm-fpu=auto
  endif
endif

HOST_CONFIGURE_VARS:=
HOST_CONFIGURE_ARGS:= \
  --dest-os=$(if $(findstring Darwin,$(HOST_OS)),mac,linux) \
  --with-intl=small-icu \
  --prefix=$(STAGING_DIR_HOSTPKG)

define Build/InstallDev
	$(INSTALL_DIR) $(1)/usr/include
	$(CP) $(PKG_INSTALL_DIR)/usr/include/* $(1)/usr/include/
endef

define Package/node/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/node $(1)/usr/bin/
endef

define Package/node-npm/install
	$(INSTALL_DIR) $(1)/usr/lib/node_modules/npm
	$(INSTALL_DIR) $(1)/usr/bin
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/node_modules/npm $(1)/usr/lib/node_modules/
	rm -f $(1)/usr/bin/npm
	$(LN) ../lib/node_modules/npm/bin/npm-cli.js $(1)/usr/bin/npm
	rm -f $(1)/usr/bin/npx
	$(LN) ../lib/node_modules/npm/bin/npx-cli.js $(1)/usr/bin/npx
endef

define Package/node-npm/postrm
#!/bin/sh
[ -d /usr/lib/node_modules/npm ] && rm -rf /usr/lib/node_modules/npm
endef

USE_NODEJS_HOST_BIN:=
ifeq ($(CONFIG_NODEJS_HOST_BIN),y)
  ifeq ($(HOST_OS),Linux)
    USE_NODEJS_HOST_BIN:=y
  endif
endif

ifeq ($(USE_NODEJS_HOST_BIN),y)
NODEJS_BIN:=node-$(PKG_VERSION)-linux-x64.tar.gz

define Download/nodebin
  URL:=https://nodejs.org/download/release/$(PKG_VERSION)/
  FILE:=$(NODEJS_BIN)
  HASH:=$(NODEJS_BIN_SUM)
endef
$(eval $(call Download,nodebin))

define Host/Prepare
	$(call Host/Prepare/Default)
endef

define Host/Configure
endef

define Host/Compile
endef

define Host/Install
	rm -f $(1)/bin/npm
	rm -f $(1)/bin/npx
	rm -rf $(1)/lib/node_modules/npm
	rm -f $(1)/bin/corepack
	rm -rf $(1)/lib/node_modules/corepack
	$(TAR) -xvf $(DL_DIR)/$(NODEJS_BIN) -C $(1) --strip-components=1
	rm -f $(1)/CHANGELOG.md $(1)/LICENSE $(1)/README.md
endef

else
define Host/Install
	rm -f $(1)/bin/npm
	rm -f $(1)/bin/npx
	rm -rf $(1)/lib/node_modules/npm
	rm -f $(1)/bin/corepack
	rm -rf $(1)/lib/node_modules/corepack
	$(call Host/Install/Default)
endef
endif

$(eval $(call HostBuild))
$(eval $(call BuildPackage,node))
$(eval $(call BuildPackage,node-npm))
