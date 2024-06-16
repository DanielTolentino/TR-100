#!/bin/bash
# TR-100 Machine Report
# Copyright © 2024, U.S. Graphics, LLC. BSD-3-Clause License.

export LC_NUMERIC=C

# Basic configuration, change as needed
report_title="UNITED STATES GRAPHICS COMPANY"
#zfs_filesystem="zroot/ROOT/os"

# Utilities
bar_graph() {
    local percent
    local num_blocks
    local width=29
    local graph=""
    local used=$1
    local total=$2

    percent=$(echo "scale=2; $used / $total * 100" | bc)
    num_blocks=$(printf "%.0f" $(echo "scale=2; ($percent / 100) * $width" | bc))
    
    for ((i = 0; i < num_blocks; i++)); do
        graph+="█"
    done
    for ((i = num_blocks; i < width; i++)); do
        graph+="░"
    done
    printf "%s" "${graph}"
}


# Operating System Information
source /etc/os-release
os_name="${PRETTY_NAME^} ${VERSION_CODENAME}"

#os_name="${ID^} $(cat /etc/lsb-release) ${DISTRIB_CODENAME^}"
os_kernel=$({
	uname
	uname -r
} | tr '\n' ' ')

# Network Information
net_current_user=$(whoami)
net_hostname=$(hostname -f)
net_machine_ip=$(hostname -I | awk '{print $2}')
#net_client_ip=$(who am i --ips | awk '{print $5}')
net_dns_ips=()
while read -r line; do
	ip=$(echo "$line" | awk '{print $2}')
	net_dns_ips+=("$ip")
done < <(grep 'nameserver' /etc/resolv.conf)

# CPU Information
cpu_model="$(lscpu | grep 'Nome do modelo' | grep -v 'BIOS' | cut -f 2 -d ':' | awk '{print $1 " "  $2 " " $3}')"
cpu_hypervisor="$(lscpu | grep 'Hypervisor vendor' | cut -f 2 -d ':' | awk '{$1=$1}1')"
cpu_cores="$(nproc --all)"
cpu_cores_per_socket="$(lscpu | grep 'Núcleo(s) por soquete' | cut -f 2 -d ':' | awk '{$1=$1}1')"
cpu_sockets="$(lscpu | grep 'Soquete(s)' | cut -f 2 -d ':' | awk '{$1=$1}1')"
cpu_freq="$(grep 'cpu MHz' /proc/cpuinfo | cut -f 2 -d ':' | awk 'NR==1' | awk '{$1=$1/1000}1' | numfmt --format="%.2f")"

load_avg_1min=$(uptime | awk -F'load average: ' '{print $2}' | cut -d ',' -f1 | tr -d ' ')
load_avg_5min=$(uptime | awk -F'load average: ' '{print $2}' | cut -d ',' -f2 | tr -d ' ')
load_avg_15min=$(uptime | awk -F'load average: ' '{print $2}' | cut -d ',' -f3 | tr -d ' ')

cpu_1min_bar_graph=$(bar_graph "$load_avg_1min" "$cpu_cores")
#cpu_5min_bar_graph=$(bar_graph "$load_avg_5min" "$cpu_cores")
cpu_15min_bar_graph=$(bar_graph "$load_avg_15min" "$cpu_cores")

# Memory Information
mem_total=$(grep 'MemTotal' /proc/meminfo | awk '{print $2}')
mem_available=$(grep 'MemAvailable' /proc/meminfo | awk '{print $2}')
mem_used=$((mem_total - mem_available))
mem_percent=$(echo "$mem_used / $mem_total * 100" | bc -l)
mem_percent=$(printf "%.0f" "$mem_percent")
mem_total_gb=$(echo "$mem_total" | numfmt --from-unit=Ki --to-unit=Gi --format %.2f)
mem_used_gb=$(echo "$mem_used" | numfmt --from-unit=Ki --to-unit=Gi --format %.2f)
mem_bar_graph=$(bar_graph "$mem_used" "$mem_total")

# Disk Information
disk_info=($(df -h / | awk 'NR==2 {print $2, $3, $4, $5}'))
disk_total="${disk_info[0]}"
disk_used="${disk_info[1]}"
disk_available="${disk_info[2]}"
disk_usage="${disk_info[3]}"
disk_bar_graph=$(bar_graph "$disk_used" "$disk_total")

# Last login and Uptime
last_login=$(lastlog -u root)
last_login_ip=$(echo "$last_login" | awk 'NR==2 {print $3}')
last_login_time=$(echo "$last_login" | awk 'NR==2 {print $5, $6, $7, $8, $9}')
last_login_formatted_time=$(date -d "$last_login_time" "+%b %-d %Y %T")
sys_uptime=$(uptime -p | sed 's/up\s*//; s/\s*day\(s*\)/d/; s/\s*hour\(s*\)/h/; s/\s*minute\(s*\)/m/')

# Machine Report
printf "┌┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┬┐\n"
printf "├┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┴┤\n"
printf "│       %s       │\n" "$report_title"
printf "│            TR-100 MACHINE REPORT           │\n"
printf "├────────────┬───────────────────────────────┤\n"
printf "│ %-10s │ %-29s │\n" "OS" "$os_name"
printf "│ %-10s │ %-29s │\n" "KERNEL" "$os_kernel"
printf "├────────────┼───────────────────────────────┤\n"
printf "│ %-10s │ %-29s │\n" "HOSTNAME" "$net_hostname"
printf "│ %-10s │ %-29s │\n" "MACHINE IP" "$net_machine_ip"
printf "│ %-10s │ %-29s │\n" "CLIENT  IP" "$net_client_ip"
dns_ip_count=${#net_dns_ips[@]}
if [ "$dns_ip_count" -eq 1 ]; then
	printf "│ %-10s │ %-29s │\n" "DNS     IP" "${net_dns_ips[0]}"
else
	for ((i = 0; i < $dns_ip_count; i++)); do
		if [ "$i" -eq 0 ]; then
			printf "│ %-10s │ %-29s │\n" "DNS IP/s 1" "${net_dns_ips[$i]}"
		else
			printf "│ %-10s │ %-29s │\n" "         $((i + 1))" "${net_dns_ips[$i]}"
		fi
	done
fi
printf "│ %-10s │ %-29s │\n" "USER" "$net_current_user"
printf "├────────────┼───────────────────────────────┤\n"
printf "│ %-10s │ %-29s │\n" "PROCESSOR" "$cpu_model"
printf "│ %-10s │ %-29s │\n" "CORES" "$cpu_cores_per_socket vCPU(s) / $cpu_sockets Socket(s)"
printf "│ %-10s │ %-29s │\n" "HYPERVISOR" "$cpu_hypervisor"
printf "│ %-10s │ %-29s │\n" "CPU FREQ" "$cpu_freq GHz"
printf "│ %-10s │ %-29s │\n" "LOAD  1m" "$cpu_1min_bar_graph"
printf "│ %-10s │ %-29s │\n" "LOAD 15m" "$cpu_15min_bar_graph"
printf "├────────────┼───────────────────────────────┤\n"
printf "│ %-10s │ %-29s │\n" "VOLUME" "$disk_total $disk_used $disk_available [$disk_usage]"
printf "│ %-10s │ %-29s │\n" "DISK USAGE" "$disk_bar_graph"
printf "├────────────┼───────────────────────────────┤\n"
printf "│ %-10s │ %-29s │\n" "MEMORY" "${mem_used_gb}/${mem_total_gb} GiB [${mem_percent}%]"
printf "│ %-10s │ %-29s │\n" "USAGE" "${mem_bar_graph}"
printf "├────────────┼───────────────────────────────┤\n"
printf "│ %-10s │ %-29s │\n" "LAST LOGIN" "$last_login_formatted_time"
printf "│ %-10s │ %-29s │\n" "" "$last_login_ip"
printf "│ %-10s │ %-29s │\n" "UPTIME" "$sys_uptime"
printf "└────────────┴───────────────────────────────┘\n"
