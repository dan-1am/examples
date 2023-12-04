#!/bin/bash

#!!! remove lang refresh at 10s???
#!!! use lang codes from pipe???
#dzenpanel v1.08 2023.07.31 display memory usage
#dzenpanel v1.07 2021.07.06 lang switch watching xkb-switch
#dzenpanel v1.06 2021.03.02 Return from signal to pipe communication
#dzenpanel v1.05 2021.02.27 Get rid of subshell/sleep processes
#dzenpanel v1.04 2021.01.25
#dzenpanel v1.03 2020.09.08 19:21:24
#dzenpanel v1.02 2020.07.08 19:47:42
#dzenpanel v1.01 2020.06.18 03:28:00

#cat /proc/cpuinfo|grep -E '(model name)|(cpu MHz)'

pipe=/tmp/dzenpanel$DISPLAY
termpos="-geometry -2+24"

# fork in background
if [ "$1" == "-d" ]; then
    setsid "$0" &> /dev/null < /dev/null &
    exit
fi


calendar(){
  urxvt $termpos -e sh -c 'cal -n 6 -S -m;read -n 1'
#  { cal -m; sleep 20; } | dzen2 -l 7 -x "-220" -y 32 -w 220 -sa 'c' \
#  -fn fixed -e 'onstart=uncollapse;button1=exit;button3=exit'
}


exitmenu(){
  txt=$(echo -e "=X exit options=\nCancel\nExit X\nReboot\nPower off" | dzen2 \
  -m -p -l 4 -x "-200" -y 32 -w 200 -ta 'c' -sa 'c' \
  -e 'onstart=uncollapse,grabmouse;button1=menuprint,exit;button3=exit')
  txt=${txt:0:3}
  [ "$txt" == "Exi" ] && openbox --exit
  [ "$txt" == "Reb" ] && sudo reboot
  [ "$txt" == "Pow" ] && sudo poweroff
}


case "$1" in
volup) amixer -q set Master 2+; echo "vol">$pipe; exit ;;
voldn) amixer -q set Master 2-; echo "vol">$pipe; exit ;;
volx) amixer -q set Front toggle; echo "vol">$pipe; exit ;;
lang) xkb-switch --next; echo "lang">$pipe; exit ;;
cal) calendar; exit ;;
raise) echo "raise">$pipe; exit ;;
exit) exitmenu; exit ;;
esac

#if [ "$1" == "cpu" ]; then
#    ps -A f | dzen2 -p -l 20 -x "-600" -w 600 -y 32 -ta 'l' -sa 'l' -fn fixed-8 \
#-e "onstart=uncollapse,grabkeys;key_Escape=exit;button1=exit;button3=exit;\
#key_Up=scrollup;key_Down=scrolldown;key_Prior=scrollup:20;\
#key_Next=scrolldown:20;button4=scrollup;button5=scrolldown"
#    exit
#fi


heatfilebyid(){
  heatfile="/sys/class/thermal/thermal_zone${1}/temp"
}


findheatfile(){
  for heatmax in 9 8 7 6 5 4 3 2 1 0; do
    heatfilebyid $heatmax
    if [ -e "$heatfile" ]; then return 0; fi
  done
  return 1
}


updatevol(){
  vol="$(amixer -M sget Master)"
  mute="$(amixer -M sget Front)"
  if [ -z "${mute##*'[on]'*}" ]; then
    mute="+"
  else
    mute="x"
  fi
  vol="${vol#*[}"
  vol="00${vol%%\%*}"
  vol="${mute}${vol: -3}"
}


updatelang(){
  lang="$(xkb-switch -p)"
}


updateslow(){
  updatevol
  updatelang
}


updatefast(){
  time=$(date '+%F %a   %H:%M:%S')

  [ -e "$heatfile" ] && read temp < "$heatfile"
  # check if $temp is integer
  [ "$temp" -eq "$temp" ] 2>/dev/null || temp=0
  temp=$((100+temp/1000))
  temp=${temp:1:3}

  read total user nice system idle total < /proc/stat
  total=$((user+system+idle))
  cpu=1000
  [ "$total" != "$total0" ] && cpu=$((1000+100*(user+system-active0)/(total-total0)))
  active0=$((user+system))
  total0=$total
  cpu=${cpu:1}

  if read txt mem0 txt; read txt; read txt mem1 txt; then
    mem=$((1000+100*(mem0-mem1)/mem0))
    mem=${mem:1}
  fi </proc/meminfo
}


toggleraise(){
  if [ $raise = 0 ]; then
    raise=1
    echo '^raise()'
  else
    raise=0
    echo '^lower()'
  fi
}


launch="^ca(1,xdotool key Super_L+w)W^ca() \
^ca(1,xdotool key Super_L+l)L^ca() \
  ^ca(1,urxvt -e /bin/bash)T^ca() ^ca(1,spacefm)F^ca() \
^ca(1,firefox-bin)I^ca()   \
^ca(1,xdotool set_desktop 0)1^ca() \
^ca(1,xdotool set_desktop 1)2^ca() \
^ca(1,xdotool set_desktop 2)3^ca() \
^ca(1,xdotool set_desktop 3)4^ca()"


display(){
    local raisetext="_"
    if [ "$raise" = 1 ]; then
      raisetext="^^"
    fi
    echo "^tw() $launch^p(_RIGHT)^p(-580)\
^ca(1,$0 lang)^fg(gay80)${lang}^ca()\
 ^ca(1,urxvt $termpos -e alsamixer)^ca(3,$0 volx)\
^ca(5,$0 voldn)^ca(4,$0 volup)\
^fg(gay80)$vol^ca()^ca()^ca()^ca()\
 ^fg(red)t$temp\
 ^ca(1,urxvt $termpos -e top)^fg(green)$cpu^ca()\
 ^fg(yellow)$mem\
    ^ca(1,$0 cal)^fg(grey)$time^ca()\
    ^ca(1,$0 raise)$raisetext^ca() ^ca(1,$0 exit)X^ca()"
}


if [ ! -p $pipe ]; then mkfifo $pipe; fi
findheatfile
temp=0
count=1
raise=1
update=0

trap "kill \$killpid; rm -f $pipe" EXIT
#trap "refresh" USR1

# redirect script stdout to dzen
exec > >(exec dzen2 -bg gray10 -fn 'Liberation Mono-12' -ta 'l' -e '')
# workaround for fifo read timeout
exec 3<>$pipe
# get temporary empty file descriptor to read with timeout
#exec <> <(:)
xkb-switch -W >$pipe &
killpid=$!

while :; do
  updatefast
  if [ $count = "1" ]; then
      updateslow
  fi
  display
  while :; do
#echo -n 1 >&2
    read -t 1 line <&3
    case "$line" in
    "") break ;;
    vol) updatevol; updatefast; display ;;
    lang) updatelang; updatefast; display ;;
    raise) toggleraise; updatefast; display ;;
    *) updateslow; break;;
    esac
  done
  (( --count < 1)) && count=10
done
