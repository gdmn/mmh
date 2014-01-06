#! /usr/bin/env bash

# include config.sh 
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "${SCRIPT_DIR}/config.sh"
if [[ "$?" != "0" ]]; then
	echo 'config.sh not found' ; exit 2
fi
# 

echo_content_type_plain() { 
	echo Content-type: text/plain
	echo ""
} 

arg() { 
	name="$1"
	echo "&${QUERY_STRING}" | sed -n 's/^.*&'"$name"'=\([^&]*\).*$/\1/p' | sed "s/%20/ /g"
}  

process() {
	local debug="$( arg debug )"
	local q="$( arg q )"
	
	if [[ "" != "$debug" ]]; then
		echo "'$QUERY_STRING'"
		echo ""
	fi

	if [[ "" != "$q" ]] ; then
		case "$q" in
			'mtime' )
				stat -c %Y "$MPD_LOG"
				;;
			'tail' )
				tail -n 20 "$MPD_LOG"
				;;
			'outputs' )
				cat "$MUSIC_OUTPUTS"
				;;
			* )
				local f="$( arg f)"
				if [[ "" == "$f" ]] ; then
					mosquitto_pub -h "$MQTT_HOST" -t "$MQTT_COMMAND_TOPIC" -m "$q"
				else
					mosquitto_pub -h "$MQTT_HOST" -t "$MQTT_COMMAND_TOPIC" -m "${q}: $f"
				fi
				;;
		esac
	fi
}

echo_content_type_plain
process

