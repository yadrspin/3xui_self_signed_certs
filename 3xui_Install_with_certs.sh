#!/bin/bash

# Press Enter
wait_for_enter() {
    echo -e "\nНажмите [Enter], чтобы продолжить..."
    read -r
}

# 1. root checking
if [ "$EUID" -ne 0 ]; then
  echo "Ошибка: Запустите скрипт через sudo!"
  exit 1
fi

# 2. if 3xui already installed
if [ -f "/usr/local/x-ui/x-ui" ]; then
    clear
echo "------------------------------------------------------------------------------"
echo "Done:"
echo "------------------------------------------------------------------------------"
echo -e "username: \e[1m${USER_EXT}\e[0m"
echo -e "password:           \e[1m${PASS_EXT}\e[0m"
echo -e "port:             \e[33m${PORT_EXT}\e[0m"
echo -e "path to panel:      /${PATH_CLEAN}/"
echo -e "link : \e[32m\e[4m${URL_EXT}\e[0m"
echo "----------------------------------------------------------------------------"
echo ""
echo -e "\e[1;36m Cert Info:\e[0m"
echo "Сертификаты автоматически генерируются самой панелью на 6 дней"
echo "и затем автоматически продлеваются каждые 6 дней."
echo ""
echo "Ничего вручную прописывать не нужно — сертификаты"
echo "уже автоматически прописаны в саму панель."
echo ""
    exit 0
fi

# 3. Установка зависимостей
echo "--- Подготовка системы (sqlite3, expect, qrencode) ---"
apt-get update && apt-get install -y expect qrencode curl sqlite3
sleep 1

echo "--- Установка 3x-ui ---"
LOG_FILE="/tmp/3x_ui_install.log"
> "$LOG_FILE"

# 4. Установка через Expect (имитация ручного ввода с паузами)
expect <<EOF | tee $LOG_FILE
set timeout -1
spawn bash -c "curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh | bash"

expect "Confirm the installation"
sleep 1
send "y\r"

expect "customize the Panel Port settings"
sleep 1
send "n\r"

expect "Choose an option"
sleep 1
send "2\r"

expect "Port to use for ACME"
sleep 1
send "\r"

expect eof
EOF

echo -e "\n--- Обработка данных (пауза 2 сек) ---"
sleep 2

# --- ИЗВЛЕЧЕНИЕ ДАННЫХ (БАЗА ДАННЫХ + ЛОГ) ---
DB_PATH="/etc/x-ui/x-ui.db"

# Сначала пробуем достать из базы данных
if [ -f "$DB_PATH" ]; then
    USER_EXT=$(sqlite3 "$DB_PATH" "SELECT value FROM settings WHERE key='username';" 2>/dev/null)
    PASS_EXT=$(sqlite3 "$DB_PATH" "SELECT value FROM settings WHERE key='password';" 2>/dev/null)
    PORT_EXT=$(sqlite3 "$DB_PATH" "SELECT value FROM settings WHERE key='port';" 2>/dev/null)
    PATH_EXT=$(sqlite3 "$DB_PATH" "SELECT value FROM settings WHERE key='webBasePath';" 2>/dev/null)
fi

# Если в базе пусто (например, файл еще не создался), вытаскиваем из лога установки
if [[ -z "$USER_EXT" ]] || [[ -z "$PASS_EXT" ]]; then
    USER_EXT=$(grep "Username:" $LOG_FILE | tail -1 | awk '{print $NF}' | tr -d '\r')
    PASS_EXT=$(grep "Password:" $LOG_FILE | tail -1 | awk '{print $NF}' | tr -d '\r')
fi

if [[ ! "$PORT_EXT" =~ ^[0-9]+$ ]]; then
    PORT_EXT=$(grep -E "Port:[[:space:]]+[0-9]+" $LOG_FILE | tail -1 | awk '{print $NF}' | tr -d '\r')
fi

if [[ -z "$PATH_EXT" ]]; then
    PATH_EXT=$(grep "WebBasePath:" $LOG_FILE | tail -1 | awk '{print $NF}' | tr -d '\r')
fi

# Формирование ссылки
IP_EXT=$(curl -s ifconfig.me)
PATH_CLEAN=$(echo "$PATH_EXT" | tr -d '"/' )
URL_EXT="https://${IP_EXT}:${PORT_EXT}/${PATH_CLEAN}/"

rm -f $LOG_FILE

# --- ВЫВОД ДАННЫХ ПАНЕЛИ ---
clear
echo "------------------------------------------------------------------------------"
echo "Done:"
echo "------------------------------------------------------------------------------"
echo -e "username: \e[1m${USER_EXT}\e[0m"
echo -e "password:           \e[1m${PASS_EXT}\e[0m"
echo -e "port:             \e[33m${PORT_EXT}\e[0m"
echo -e "path to panel:      /${PATH_CLEAN}/"
echo -e "link : \e[32m\e[4m${URL_EXT}\e[0m"
echo "----------------------------------------------------------------------------"
echo ""
echo -e "\e[1;36m Cert Info:\e[0m"
echo "Сертификаты автоматически генерируются самой панелью на 6 дней"
echo "и затем автоматически продлеваются каждые 6 дней."
echo ""
echo "Ничего вручную прописывать не нужно — сертификаты"
echo "уже автоматически прописаны в саму панель."
echo ""

wait_for_enter
