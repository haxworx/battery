#! /bin/sh

# his is Richo Healey's battery monitor.
# https://github.com/richo
#
# <netstar@gmail.com> "A. Poole":
#   Added support for OpenBSD.
#   Added more precision for OpenBSD.
#   Fixed a bug with buggy results (ACPI??)

RT_FULL=♥
HEART_EMPTY=♡
[ -z "$NUM_HEARTS" ] &&
    NUM_HEARTS=5

cutinate()
{
    perc=$1
    inc=$(( 100 / $NUM_HEARTS))


    for i in `seq $NUM_HEARTS`; do
        if [ $perc -lt 100 ]; then
            echo $HEART_EMPTY
        else
            echo $HEART_FULL
        fi
        perc=$(( $perc + $inc ))
    done
}

linux_get_bat ()
{
    bf=$(cat $BAT_FULL)
    bn=$(cat $BAT_NOW)
    echo $(( 100 * $bn / $bf ))
}


openbsd_get_bat ()
{
    bf=$(echo `sysctl -n hw.sensors.acpibat0.amphour0 | cut -d ' ' -f 1`);
    bn=$(echo `sysctl -n hw.sensors.acpibat0.amphour3 | cut -d ' ' -f 1`);

    # Hack for this battery which seems borken!
    # fixes crazy battery responses!

    perc=$(echo "(($bn * 100) / $bf )" | bc -l | awk -F '.' '{ print $1 }')

    battery_status=$(echo `sysctl -n hw.sensors.acpibat0.raw0 | cut -d ' ' -f 1`)

    if [ $battery_status == 2 ]; then
	echo "charging at $perc";
    elif [ $battery_status == 1 ]; then
	echo "discharging at $perc"
    elif [ $battery_status == 0 ]; then
	echo "charged at 100";
    else
	echo "no battery";
    fi
}

freebsd_get_bat ()
{
    sysctl -n hw.acpi.battery.life
}

# Do with grep and awk unless too hard

# TODO Identify which machine we're on from teh script.

battery_status()
{
case $(uname -s) in
    "Linux")
        BATPATH=${BATPATH:-/sys/class/power_supply/BAT0}
        if [ ! -e $BATPATH ]; then
                BATPATH="/sys/class/power_supply/BAT1";
        fi
        STATUS=$BATPATH/status
        [ "$1" = `cat $STATUS` ] || [ "$1" = "" ] || return 0
        if [ -f "$BATPATH/energy_full" ]; then
            naming="energy"
        elif [ -f "$BATPATH/charge_full" ]; then
            naming="charge"
        elif [ -f "$BATPATH/capacity" ]; then
            cat "$BATPATH/capacity"
            return 0
        fi
        BAT_FULL=$BATPATH/${naming}_full
        BAT_NOW=$BATPATH/${naming}_now
        linux_get_bat
        ;;
    "FreeBSD")
        STATUS=`sysctl -n hw.acpi.battery.state`
        case $1 in
            "Discharging")
                if [ $STATUS -eq 1 ]; then
                    freebsd_get_bat
                fi
                ;;
            "Charging")
                if [ $STATUS -eq 2 ]; then
                    freebsd_get_bat
                fi
                ;;
            "")
                freebsd_get_bat
                ;;
        esac
        ;;
    "OpenBSD")
        openbsd_get_bat
        ;;
    "Darwin")
        case $1 in
            "Discharging")
                ext="No";;
            "Charging")
                ext="Yes";;
        esac

        ioreg -c AppleSmartBattery -w0 | \
        grep -o '"[^"]*" = [^ ]*' | \
        sed -e 's/= //g' -e 's/"//g' | \
        sort | \
        while read key value; do
            case $key in
                "MaxCapacity")
                    export maxcap=$value;;
                "CurrentCapacity")
                    export curcap=$value;;
                "ExternalConnected")
                    if [ -n "$ext" ] && [ "$ext" != "$value" ]; then
                        exit
                    fi
                ;;
                "FullyCharged")
                    if [ "$value" = "Yes" ]; then
                        exit
                    fi
                ;;
            esac
            if [[ -n "$maxcap" && -n $curcap ]]; then
                echo $(( 100 * $curcap / $maxcap ))
                break
            fi
        done
esac
}

BATTERY_STATUS=`battery_status $1`
[ -z "$BATTERY_STATUS" ] && exit

if [ -n "$CUTE_BATTERY_INDICATOR" ]; then
    cutinate $BATTERY_STATUS
else
    echo ${BATTERY_STATUS}%
fi

