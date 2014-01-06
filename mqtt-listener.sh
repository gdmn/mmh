#! /usr/bin/env bash

# include config.sh 
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "${SCRIPT_DIR}/config.sh"
if [[ "$?" != "0" ]]; then
	echo 'config.sh not found' ; exit 2
fi
# 

LINE=
cmd="mpc"

pub() {
	$MQ -t "${MQTT_TOPIC}" -m "$1"
}

pub_in() {
	while read l; do
		pub "$l"
	done
}

mpd_config_get() { #{{{
	local key="$1"
	local val=`grep ^$key $MPD_CONFIG`
	if [[ "" != "$val" ]]; then
		val="/${val#*\/}"
		val="${val/\"*/}"
		echo "$val"
	fi
} #}}}

library_refresh_scan_dir() { 
	local dir="$1"
	local output="$2"

	if [ ! -d "$dir" ] || [[ "" == "$dir" ]]; then return; fi

	# append slash at the end
	dir="${dir}/"
	# delete double slashes
	dir="${dir//\/\//\/}"
	
	pub "$dir"
	find "${dir}" -maxdepth 2 -type f -iname '*pls' -or -iname '*m3u' 2>/dev/null \
		| sort >> "$output"
} 

library_refresh_scan_dirs() { 
	mpd_config_get playlist_directory
} 

library_refresh() { 
	local temp="`mktemp`"
	local first=1
	library_refresh_scan_dirs | uniq | \
		while read dir; do
			library_refresh_scan_dir "$dir" "$temp"
		done
	rm -f "$MUSIC_LIST_OUT"
	cat "$temp" | uniq > "$MUSIC_LIST_OUT"
	$cmd ls | sort >> "$MUSIC_LIST_OUT"
	rm -f "$temp"
	pub 'library refresh complete'
} 

handle_code() {
	echo "handling $*"
	#pub "handling $1"

	case $1 in
		'echo' )
			pub ''
			pub ''
			pub 'Hello world!'
			pub '--------------------'
			;;
		'play' )
			pub "$1"
			( $cmd play | pub_in ) &
			;;
		'pause' )
			pub "$1"
			( $cmd pause | pub_in ) &
			;;

		'next' )
			pub "$1"
			( $cmd next | pub_in ) &
			;;
		'previous' )
			pub "$1"
			( $cmd prev | pub_in ) &
			;;

		'seek backward' )
			pub "$1"
			( $cmd seek '-10' | pub_in ) &
			;;
		'seek forward' )
			pub "$1"
			( $cmd seek '+10' | pub_in ) &
			;;

		'volume up' )
			pub "$1"
			( $cmd volume '+5' | pub_in ) &
			;;
		'volume down' )
			pub "$1"
			( $cmd volume '-5' | pub_in ) &
			;;
		'volume '* )
			pub "$1"
			local l="${1/volume /}"
			( $cmd volume "$l" | pub_in ) &
			;;
		
		'repeat off' )
			pub "$1"
			( $cmd repeat off | pub_in ) &
			;;
		'repeat on' )
			pub "$1"
			( $cmd repeat on | pub_in ) &
			;;

		'autonext off' )
			pub "$1"
			( $cmd single on | pub_in ) &
			;;
		'autonext on' )
			pub "$1"
			( $cmd single off | pub_in ) &
			;;

		'shuffle off' )
			pub "$1"
			( $cmd random off | pub_in ) &
			;;
		'shuffle on' )
			pub "$1"
			( $cmd random on | pub_in ) &
			;;

		'library refresh' )
			pub "$1"
			library_refresh;
			;;

		'setplaylist: '* )
			local l="${1/setplaylist: /}"
			pub "$l"
			if [ -f "$l" ] ; then
				( $cmd clear >/dev/null ; \
					grep '/' "$l" | grep -v -i '^title' | \
						while read k ; do
							local item="${k/*=/}"
							$cmd add "$item" | pub_in
						done
					$cmd playlist | pub_in
					$cmd play | pub_in ) &
			else
				( $cmd clear >/dev/null ; \
					$cmd add "$l" | pub_in
					$cmd playlist | pub_in
					$cmd play | pub_in ) &
			fi
			;;

		'playlist' )
			pub "$1"
			( $cmd playlist | pub_in ) &
			;;

		'clear log' )
			pub "$1"
			echo -ne '' > "$MPD_LOG"
			;;
		
		'enable '* )
			pub "$1"
			local l="${1/enable /}"
			( ( $cmd enable "$l"; $cmd outputs ) | pub_in ) &
			;;
		'disable '* )
			pub "$1"
			local l="${1/disable /}"
			( ( $cmd disable "$l"; $cmd outputs ) | pub_in ) &
			;;

		'info' )
			pub "$1"
			( ( $cmd outputs; $cmd status ) \
				| $MQ -t "${MQTT_TOPIC}/title" -s -r ) & ;;
		* )
			echo "Unhandled $1"
			pub "Unhandled $1"
			;;
	esac

}

read_next_line() {
	read LINE
	local RET=$?
	LINE="${LINE//%20/ }"
	return $RET
}

read_sub() {
	while read_next_line; do
		handle_code "$LINE"
	done
}

parse_playlist() {
	grep '/' "$1" | \
		while read k ; do
			echo ${k/*=/}
		done
}

setup_outpus() {
	rm -f "$MUSIC_OUTPUTS"
	$cmd outputs | while read k ; do
		k="${k/*\(/}"
		k="${k/\)*/}"
		echo "${k}" >> "$MUSIC_OUTPUTS"
	done
}

setup_outpus
mosquitto_sub -t "$MQTT_TOPIC" -t "${MQTT_TOPIC}/title" > $MPD_LOG &
subPID=$!

control_c() {
  kill $subPID >/dev/null 2>&1
  fail "ctrl-c"
}

sig_term() {
  kill $subPID >/dev/null 2>&1
  fail "terminated"
}
 
# trap keyboard interrupt (control-c)
trap control_c SIGINT
trap sig_term SIGTERM

mosquitto_sub -h $MQTT_HOST -t $MQTT_LISTEN_TOPIC | read_sub
kill $subPID >/dev/null 2>&1

