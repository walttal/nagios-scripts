#!/bin/bash
#nagios return
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

#tips: type cmd || hash cmd
command -v snmpwalk >/dev/null 2>&1 || { echo "SNMPWALK not found. Aborting."; exit $(STATE_WARNING); }
snmpwalk_command=$(command -v snmpwalk)

hostname_oid='1.3.6.1.2.1.1.5.0'

switchboard_detailed_info_oid='1.3.6.1.4.1.2636.3.1.13.1'
switchboard_chassis_temp_detailed_info_oid='1.3.6.1.4.1.2636.3.1.13.1.7.7'
switchboard_engine_temp_detailed_info_oid='1.3.6.1.4.1.2636.3.1.13.1.7.9'
switchboard_power_supply_detailed_info_oid='1.3.6.1.4.1.2636.3.1.13.1.6.2'
switchboard_fan_state_detailed_info_oid='1.3.6.1.4.1.2636.3.1.13.1.6.4'
switchboard_FPC_Board_detailed_info_oid='1.3.6.1.4.1.2636.3.1.13.1.6.7'
switchboard_PIC_Board_detailed_info_oid='1.3.6.1.4.1.2636.3.1.13.1.6.8'
switchboard_routing_engine_detailed_info_oid='1.3.6.1.4.1.2636.3.1.13.1.6.9'
switchboard_cpu_usage_detailed_info_oid='1.3.6.1.4.1.2636.3.1.13.1.8.9'
switchboard_memory_usage_detailed_info_oid='1.3.6.1.4.1.2636.3.1.13.1.11.9'
switchboard_detailed_description_info_oid='1.3.6.1.4.1.2636.3.1.13.1.5'

switchboard_interface_state_oid='1.3.6.1.2.1.2.2.1.8'
switchboard_interface_port_oid='1.3.6.1.2.1.2.2.1.2'
switchboard_interface_description_oid='1.3.6.1.2.1.31.1.1.1.18'

current_timestamp=$(date +%s)

usage_help() {
  echo "Usage $(basename $0): -p [1|2c|3]"
  echo "Usage $(basename $0): -H hostname -c community -p [1|2c|3] -o .[[:digital:]]. -h -u percentage -m percentage"
  echo "Usage $(basename $0): --Host hostname --community community --protocol [1|2c|3] --oid .[[:digital:]]. --help --cpu percentage --memory percentage"
  echo "Usage $(basename $0): --Host=hostname --community=community --protocol=[1|2c|3] --oid=.[[:digital:]]. --help --cpu=percentage --memory=percentage"
}

options=$(getopt -o H:c:p:o:u:m:h --long Host:,community:,protocol:,oid:,cpu:,memory:,help -n 'help' -- "$@")
if [ $? -ne 0 ];then
  #echo "Terminating..." >&2
  echo "Terminating..."
  exit ${STATE_UNKNOWN}
fi

eval set -- "$options"

while true;do
  case "$1" in
    -H|--Host)
    host_ip=$2
    if [[ $host_ip == *=* ]];then
      echo "Wrong host parameters..."
      exit ${STATE_UNKNOWN}
    fi
    shift 2;;
    -c|--community)community=$2;shift 2;;
    -p|--protocol)
    protocol_version=$2
    if [[ ! $protocol_version == 1 && ! $protocol_version == 2c && ! $protocol_version == 3 ]];then
      echo "Wrong protocol parameters..."
      exit ${STATE_UNKNOWN}
    fi
    shift 2;;
    -o|--oid)
    resources_specified_or_switchboard_interface_oid=$2
    if [[ ! -z $(echo $resources_specified_or_switchboard_interface_oid | sed 's/[.0-9]//g') ]];then
      echo "Wrong oid parameters..."
      exit ${STATE_UNKNOWN}
    fi
    shift 2;;
    -u|--cpu)
    cpu_critical_threshold=$2
    if [[ ! -z $(echo $cpu_critical_threshold | sed 's/[0-9]//g') ]];then
      echo "Wrong cpu threshold parameters..."
      exit ${STATE_UNKNOWN}
    else
      if [[ $cpu_critical_threshold -le 0 || $cpu_critical_threshold -ge 100 ]];then
        echo "Cpu threshold parameters out of range..."
        exit ${STATE_UNKNOWN}
      fi
    fi
    shift 2;;
    -m|--memory)
    memory_buffer_critical_threshold=$2
    if [[ ! -z $(echo $memory_buffer_critical_threshold | sed 's/[0-9]//g') ]];then
      echo "Wrong memory buffer threshold parameters..."
      exit ${STATE_UNKNOWN}
    else
      if [[ $memory_buffer_critical_threshold -le 0 || $memory_buffer_critical_threshold -ge 100 ]];then
        echo "Memory buffer threshold parameters out of range..."
        exit ${STATE_UNKNOWN}
      fi
    fi
    shift 2;;
    -h|--help)usage_help;break;;
    --)shift;break;;
    *)echo "Unknown options...";exit ${STATE_UNKNOWN};;
  esac
done

if [[ ! $options == *-h* && ! $options == *--help* ]];then
  if [[ -z $host_ip || -z $community || -z $protocol_version || -z $resources_specified_or_switchboard_interface_oid ]];then
    echo "Missing options..."
    exit ${STATE_UNKNOWN}
  fi
fi

chassis_temp_detailed_info() {
  if [[ ! -f $file_chassis_temp_detailed_info || $(expr $current_timestamp - $(stat -c %Z $file_chassis_temp_detailed_info)) -gt 60 ]];then
    $snmpwalk_command -v $protocol_version -c $community $host_ip $switchboard_chassis_temp_detailed_info_oid 2>&1 >$file_chassis_temp_detailed_info
  fi
  chassis_temp_status_value=$(grep "${resources_specified_or_switchboard_interface_oid#1.3.6.1.4.1.}" $file_chassis_temp_detailed_info | sed 's/.* = Gauge.*: //')
  if [[ $chassis_temp_status_value -lt 40 ]];then
    status_value=$chassis_temp_status_value
    detailed_info_description
  else
    echo "Chassis temperature overheating higher than 40 degree"
    exit ${STATE_CRITICAL}
  fi
}

engine_temp_detailed_info() {
  if [[ ! -f $file_engine_temp_detailed_info || $(expr $current_timestamp - $(stat -c %Z $file_engine_temp_detailed_info)) -gt 60 ]];then
    $snmpwalk_command -v $protocol_version -c $community $host_ip $switchboard_engine_temp_detailed_info_oid 2>&1 >$file_engine_temp_detailed_info
  fi
  engine_temp_status_value=$(grep "${resources_specified_or_switchboard_interface_oid#1.3.6.1.4.1.}" $file_engine_temp_detailed_info | sed 's/.* = Gauge.*: //')
  if [[ $engine_temp_status_value -lt 40 ]];then
    status_value=$engine_temp_status_value
    detailed_info_description
  else
    echo "Engine temperature overheating higher than 40 degree"
    exit ${STATE_CRITICAL}
  fi
}

power_supply_detailed_info() {
  if [[ ! -f $file_power_supply_detailed_info || $(expr $current_timestamp - $(stat -c %Z $file_power_supply_detailed_info)) -gt 60 ]];then
    $snmpwalk_command -v $protocol_version -c $community $host_ip $switchboard_power_supply_detailed_info_oid 2>&1 >$file_power_supply_detailed_info
  fi
  power_supply_status_value=$(grep "${resources_specified_or_switchboard_interface_oid#1.3.6.1.4.1.}" $file_power_supply_detailed_info | sed 's/.* = INTEGER.*: //')
  if [[ $power_supply_status_value -eq 2 ]];then
    status_value=$power_supply_status_value
    detailed_info_description
  else
    echo "Power supply state abnormal"
    exit ${STATE_CRITICAL}
  fi
}

fan_state_detailed_info() {
  if [[ ! -f $file_fan_state_detailed_info || $(expr $current_timestamp - $(stat -c %Z $file_fan_state_detailed_info)) -gt 60 ]];then
    $snmpwalk_command -v $protocol_version -c $community $host_ip $switchboard_fan_state_detailed_info_oid 2>&1 >$file_fan_state_detailed_info
  fi
  fan_state_status_value=$(grep "${resources_specified_or_switchboard_interface_oid#1.3.6.1.4.1.}" $file_fan_state_detailed_info | sed 's/.* = INTEGER.*: //')
  if [[ $fan_state_status_value -eq 2 ]];then
    status_value=$fan_state_status_value
    detailed_info_description
  else
    echo "Fan state abnormal"
    exit ${STATE_CRITICAL}
  fi
}

FPC_Board_detailed_info() {
  if [[ ! -f $file_FPC_Board_detailed_info || $(expr $current_timestamp - $(stat -c %Z $file_FPC_Board_detailed_info)) -gt 60 ]];then
    $snmpwalk_command -v $protocol_version -c $community $host_ip $switchboard_FPC_Board_detailed_info_oid 2>&1 >$file_FPC_Board_detailed_info
  fi
  FPC_Board_status_value=$(grep "${resources_specified_or_switchboard_interface_oid#1.3.6.1.4.1.}" $file_FPC_Board_detailed_info | sed 's/.* = INTEGER.*: //')
  if [[ $FPC_Board_status_value -eq 2 ]];then
    status_value=$FPC_Board_status_value
    detailed_info_description
  else
    echo "FPC Board state abnormal"
    exit ${STATE_CRITICAL}
  fi
}

PIC_Board_detailed_info() {
  if [[ ! -f $file_PIC_Board_detailed_info || $(expr $current_timestamp - $(stat -c %Z $file_PIC_Board_detailed_info)) -gt 60 ]];then
    $snmpwalk_command -v $protocol_version -c $community $host_ip $switchboard_PIC_Board_detailed_info_oid 2>&1 >$file_PIC_Board_detailed_info
  fi
  PIC_Board_status_value=$(grep "${resources_specified_or_switchboard_interface_oid#1.3.6.1.4.1.}" $file_PIC_Board_detailed_info | sed 's/.* = INTEGER.*: //')
  if [[ $PIC_Board_status_value -eq 2 ]];then
    status_value=$PIC_Board_status_value
    detailed_info_description
  else
    echo "PIC Board state abnormal"
    exit ${STATE_CRITICAL}
  fi
}

routing_engine_detailed_info() {
  if [[ ! -f $file_routing_engine_detailed_info || $(expr $current_timestamp - $(stat -c %Z $file_routing_engine_detailed_info)) -gt 60 ]];then
    $snmpwalk_command -v $protocol_version -c $community $host_ip $switchboard_routing_engine_detailed_info_oid 2>&1 >$file_routing_engine_detailed_info
  fi
  routing_engine_status_value=$(grep "${resources_specified_or_switchboard_interface_oid#1.3.6.1.4.1.}" $file_routing_engine_detailed_info | sed 's/.* = INTEGER.*: //')
  if [[ $routing_engine_status_value -eq 2 || $routing_engine_status_value -eq 7 ]];then
    status_value=$routing_engine_status_value
    detailed_info_description
  else
    echo "Routing engine state abnormal"
    exit ${STATE_CRITICAL}
  fi
}

cpu_usage_detailed_info() {
  cpu_counter_record=/tmp/Juniper_switchboard_cpu.counter_record_${host_ip}_${resources_specified_or_switchboard_interface_oid#1.3.6.1.4.1.}
  if [[ ! -f $file_cpu_usage_detailed_info || $(expr $current_timestamp - $(stat -c %Z $file_cpu_usage_detailed_info)) -ge 60 ]];then
    $snmpwalk_command -v $protocol_version -c $community $host_ip $switchboard_cpu_usage_detailed_info_oid 2>&1 >$file_cpu_usage_detailed_info
  fi
  cpu_usage_status_value=$(grep "${resources_specified_or_switchboard_interface_oid#1.3.6.1.4.1.}" $file_cpu_usage_detailed_info | sed 's/.* = Gauge.*: //')
  echo $cpu_usage_status_value > /dev/null
  status_value=$cpu_usage_status_value
  if [[ $cpu_usage_status_value -ge $cpu_critical_threshold ]];then
    echo "CPU Usage percentage higher than ${cpu_critical_threshold}% -- Current: $status_value"
    exit ${STATE_CRITICAL}
  else
    detailed_info_description
  fi
}

memory_usage_detailed_info() {
  if [[ ! -f $file_memory_usage_detailed_info || $(expr $current_timestamp - $(stat -c %Z $file_memory_usage_detailed_info)) -gt 60 ]];then
    $snmpwalk_command -v $protocol_version -c $community $host_ip $switchboard_memory_usage_detailed_info_oid 2>&1 >$file_memory_usage_detailed_info
  fi
  memory_usage_status_value=$(grep "${resources_specified_or_switchboard_interface_oid#1.3.6.1.4.1.}" $file_memory_usage_detailed_info | sed 's/.* = Gauge.*: //')
  status_value=$memory_usage_status_value
  if [[ $memory_usage_status_value -ge $memory_buffer_critical_threshold ]];then
    echo "Memory Buffer Usage percentage higher than ${memory_buffer_critical_threshold}% -- Current: $status_value"
    exit ${STATE_CRITICAL}
  else
    detailed_info_description
  fi
}

detailed_info_description() {
  if [[ ! -f $file_detailed_description_info || $(expr $current_timestamp - $(stat -c %Z $file_detailed_description_info)) -gt 3600 ]];then
    $snmpwalk_command -v $protocol_version -c $community $host_ip $switchboard_detailed_description_info_oid 2>&1 >$file_detailed_description_info
  fi
  description_value_oid=$(echo $resources_specified_or_switchboard_interface_oid | sed 's/\(.*\.2636\.3\.1\.13\.1\.\)[0-9]\{1,\}\(\..*\)/\15\2/;s/.*\(\.2636.*\)/\1/')
  description_value=$(sed -n '/'''$description_value_oid'''/{s/.*= STRING: //;s/"//g;p}' $file_detailed_description_info)
  if [[ -z $description_value ]];then
    echo "State: $status_value"
    exit ${STATE_OK}
  else
    if [[ $resources_specified_or_switchboard_interface_oid == 1.3.6.1.4.1.2636.3.1.13.1.7.[79]* ]];then
      echo "$description_value temperature: $status_value"
      exit ${STATE_OK}
    elif [[ $resources_specified_or_switchboard_interface_oid == 1.3.6.1.4.1.2636.3.1.13.1.8.9* ]];then
      echo "$description_value CPU Gauge: $status_value"
      exit ${STATE_OK}
    elif [[ $resources_specified_or_switchboard_interface_oid == 1.3.6.1.4.1.2636.3.1.13.1.11.9* ]];then
      echo "$description_value Memory Buffer Gauge: $status_value"
      exit ${STATE_OK}
    else
      echo "$description_value state: $status_value"
      exit ${STATE_OK}
    fi
  fi
}

switchboard_interface_info() {
  switchboard_interface_state_value=$(grep "${resources_specified_or_switchboard_interface_oid#1.3.6.1.2.1.2.2.1.8.}" $file_interface_state_info | sed 's/.*: //')
  echo $switchboard_interface_state_value > /dev/null
  switchboard_interface_port_value=$(grep "${resources_specified_or_switchboard_interface_oid##*.}" $file_interface_port_info | sed 's/.*: //')
  echo $switchboard_interface_port_value > /dev/null
  switchboard_interface_description_value=$(grep "${resources_specified_or_switchboard_interface_oid##*.}" $file_interface_description_info | sed 's/.*: //')
  echo $switchboard_interface_description_value > /dev/null
  if [[ $switchboard_interface_state_value == up* ]];then
    if [[ -z $switchboard_interface_description_value ]];then
      echo "${switchboard_interface_port_value} state: ${switchboard_interface_state_value}"
      exit ${STATE_OK}
    else
      echo "${switchboard_interface_port_value}(${switchboard_interface_description_value}) state: ${switchboard_interface_state_value}"
      exit ${STATE_OK}
    fi
  else
    echo "${switchboard_interface_port_value} is down"
    exit ${STATE_CRITICAL}
  fi
}

file_age_switchboard_interface() {
  if [[ ! -f $file_interface_description_info || $(expr $current_timestamp - $(stat -c %Z $file_interface_description_info)) -ge 3600 ]];then
    $snmpwalk_command -v $protocol_version -c $community $host_ip $switchboard_interface_description_oid 2>&1 >$file_interface_description_info
  fi
  if [[ ! -f $file_interface_port_info || $(expr $current_timestamp - $(stat -c %Z $file_interface_port_info)) -ge 3600 ]];then
    $snmpwalk_command -v $protocol_version -c $community $host_ip $switchboard_interface_port_oid 2>&1 >$file_interface_port_info
  fi
  if [[ ! -f $file_interface_state_info || $(expr $current_timestamp - $(stat -c %Z $file_interface_state_info)) -gt 60 ]];then
    $snmpwalk_command -v $protocol_version -c $community $host_ip $switchboard_interface_state_oid 2>&1 >$file_interface_state_info
  fi
}

file_detailed_info=/tmp/Juniper_switchboard_detailed_info_${host_ip}
file_detailed_description_info=/tmp/Juniper_switchboard_detailed_description_info_${host_ip}
file_chassis_temp_detailed_info=/tmp/Juniper_switchboard_chassis_temp_detailed_info_${host_ip}
file_engine_temp_detailed_info=/tmp/Juniper_switchboard_engine_temp_detailed_info_${host_ip}
file_power_supply_detailed_info=/tmp/Juniper_switchboard_power_supply_detailed_info_${host_ip}
file_fan_state_detailed_info=/tmp/Juniper_switchboard_fan_state_detailed_info_${host_ip}
file_FPC_Board_detailed_info=/tmp/Juniper_switchboard_FPC_Board_detailed_info_${host_ip}
file_PIC_Board_detailed_info=/tmp/Juniper_switchboard_PIC_Board_detailed_info_${host_ip}
file_routing_engine_detailed_info=/tmp/Juniper_switchboard_routing_engine_detailed_info_${host_ip}
file_cpu_usage_detailed_info=/tmp/Juniper_switchboard_cpu_usage_detailed_info_${host_ip}
file_memory_usage_detailed_info=/tmp/Juniper_switchboard_memory_usage_detailed_info_${host_ip}

file_interface_description_info=/tmp/Juniper_switchboard_interface_description_info_${host_ip}
file_interface_port_info=/tmp/Juniper_switchboard_interface_port_info_${host_ip}
file_interface_state_info=/tmp/Juniper_switchboard_interface_state_info_${host_ip}

if [[ $resources_specified_or_switchboard_interface_oid == *.2636.* ]];then
  case $resources_specified_or_switchboard_interface_oid in
    1.3.6.1.4.1.2636.3.1.13.1.7.7*)
    chassis_temp_detailed_info;;
    1.3.6.1.4.1.2636.3.1.13.1.7.9*)
    engine_temp_detailed_info;;
    1.3.6.1.4.1.2636.3.1.13.1.6.2*)
    power_supply_detailed_info;;
    1.3.6.1.4.1.2636.3.1.13.1.6.4*)
    fan_state_detailed_info;;
    1.3.6.1.4.1.2636.3.1.13.1.6.7*)
    FPC_Board_detailed_info;;
    1.3.6.1.4.1.2636.3.1.13.1.6.8*)
    PIC_Board_detailed_info;;
    1.3.6.1.4.1.2636.3.1.13.1.6.9*)
    routing_engine_detailed_info;;
    1.3.6.1.4.1.2636.3.1.13.1.8.9*)
    cpu_usage_detailed_info;;
    1.3.6.1.4.1.2636.3.1.13.1.11.9*)
    memory_usage_detailed_info;;
    *)
    exit ${STATE_UNKNOWN};;
  esac
elif [[ $resources_specified_or_switchboard_interface_oid == 1.3.6.1.2.1* ]];then
  file_age_switchboard_interface
  switchboard_interface_info
else
  exit ${STATE_CRITICAL}
fi
