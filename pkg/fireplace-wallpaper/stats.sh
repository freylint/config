#!/bin/sh
awk '/^cpu /{printf "CPU:%s %s %s %s %s %s %s\n",$2,$3,$4,$5,$6,$7,$8;exit}' /proc/stat

awk '/^MemTotal:/{t=$2}/^MemAvailable:/{a=$2}END{printf "MEM:%.1f/%.0f\n",(t-a)/1048576,t/1048576}' /proc/meminfo

gpu=""
for f in /sys/class/drm/card*/device/gpu_busy_percent; do
    [ -r "$f" ] && gpu=$(cat "$f") && break
done
printf 'GPU:%s\n' "${gpu:---}"

awk '$3=="nvme0n1"||$3=="sda"||$3=="vda"||$3=="hda"{printf "DSK:%s %s\n",$6,$10;exit}' /proc/diskstats

awk 'NR>2 && $1!~/^(lo:|docker|br-|veth|virbr)/{gsub(/:/,"",$1); printf "NET:%s %s\n",$2,$10; exit}' /proc/net/dev
