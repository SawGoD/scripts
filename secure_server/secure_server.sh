#!/bin/bash

set -e

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
PINK='\033[0;35m'    # заменили синий на розовый
YELLOW='\033[1;33m'
CYAN='\033[0;36m'    # для выделения переменных
NC='\033[0m' # No Color

# Функция проверки порта на занятость
function check_port() {
    local port=$1
    if ss -tuln | grep -q ":$port "; then
        return 1  # занят
    else
        return 0  # свободен
    fi
}

# 🔍 Проверка существующего бэкапа
if [[ -f "/etc/ssh/sshd_config.bak" ]]; then
    echo -e "${PINK}🔍 Найден существующий бэкап SSH конфигурации: ${CYAN}/etc/ssh/sshd_config.bak${NC}"
    echo -e "   ${PINK}Дата создания: ${CYAN}$(stat -c %y /etc/ssh/sshd_config.bak)${NC}"
    echo ""
    read -p "🔄 Восстановить SSH конфигурацию из бэкапа? (Y/n): " restore_choice
    
    if [[ "$restore_choice" =~ ^[Yy]$ ]] || [[ -z "$restore_choice" ]]; then
        echo -e "${PINK}🔄 Восстанавливаем конфигурацию из бэкапа...${NC}"
        cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
        systemctl restart ssh
        echo -e "${GREEN}✅ SSH конфигурация восстановлена из бэкапа${NC}"
        echo -e "${GREEN}🔐 SSH снова работает на стандартном порту ${CYAN}22${NC}"
        echo -e "${PINK}Для подключения используйте: ${CYAN}ssh root@<твой-сервер>${NC}"
        exit 0
    else
        echo -e "${PINK}Продолжаем с текущей конфигурацией...${NC}"
    fi
    echo ""
fi

# Ввод IP для whitelist
echo -e "${PINK}🔐 Введите IP-адреса, которым разрешён доступ по SSH (через запятую).${NC}"
echo -e "   ${PINK}Если хотите разрешить доступ всем — введите ${CYAN}'n'${NC} и нажмите Enter.${NC}"

read -p "IP-адреса: " input_ips

if [[ "$input_ips" == "n" || -z "$input_ips" ]]; then
    echo -e "${YELLOW}⚠️  Доступ к SSH будет открыт для всех IP${NC}"
    whitelist_mode="any"
else
    IFS=',' read -ra ip_array <<< "$input_ips"
    whitelist_mode="custom"
fi

# Выбор SSH-порта
while true; do
    read -p "Введите желаемый SSH-порт: " ssh_port

    if [[ ! "$ssh_port" =~ ^[0-9]+$ ]] || [ "$ssh_port" -lt 1 ] || [ "$ssh_port" -gt 65535 ]; then
        echo -e "${RED}❌ Недопустимый порт. Введите число от 1 до 65535.${NC}"
        continue
    fi

    if check_port "$ssh_port"; then
        echo -e "${GREEN}✅ Порт $ssh_port свободен.${NC}"
        break
    else
        echo -e "${RED}❌ Порт $ssh_port уже занят. Введите другой.${NC}"
    fi
done

# Выбор дополнительных портов
echo ""
echo -e "${PINK}Хотите открыть дополнительные порты?${NC}"
echo -e "   ${PINK}${CYAN}80${NC}   (HTTP) - для веб-сайтов${NC}"
echo -e "   ${PINK}${CYAN}443${NC}  (HTTPS/VPN) - для веб-сайтов и VPN${NC}"
echo -e "   ${PINK}${CYAN}1080${NC} (SOCKS) - для SOCKS прокси${NC}"
echo ""

read -p "Открыть порт 80 (HTTP)? (y/N): " open_port_80
read -p "Открыть порт 443 (HTTPS/VPN)? (Y/n): " open_port_443
read -p "Открыть порт 1080 (SOCKS)? (y/N): " open_port_1080

# Настройка по умолчанию для 443 - да, для остальных - нет
if [[ -z "$open_port_443" ]] || [[ "$open_port_443" =~ ^[Yy]$ ]]; then
    open_port_443="yes"
else
    open_port_443="no"
fi

if [[ "$open_port_80" =~ ^[Yy]$ ]]; then
    open_port_80="yes"
else
    open_port_80="no"
fi

if [[ "$open_port_1080" =~ ^[Yy]$ ]]; then
    open_port_1080="yes"
else
    open_port_1080="no"
fi

if [[ "$open_port_80" == "yes" ]]; then
    echo -e "${GREEN}✅ Будет открыт порт ${CYAN}80${NC} (HTTP)${NC}"
fi
if [[ "$open_port_443" == "yes" ]]; then
    echo -e "${GREEN}✅ Будет открыт порт ${CYAN}443${NC} (HTTPS/VPN)${NC}"
fi
if [[ "$open_port_1080" == "yes" ]]; then
    echo -e "${GREEN}✅ Будет открыт порт ${CYAN}1080${NC} (SOCKS)${NC}"
fi

# Бэкап SSH-конфига
echo -e "${PINK}Делаем бэкап ${CYAN}/etc/ssh/sshd_config${NC} → ${CYAN}/etc/ssh/sshd_config.bak${NC}"
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Меняем порт SSH
sed -i "s/^#\?Port .*/Port $ssh_port/" /etc/ssh/sshd_config
systemctl restart ssh
echo -e "${GREEN}✅ SSH теперь слушает порт ${CYAN}$ssh_port${NC}"

# 🔥 Настройка iptables
echo -e "${PINK}🔥 Настраиваем iptables...${NC}"

# Очистить текущие правила
iptables -F
iptables -X

# Политики по умолчанию
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Разрешить loopback и установленные соединения
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# ✅ SSH-доступ по whitelist
if [[ "$whitelist_mode" == "any" ]]; then
    iptables -A INPUT -p tcp --dport "$ssh_port" -j ACCEPT
else
    for ip in "${ip_array[@]}"; do
        trimmed_ip=$(echo "$ip" | xargs)
        iptables -A INPUT -p tcp -s "$trimmed_ip" --dport "$ssh_port" -j ACCEPT
        echo -e "   ${GREEN}🔓 Разрешён доступ по SSH с ${CYAN}$trimmed_ip${NC}"
    done
fi

# Открытие дополнительных портов
if [[ "$open_port_80" == "yes" ]]; then
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    echo -e "   ${GREEN}🔓 Разрешён порт ${CYAN}80${NC} (HTTP)${NC}"
fi

if [[ "$open_port_443" == "yes" ]]; then
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    echo -e "   ${GREEN}🔓 Разрешён порт ${CYAN}443${NC} (HTTPS/VPN)${NC}"
fi

if [[ "$open_port_1080" == "yes" ]]; then
    iptables -A INPUT -p tcp --dport 1080 -j ACCEPT
    echo -e "   ${GREEN}🔓 Разрешён порт ${CYAN}1080${NC} (SOCKS)${NC}"
fi

# Защита от сканеров
iptables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP

# Установка и сохранение iptables
echo -e "${PINK}Сохраняем правила...${NC}"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
netfilter-persistent save

echo
echo -e "${GREEN}✅ Всё готово!${NC}"
echo -e "${GREEN}🔐 Подключение по SSH теперь через порт: ${CYAN}$ssh_port${NC}"
if [[ "$whitelist_mode" == "custom" ]]; then
    echo -e "${PINK}Разрешён доступ только с указанных IP:${NC}"
    for ip in "${ip_array[@]}"; do
        echo -e "   ${PINK}- ${CYAN}$(echo "$ip" | xargs)${NC}"
    done
else
    echo -e "${YELLOW}SSH доступен с любого IP-адреса${NC}"
fi

# Показываем какие порты открыты
echo -e "${PINK}Открытые порты:${NC}"
echo -e "   ${GREEN}- ${CYAN}$ssh_port${NC} (SSH)${NC}"
if [[ "$open_port_80" == "yes" ]]; then
    echo -e "   ${GREEN}- ${CYAN}80${NC} (HTTP)${NC}"
fi
if [[ "$open_port_443" == "yes" ]]; then
    echo -e "   ${GREEN}- ${CYAN}443${NC} (HTTPS/VPN)${NC}"
fi
if [[ "$open_port_1080" == "yes" ]]; then
    echo -e "   ${GREEN}- ${CYAN}1080${NC} (SOCKS)${NC}"
fi

echo ""
echo -e "${PINK}Используй:${NC}"
echo -e "    ${CYAN}ssh -p $ssh_port root@<твой-сервер>${NC}"
