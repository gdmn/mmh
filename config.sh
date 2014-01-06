### crontab:
# PATH=/usr/local/bin:/usr/bin:/bin
#@reboot ( mocp -S  && sleep 15 && /home/pi/public_html/mpd/mqtt-listener.sh ) &
### fstab:
# none    /mnt/ram        tmpfs   auto,nr_inodes=30k,mode=777  0 0

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# MPD config {{{
MPD_LOG='/mnt/ram/mpd.log'
MPD_CONFIG="/etc/mpd.conf"
MUSIC_LIST_OUT="${HOME}/public_html/mpd/mpd.library.txt"
MUSIC_OUTPUTS="${HOME}/public_html/mpd/mpd.out.txt"
# }}}

# MQTT config {{{
MQTT_HOST='127.0.0.1'
MQTT_TOPIC='/mpd'
MQTT_LISTEN_TOPIC="${MQTT_TOPIC}/command"
MQTT_COMMAND_TOPIC="${MQTT_LISTEN_TOPIC}"
MQ="mosquitto_pub -h $MQTT_HOST -i mqtt-str"
# }}}

# CURRENT DIRECTORY {{{
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "Script location: '$SCRIPT_DIR'"
# }}}

# EXIT {{{
## http://stackoverflow.com/questions/9893667/using-exit-in-bash-functions
trap "exit 1" TERM
export TOP_PID=$$

pushd "$SCRIPT_DIR" >/dev/null 2>&1 || exit 2

function fail() {
	#find "$TEMPDIR" >&2
	popd >/dev/null 2>&1
	echo 'FAILED: '"$*" >&1
	kill -s TERM $TOP_PID
} # }}}

