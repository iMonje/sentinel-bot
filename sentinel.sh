#!/usr/bin/env bash

# =================================================================
# SENTINELBOT - El reporte que nadie pidió pero todos necesitan.
# Bitácora del Sysadmin: "Si esto falla, probablemente el servidor 
# esté ardiendo o el ISP ha decidido que hoy no es tu día".
# =================================================================

# --- Cargar Secretos (Porque no queremos que internet nos robe el bot) ---
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$DIR/.env" ]]; then
    source "$DIR/.env"
else
    echo "⚠️ Error: No encuentro el archivo .env con el TOKEN y CHAT_ID."
    echo "Soy un centinela, no un adivino."
    exit 1
fi

# --- Verificación de Conexión ---
intentos=0
while ! curl -s --connect-timeout 5 https://google.com > /dev/null; do
    if [ $intentos -gt 12 ]; then
        echo "💀 Error: No hay internet tras 1 minuto. Me rindo."
        exit 1
    fi
    ((intentos++))
    sleep 5
done

# --- Recopilar información ---
HOSTNAME=$(hostname)
IP_PRIVADA=$(hostname -I | awk '{print $1}')
IP_PUBLICA=$(curl -s --connect-timeout 10 ifconfig.me || echo "Inalcanzable")
FECHA_HORA=$(date '+%Y-%m-%d %H:%M:%S')

# CPU: Aritmética interna de Bash para evitar 'bc'
CPU_LOAD=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}' | cut -d. -f1)
MEM_USED=$(free -m | awk '/Mem:/ {print $3}')
MEM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
MEM_PERC=$((MEM_USED * 100 / MEM_TOTAL))

# Disco (Raíz)
DISK_PERC=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
DISK_INFO=$(df -h / | awk 'NR==2 {print $3 "/" $2}')

# Temperatura (Con fallback por si no hay sensores)
TEMP_RAW=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
[ -z "$TEMP_RAW" ] && TEMP="N/A" || TEMP="$((TEMP_RAW / 1000))°C"

UPDATES=$(apt list --upgradable 2>/dev/null | grep -v Listing | wc -l)
UPTIME=$(uptime -p | sed 's/^up //')
LAST_BOOT=$(who -b | awk '{print $3" "$4}')

# --- Funciones de Semáforo (Lógica minimalista) ---
get_emoji() {
    local val=$1
    if [ "$val" -lt 50 ]; then echo "🟢";
    elif [ "$val" -lt 85 ]; then echo "🟡";
    else echo "🔴"; fi
}

# --- Construir mensaje tipo mini-dashboard ---

MSG="<pre>
🖥 Host:            <code>$HOSTNAME</code>
🪪 IP Privada:      <code>$IP_PRIVADA</code>
🌐 IP Pública:      <code>$IP_PUBLICA</code>
⏰ Hora:            <code>$FECHA_HORA</code>
⏳ Último reinicio: <code>$LAST_BOOT</code>
⏱️ Uptime:          <code>$UPTIME</code>
💾 Memoria:         $(get_emoji $MEM_PERC) <code>$MEM_USED/${MEM_TOTAL}MB</code>
🖥 CPU:             $(get_emoji $CPU_LOAD) <code>$CPU_LOAD%</code>
📂 Disco:           $(get_emoji $DISK_PERC) <code>$DISK_INFO ($DISK_PERC%)</code>
🔄 Actualizaciones: <code>$UPDATES</code>
🌡️ Temperatura:     <code>$TEMP°C</code>
</pre>"

# --- Envío a Telegram ---
curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
     -d chat_id="$CHAT_ID" \
     -d parse_mode=HTML \
     -d text="$MSG" > /dev/null

# Bitácora: Misión cumplida. Vuelvo a mi letargo.