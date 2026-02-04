#!/bin/sh
# Wrapper for acme.sh to work on openwrt.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Author: Toke Høiland-Jørgensen <toke@toke.dk>

CHECK_CRON=$1
ACME=/usr/lib/acme/acme.sh
export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
export NO_TIMESTAMP=1
UHTTPD_STOPPED=0
NGINX_STOPPED=0
STATE_DIR=/etc/ssl/acme
ACCOUNT_EMAIL=
DEBUG=0
USER_CLEANUP=
AUTO_UPDATE_DAY_TIME=6
AUTO_UPDATE_WEEK_TIME=2

. /lib/functions.sh

check_cron() {
	[ -f "/etc/crontabs/root" ] && grep -q '/etc/init.d/acme' /etc/crontabs/root && return
	echo "0 $AUTO_UPDATE_DAY_TIME * * $AUTO_UPDATE_WEEK_TIME /etc/init.d/acme start" >>/etc/crontabs/root
	/etc/init.d/cron reload
}

log() {
	logger -t acme -s -p daemon.info -- "$@"
}

err() {
	logger -t acme -s -p daemon.err -- "$@"
}

debug() {
	[ "$DEBUG" -eq "1" ] && logger -t acme -s -p daemon.debug -- "$@"
}

get_listeners() {
	netstat -tnlp 2>/dev/null | awk '/:80 / {print $7}' | sort -u
}

run_acme() {
	debug "Running acme.sh as '$ACME $*'"
	$ACME "$@"
}

pre_checks() {
	main_domain="$1"
	log "Running pre checks for $main_domain."

	for listener in $(get_listeners); do
		[ "$listener" = "-" ] && continue
		pid="${listener%%/*}"
		[ -z "$pid" ] && continue
		cmd=$(basename $(readlink /proc/$pid/exe 2>/dev/null) 2>/dev/null)
		[ -z "$cmd" ] && cmd=$(cat /proc/$pid/comm 2>/dev/null)

		case "$cmd" in
		uhttpd)
			if [ "$UHTTPD_STOPPED" -eq 1 ]; then
				continue
			fi
			debug "Found uhttpd listening on port 80; trying to stop."
			/etc/init.d/uhttpd stop && UHTTPD_STOPPED=1
			;;
		nginx)
			if [ "$NGINX_STOPPED" -eq 1 ]; then
				continue
			fi
			debug "Found nginx listening on port 80; trying to stop."
			/etc/init.d/nginx stop && NGINX_STOPPED=1
			;;
		*)
			err "错误: $main_domain 无法运行。80端口被 $cmd (PID: $pid) 占用。"
			return 1
			;;
		esac
	done

	iptables -I input_rule -p tcp --dport 80 -j ACCEPT -m comment --comment "ACME" || return 1
	ip6tables -I input_rule -p tcp --dport 80 -j ACCEPT -m comment --comment "ACME" || return 1
	return 0
}

post_checks() {
	[ "$CLEANUP_DONE" = "1" ] && return
	CLEANUP_DONE=1

	log "Running post checks (cleanup)."
	# The comment ensures we only touch our own rules.
	# If no rules exist, that is fine, so hide any errors.
	iptables -D input_rule -p tcp --dport 80 -j ACCEPT -m comment --comment "ACME" 2>/dev/null
	ip6tables -D input_rule -p tcp --dport 80 -j ACCEPT -m comment --comment "ACME" 2>/dev/null

	if [ "$UHTTPD_STOPPED" -eq 1 ]; then
		log "重新启动 uhttpd..."
		/etc/init.d/uhttpd start
		UHTTPD_STOPPED=0
	fi

	if [ "$NGINX_STOPPED" -eq 1 ]; then
		log "重新启动 nginx..."
		/etc/init.d/nginx start
		NGINX_STOPPED=0
	fi

	if [ -n "$USER_CLEANUP" ] && [ -f "$USER_CLEANUP" ]; then
		log "Running user-provided cleanup script from $USER_CLEANUP."
		"$USER_CLEANUP"
	fi
}

handle_credentials() {
	eval export "$1"
}

is_staging() {
	grep -q "acme-staging" "$2/$1.conf" 2>/dev/null
}

issue_cert() {
	local section="$1"
	local acme_args=""
	local enabled
	local use_staging
	local keylength
	local keylength_ecc=0
	local domains
	local main_domain
	local webroot
	local dns
	local user_setup
	local user_cleanup
	local ret
	local domain_dir
	local acme_server
	local days
	local dns_wait

	config_get_bool enabled "$section" enabled 0
	[ "$enabled" -eq "1" ] || return 0

	config_get_bool use_staging "$section" use_staging 0
	config_get domains "$section" domains
	config_get keylength "$section" keylength "2048"
	config_get webroot "$section" webroot
	config_get dns "$section" dns
	config_get user_setup "$section" user_setup
	config_get user_cleanup "$section" user_cleanup
	config_get acme_server "$section" acme_server
	config_get days "$section" days
	config_get dns_wait "$section" dns_wait

	USER_CLEANUP=$user_cleanup
	[ "$DEBUG" -eq "1" ] && acme_args="$acme_args --debug"

	set -- $domains
	main_domain=$1
	[ -z "$main_domain" ] && return 1

	if [ -n "$user_setup" ] && [ -f "$user_setup" ]; then
		log "Running user-provided setup script from $user_setup."
		"$user_setup" "$main_domain" || return 1
	else
		[ -n "$webroot" ] || [ -n "$dns" ] || pre_checks "$main_domain" || return 1
	fi

	if echo "$keylength" | grep -q "^ec-"; then
		domain_dir="$STATE_DIR/${main_domain}_ecc"
		keylength_ecc=1
	else
		domain_dir="$STATE_DIR/${main_domain}"
	fi

	log "Running ACME for $main_domain"

	config_list_foreach "$section" credentials handle_credentials

	if [ -e "$domain_dir" ]; then
		if [ "$use_staging" -eq "0" ] && is_staging "$main_domain" "$domain_dir"; then
			log "Found previous cert issued using staging server. Moving it out of the way."
			mv "$domain_dir" "${domain_dir}.staging"
		else
			log "Found previous cert config. Issuing renew."
			[ "$keylength_ecc" -eq "1" ] && acme_args="$acme_args --ecc"
			run_acme --home "$STATE_DIR" --renew -d "$main_domain" $acme_args
			return $?
		fi
	fi

	for d in $domains; do
		acme_args="$acme_args -d $d"
	done

	acme_args="$acme_args --keylength $keylength"
	[ "$keylength_ecc" -eq "1" ] && acme_args="$acme_args --ecc"
	[ -n "$ACCOUNT_EMAIL" ] && acme_args="$acme_args --accountemail $ACCOUNT_EMAIL"

	if [ -n "$acme_server" ]; then
		log "Using custom ACME server URL"
		acme_args="$acme_args --server $acme_server"
	else
		if [ "$use_staging" -eq "1" ]; then
			acme_args="$acme_args --server letsencrypt_test"
		else
			acme_args="$acme_args --server letsencrypt"
		fi
	fi

	if [ -n "$days" ]; then
		log "Renewing after $days days"
		acme_args="$acme_args --days $days"
	fi

	if [ -n "$dns" ]; then
		log "Using dns mode"
		acme_args="$acme_args --dns $dns"
		if [ -n "$dns_wait" ]; then
			acme_args="$acme_args --dnssleep $dns_wait"
		fi
		config_get dalias "$section" dalias
		config_get calias "$section" calias
		if [ -n "$dalias" ]; then
			log "Using domain alias for dns mode"
			acme_args="$acme_args --domain-alias $dalias"
			if [ -n "$calias" ]; then
				err "Both domain and challenge aliases are defined. Ignoring the challenge alias."
			fi
		elif [ -n "$calias" ]; then
			log "Using challenge alias for dns mode"
			acme_args="$acme_args --challenge-alias $calias"
		fi
	elif [ -z "$webroot" ]; then
		log "Using standalone mode"
		acme_args="$acme_args --standalone --listen-v6"
	else
		if [ ! -d "$webroot" ]; then
			err "$main_domain: Webroot dir '$webroot' does not exist!"
			return 1
		fi
		log "Using webroot dir: $webroot"
		acme_args="$acme_args --webroot $webroot"
	fi

	if ! run_acme --home "$STATE_DIR" --issue $acme_args; then
		err "Issuing cert for $main_domain failed."
		return 1
	fi
	[ -n "$user_cleanup" ] && [ -f "$user_cleanup" ] && "$user_cleanup"
}

load_vars() {
	ACCOUNT_EMAIL=$(config_get "$1" account_email)
	DEBUG=$(config_get "$1" debug 0)
}

check_cron
[ -n "$CHECK_CRON" ] && exit 0
[ -e "/var/run/acme_boot" ] && rm -f "/var/run/acme_boot" && exit 0

config_load acme
config_foreach load_vars acme

if [ -z "$ACCOUNT_EMAIL" ]; then
	err "account_email must be set in /etc/config/acme"
	exit 1
fi

[ -d "$STATE_DIR" ] || mkdir -p "$STATE_DIR"

trap post_checks EXIT
trap 'exit 1' HUP TERM
trap 'exit 130' INT

RET=0
config_foreach issue_cert cert || RET=1
exit $RET
