```bash
#!/bin/sh
# Этот скрипт устанавливает TorrServer на OpenWRT.

# Каталог для TorrServer
dir="/opt/torrserver"
binary="${dir}/torrserver"
init_script="/etc/init.d/torrserver"
fallback_path="/mnt/sda2/torrserver"

# Функция для обработки аргументов командной строки
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --path)
                shift
                input_path="$1"
                ;;
            *)
                echo "Неизвестный аргумент: $1"
                exit 1
                ;;
        esac
        shift
    done
}

# Функция для создания файла авторизации
create_auth_file() {
    auth_file="${torrserver_path}/accs.db"
    echo "Введите логин для TorrServer:"
    read -r username
    if [ -z "$username" ]; then
        echo "Логин не введен. Авторизация не будет настроена."
        return 1
    fi
    echo "Введите пароль для TorrServer:"
    read -r password
    if [ -z "$password" ]; then
        echo "Пароль не введен. Авторизация не будет настроена."
        return 1
    fi
    # Создаем файл авторизации в формате JSON
    printf "{\"${username}\":\"${password}\"}" > "${auth_file}" || { echo "Ошибка создания файла авторизации ${auth_file}"; exit 1; }
    chmod 600 "${auth_file}"
    echo "Файл авторизации ${auth_file} успешно создан."
    return 0
}

# Функция для проверки и создания директорий
check_and_create_dirs() {
    # Проверяем, был ли указан путь через аргумент --path
    if [ -n "$input_path" ]; then
        torrserver_path="$input_path"
        log_path="${input_path}/torrserver.log"
        echo "Используется путь из аргумента: ${torrserver_path}"
    # Проверяем, является ли выполнение интерактивным
    elif tty >/dev/null 2>&1 && [ -t 0 ]; then
        echo "Введите путь для каталога TorrServer (например, /mnt/sda2/torrserver) или нажмите Enter для использования стандартного пути (${dir}):"
        read -r input_path
        if [ -z "$input_path" ]; then
            torrserver_path="${dir}"
            log_path="/tmp/log/torrserver/torrserver.log"
            echo "Используется стандартный путь: ${torrserver_path}"
        else
            torrserver_path="${input_path}"
            log_path="${input_path}/torrserver.log"
        fi
    else
        echo "Неинтерактивный режим. Используется запасной путь: ${fallback_path}"
        torrserver_path="${fallback_path}"
        log_path="${fallback_path}/torrserver.log"
    fi

    # Проверяем наличие каталога
    if [ -d "${torrserver_path}" ]; then
        echo "Каталог ${torrserver_path} уже существует."
    else
        echo "Каталог ${torrserver_path} не существует."
        # В неинтерактивном режиме или при использовании --path автоматически создаем каталог
        if [ -n "$input_path" ] || ! tty >/dev/null 2>&1 || [ ! -t 0 ]; then
            mkdir -p "${torrserver_path}" || { echo "Ошибка создания каталога ${torrserver_path}"; exit 1; }
            echo "Каталог ${torrserver_path} автоматически создан."
        else
            echo "Хотите создать каталог ${torrserver_path}? (y/n)"
            read -r response
            if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
                mkdir -p "${torrserver_path}" || { echo "Ошибка создания каталога ${torrserver_path}"; exit 1; }
                echo "Каталог ${torrserver_path} успешно создан."
            else
                echo "Каталог не создан. Используется стандартный путь: ${dir}"
                torrserver_path="${dir}"
                log_path="/tmp/log/torrserver/torrserver.log"
            fi
        fi
    fi
}

# Функция для установки TorrServer
install_torrserver() {
    # Проверяем, установлен ли TorrServer
    if [ -f "${binary}" ]; then
        echo "TorrServer уже установлен в ${binary}."
        echo "Для удаления используйте: $0 -s -- --remove"
        exit 0
    fi

    # Создаем каталог для TorrServer
    mkdir -p ${dir}

    # Определяем архитектуру системы
    echo "Проверяем архитектуру..."
    architecture=""
    case $(uname -m) in
        x86_64) architecture="amd64" ;;
        i*86) architecture="386" ;;
        armv7*) architecture="arm7" ;;
        armv5*) architecture="arm5" ;;
        aarch64) architecture="arm64" ;;
        mips) architecture="mips" ;;
        mips64) architecture="mips64" ;;
        mips64el) architecture="mips64le" ;;
        mipsel) architecture="mipsle" ;;
        *) echo "Архитектура не поддерживается"; exit 1 ;;
    esac

    # Загружаем TorrServer
    url="https://github.com/YouROK/TorrServer/releases/latest/download/TorrServer-linux-${architecture}"
    echo "Загружаем TorrServer для ${architecture}..."
    wget -O ${binary} ${url} || { echo "Ошибка загрузки TorrServer"; exit 1; }
    chmod +x ${binary}

    # Проверяем, установлен ли UPX
    if command -v upx > /dev/null 2>&1; then
        echo "UPX уже установлен."
        # Сжимаем бинарный файл с помощью UPX
        echo "Сжимаем бинарный файл TorrServer с использованием UPX..."
        if upx --lzma ${binary}; then
            echo "Бинарный файл TorrServer успешно сжат."
        else
            echo "Ошибка сжатия TorrServer. Продолжаем установку без сжатия."
        fi
    else
        echo "UPX не установлен. Пытаемся установить UPX..."
        if opkg update && opkg install upx; then
            echo "UPX успешно установлен."
            # Сжимаем бинарный файл с помощью UPX
            echo "Сжимаем бинарный файл TorrServer с использованием UPX..."
            if upx --lzma ${binary}; then
                echo "Бинарный файл TorrServer успешно сжат."
            else
                echo "Ошибка сжатия TorrServer. Продолжаем установку без сжатия."
            fi
        else
            echo "Не удалось установить UPX. Продолжаем установку без сжатия."
        fi
    fi

    # Проверяем и создаем директории
    check_and_create_dirs

    # Проверяем интерактивность для настройки авторизации
    httpauth=""
    if tty >/dev/null 2>&1 && [ -t 0 ]; then
        echo "Настроить HTTP-авторизацию для TorrServer? (y/n)"
        read -r auth_response
        if [ "$auth_response" = "y" ] || [ "$auth_response" = "Y" ]; then
            if create_auth_file; then
                httpauth="--httpauth"
            fi
        fi
    fi

    # Создаем скрипт init.d для управления службой
    cat << EOF > ${init_script}
#!/bin/sh /etc/rc.common
# Скрипт запуска Torrent сервера

START=95
STOP=10
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command ${binary} \
        -d ${dir} \
        -p 8090 \
        --path ${torrserver_path} \
        --logpath ${log_path} \
        ${httpauth}
    procd_set_param respawn
    procd_set_param respawn_threshold 3600 5 5  # Перезапуск до 5 раз в час
    procd_set_param respawn_timeout 5          # Таймаут 5 сек
    procd_close_instance
}
EOF

    # Делаем скрипт init.d исполняемым и запускаем службу
    chmod +x ${init_script}
    ${init_script} enable
    ${init_script} start

    echo "TorrServer успешно установлен и запущен."
}

# Функция для удаления TorrServer
remove_torrserver() {
    # Останавливаем службу, если она запущена
    if [ -f "${init_script}" ]; then
        ${init_script} stop
        ${init_script} disable
    fi

    # Удаляем файлы TorrServer
    if [ -f "${binary}" ]; then
        rm -f ${binary}
        echo "Удален бинарный файл TorrServer: ${binary}"
    fi

    if [ -d "${dir}" ]; then
        rm -rf ${dir}
        echo "Удален каталог TorrServer: ${dir}"
    fi

    if [ -f "${init_script}" ]; then
        rm -f ${init_script}
        echo "Удален init.d скрипт: ${init_script}"
    fi

    # Удаляем каталог torrserver и файл авторизации, если они существуют
    if [ -n "${torrserver_path}" ] && [ -d "${torrserver_path}" ] && [ "${torrserver_path}" != "${dir}" ]; then
        if [ -f "${torrserver_path}/accs.db" ]; then
            rm -f "${torrserver_path}/accs.db"
            echo "Удален файл авторизации: ${torrserver_path}/accs.db"
        fi
        rm -rf "${torrserver_path}"
        echo "Удален каталог TorrServer: ${torrserver_path}"
    fi

    echo "TorrServer успешно удален."
}

# Основная логика скрипта
case "$1" in
    --remove|-r)
        remove_torrserver
        ;;
    *)
        parse_args "$@"
        install_torrserver
        ;;
esac
```
