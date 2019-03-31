#!/bin/bash

#
#  Copyright 2019 Alex Vesev
#
#  This file is part of BTPLS - Bluetooth Proximity Screen Locker.
#
#  BTPLS is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  BTPLS is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with BTPLS. If not, see <http://www.gnu.org/licenses/>.
#
##


PS4="+:\$( basename "\${0}" ):\${LINENO}: "
set -xe

declare -r val_true=0
declare -r val_false=1
declare -r dir_this="$( dirname "$( readlink -f "${0}" )" )"

declare -r template_conf='
{
  "devices": [
    {
      "name": "device-A",
      "mac": "00:AA:BB:11:CC:22",
      "proximity_dB": "-1"
    },
    {
      "name": "device-B",
      "mac": "FF:33:EE:22:DD:11",
      "proximity_dB": "-10"
    }
  ]
}
'


declare -rA file_cnf_pool=( \
    ["dirThis"]="${dir_this}/bt-proximity-screen-locker.conf" \
    ["userspace"]="${HOME}/.config/bt-proximity-screen-locker.conf" \
    ["global"]="/etc/bt-proximity-screen-locker.conf" \
    )


###
##
#


function create_conf_file_stub {
    set -e
    if [ ! -f "${file_cnf_pool["global"]}" ] ; then
        echo "${template_conf}" > "${file_cnf_pool["global"]}"
    fi
}

function get_conf_file_name {
    local f_name
    for f_name in "${file_cnf_pool[@]}" ; do
        if [ -f "${f_name}" ] ; then
            echo -n "${f_name}"
            break
        fi
    done
}

#function is_device_there {
    #local -r addr_mac="${1}"
    #local is_there=${val_false}
    #if l2ping -c 2 -d 0.2 -t 0.3 "${addr_mac}" ; then
        #is_there=${val_true}
    #fi
    #return ${is_there}
#}


function wait_for_device {
    local -r mac_addr="${1}"
    while : ; do
        connect_device "${mac_addr}" || true
        if is_connection_active "${mac_addr}" ; then
            break
        fi
        sleep 1
    done
}


function is_connection_active {
    set +e
    local -r addr_mac="${1}"
    local    is_found=${val_false}
    while read hcitool_output ; do
        if [[ "${hcitool_output}" == *"${addr_mac}"* ]]; then
            is_found=${val_true};
            break
        fi
    done <<< "$( "/usr/bin/hcitool" con )"
    return ${is_found}
}


function connect_device {
    local -r addr_mac="${1}"
    local    is_connected=${val_false}

    if is_connection_active "${addr_mac}" ; then
        is_connected=${val_true};
        echo "INFO:${0}:${LINENO}: Already have active connection to '${addr_mac}'." 1>&2
    else
        if l2ping -c 2 -d 0.2 -t 0.3 "${addr_mac}" ; then
            "/usr/bin/hcitool" cc "${addr_mac}" 1>&2  # Connect it.
            sleep 0.1
            if is_connection_active "${addr_mac}" ; then
                is_connected=${val_true};
                echo "INFO:${0}:${LINENO}: Device '${addr_mac}' has been connected." 1>&2
            else
                echo "ERROR:${0}:${LINENO}: Could not connect to device '${addr_mac}'." 1>&2
                is_connected=${val_false};
            fi
        else
            echo "INFO:${0}:${LINENO}: Device '${addr_mac}' is not visible at all." 1>&2
        fi
    fi
    return ${is_connected}
}


function get_distance {
    set +e
    local -r addr_mac="${1}"
    local -r distance_none=-1024
    local    info=${distance_none}
    local    distance=${distance_none}

    info="$( "/usr/bin/hcitool" rssi "${addr_mac}" )"
    distance="${info//RSSI return value: /}"  # Remove _all_ ocurrences of string in var value.
    if ! [ "${distance_db}" ==  "${distance_db}" ] ; then  #  If it is not an number (positive or negative).
        distance=${distance_none}
        echo "ERROR:${0}:${LINENO}: Evaluated distance (signal strength) not as a number: '${distance_db}'. Dropping to default '${distance_none}'." 1>&2
    fi
    return $(( (${distance} - 100) * -1 ))
}


function lock_it {
    echo "INFO:${0}:${LINENO}: Going to be locked." 1>&2
    #gnome-screensaver-command --lock
    xscreensaver-command -lock
}

function unlock_it {
    echo "INFO:${0}:${LINENO}: Unlocking." 1>&2
    echo "INFO:${0}:${LINENO}: Unlock will not be done as this screen saver can't be auto-unlocked by design." 1>&2
    #gnome-screensaver-command --deactivate
    #xscreensaver-command -deactivate  # Willn't unlock by design.
    sleep 5
}


#function is_ss_active {
    #set +e
    #local -r info="$( gnome-screensaver-command --query 2>&1 )"
    #local -r active_sign="The screensaver is active"
    #local -r inactive_sign="The screensaver is inactive"
    #local    is_active=${val_false}

    #if [[ "${info}" == *"${active_sign}"* ]] ; then
        #is_active=${val_true}
    #elif [[ "${info}" == *"${inactive_sign}"* ]] ; then
        #is_active=${val_false}
    #else
        #is_active=${val_false}
    #fi

    #return ${is_active}
#}


###
##
#


if [ "${EUID}" -ne 0 ] ; then
    echo "ERROR:${0}:${LINENO}: Need to be launched as root or with root permissions." 1>&2
    exit 1
fi

create_conf_file_stub

declare -r file_cnf="$( get_conf_file_name )"
declare    device_mac_addr="$( cat "${file_cnf}" | jq --raw-output .devices[0].mac )"
declare    lock_distance_db="$( cat "${file_cnf}" | jq --raw-output .devices[0].proximity_dB )"  # Locking threshold.


wait_for_device "${device_mac_addr}"

echo "INFO:${0}:${LINENO}: Waking up monitoring of device '${device_mac_addr}'." 1>&2

while : ; do
    attempts_connect=0
    attempts_connect_max=1
    connect_device "${device_mac_addr}" || true
    if is_connection_active "${device_mac_addr}" ; then
        get_distance "${device_mac_addr}" \
            ; distance_db=${?} ; distance_db=$(( (${distance_db} * -1) + 100))
        if [ "${distance_db}" -lt "${lock_distance_db}" ] ; then
            #is_ss_active || lock_it
            lock_it
        elif [ "${distance_db}" -gt "${lock_distance_db}" ] ; then
            #is_ss_active && unlock_it
            unlock_it
        else
            #is_ss_active || lock_it
            lock_it
        fi
        sleep 1
    else
        while ! connect_device "${device_mac_addr}" ; do
            if [ ${attempts_connect} -gt ${attempts_connect_max} ] ; then
                attempts_connect=0
                lock_it
                break
            else
                attempts_connect=$(( ${attempts_connect} + 1 ))
            fi
        done
        wait_for_device "${device_mac_addr}"
    fi
done
