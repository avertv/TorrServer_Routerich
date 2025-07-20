# Этот скрипт устанавливает TorrServer на OpenWRT.

# Каталог для TorrServer
dir="/opt/torrserver"
binary="${dir}/torrserver"
init_script="/etc/init.d/torrserver"
default_path="/opt/torrserver"  # Значение по умолчанию для пути
upx_binary="${dir}/upx"

# Отладочная информация
echo "DEBUG: Запуск скрипта в интерпретаторе: $SHELL"
echo "DEBUG: Проверка кодировки..."
file -bi "$0" 2>/dev/null || echo "DEBUG: Не удалось проверить кодировку"

# Функция для обработки аргументов командной строки
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --path)
                shift
                input_path="$1"
                ;;
            --auth)
                shift
                auth_credentials="$1"
                ;;
            --remove|-r)
                remove_mode=1
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
    if [ -n "$auth_credentials" ]; then
        username=$(echo "$auth_credentials" | cut -d':' -f1)
        password=$(echo "$auth_credentials" | cut -d':' -f2)
        if [ -z "$username" ] || [ -z "$password" ]; then
            echo "Ошибка: Укажите логин и пароль в формате username:password с --auth."
            return 1
        fi
    else
        echo "Введите логин для TorrServer:"
        read -t 30 username
        if [ -z "$username" ]; then
            echo "Логин не введен. Авторизация не будет настроена."
            return 1
        fi
        echo "Введите пароль для TorrServer:"
        read -t 30 password
        if [ -z "$password" ]; then
            echo "Пароль не введен. Авторизация не будет настроена."
            return 1
        fi
    fi
    # Создаем файл авторизации в формате JSON
    echo "{\"$username\":\"$password\"}" > "$auth_file" || { echo "Ошибка создания файла авторизации $auth_file"; exit 1; }
    chmod 600 "$auth_file"
    echo "DEBUG: Файл авторизации $auth_file успешно создан."
    return 0
}

# Функция для проверки и создания директорий
check_and_create_dirs() {
    # Проверяем, был ли указан путь через аргумент --path
    if [ -n "$input_path" ]; then
        torrserver_path="$input_path"
        log_path="${input_path}/torrserver.log"
        echo "DEBUG: Используется путь из аргумента: $torrserver_path"
    # Используем значение по умолчанию или интерактивный ввод
    elif [ -z "$remove_mode" ]; then
        echo "Введите путь для каталога TorrServer (например, /mnt/sda2/torrserver) или нажмите Enter для использования стандартного пути ($default_path):"
        read -t 30 input_path
        if [ -z "$input_path" ]; then
            torrserver_path="$default_path"
            log_path="${default_path}/torrserver.log"
            echo "DEBUG: Используется стандартный путь: $torrserver_path"
        else
            torrserver_path="$input_path"
            log_path="${input_path}/torrserver.log"
        fi
    else
        echo "DEBUG: Неинтерактивный режим. Используется запасной путь: $default_path"
        torrserver_path="$default_path"
        log_path="${default_path}/torrserver.log"
    fi

    # Проверяем наличие каталога
    if [ -d "$torrserver_path" ]; then
        echo "DEBUG: Каталог $torrserver_path уже существует."
    else
        echo "DEBUG: Каталог $torrserver_path не существует."
        # В неинтерактивном режиме или при использовании --path автоматически создаем каталог
        if [ -n "$input_path" ] || [ -n "$remove_mode" ]; then
            mkdir -p "$torrserver_path" || { echo "Ошибка создания каталога $torrserver_path"; exit 1; }
            echo "DEBUG: Каталог $torrserver_path автоматически создан."
        else
            echo "Хотите создать каталог $torrserver_path? (y/n)"
            read -t 30 response
            if [ "$response" = "y" ] || [ "$response" = "Y" ]; then
                mkdir -p "$torrserver_path" || { echo "Ошибка создания каталога $torrserver_path"; exit 1; }
                echo "DEBUG: Каталог $torrserver_path успешно создан."
            else
                echo "Каталог не создан. Используется стандартный путь: $default_path"
                torrserver_path="$default_path"
                log_path="${default_path}/torrserver.log"
            fi
        fi
    fi
}

# Функция для установки TorrServer
install_torrserver() {
    # Проверяем, установлен ли TorrServer
    if [ -f "$binary" ]; then
        echo "TorrServer уже установлен в $binary."
        echo "Для удаления используйте: $0 --remove"
        exit 0
    fi

    # Создаем каталог для TorrServer
    mkdir -p "$dir" || { echo "Ошибка создания каталога $dir"; exit 1; }
    echo "DEBUG: Каталог $dir создан."

    # Определяем архитектуру системы
    echo "Проверяем архитектуру..."
    architecture=""
    case $(uname -m) in
        x86_64) architecture="amd64" ;;
        i*86) architecture="386" ;;
        armv7*) architecture="arm7" ;;
        armv5*) architecture="arm5" ;;
        aarch64) architecture="arm64" ;;  # Исправлено на arm64
        mips) architecture="mips" ;;
        mips64) architecture="mips64" ;;
        mips64el) architecture="mips64le" ;;
        mipsel) architecture="mipsle" ;;
        *) echo "Архитектура не поддерживается"; exit 1 ;;
    esac
    echo "DEBUG: Определена архитектура: $architecture"

    # Загружаем TorrServer
    url="https://github.com/YouROK/TorrServer/releases/latest/download/TorrServer-linux-$architecture"
    echo "Загружаем TorrServer для $architecture..."
    wget -O "$binary" "$url" || { echo "Ошибка загрузки TorrServer"; exit 1; }
    chmod +x "$binary"
    echo "DEBUG: Бинарный файл $binary загружен и сделан исполняемым."

    # Проверка работоспособности бинарника
    echo "DEBUG: Проверка бинарника..."
    if ! /opt/torrserver/torrserver --version > /dev/null 2>&1; then
        echo "Ошибка: Бинарник /opt/torrserver/torrserver не работает. Удаляю и завершаю."
        rm -f "$binary"
        exit 1
    fi
    echo "DEBUG: Бинарник работает корректно."

    # Загружаем и устанавливаем UPX
    # Получаем последнюю версию UPX, убирая префикс 'v' и беря только числовую часть
    upx_version=$(wget -q -O - https://github.com/upx/upx/releases/latest | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
    if [ -z "$upx_version" ]; then
        echo "Не удалось определить последнюю версию UPX, сжатие пропущено."
        upx_failed=1
    else
        upx_url="https://github.com/upx/upx/releases/download/${upx_version}/upx-${upx_version}-${architecture}_linux.tar.xz"
        echo "Загружаем UPX версии $upx_version для $architecture..."
        wget -O "${dir}/upx.tar.xz" "$upx_url" || { echo "Ошибка загрузки UPX, сжатие пропущено."; upx_failed=1; }
        if [ -z "$upx_failed" ]; then
            tar -xJf "${dir}/upx.tar.xz" -C "$dir" --strip-components=1 --wildcards "*/upx" || { echo "Ошибка распаковки UPX, сжатие пропущено."; rm -f "${dir}/upx.tar.xz"; upx_failed=1; }
            if [ -z "$upx_failed" ]; then
                chmod +x "$upx_binary"
                rm -f "${dir}/upx.tar.xz"
                echo "DEBUG: UPX успешно установлен в $upx_binary."

                # Сжатие бинарника с помощью UPX
                echo "DEBUG: Сжатие бинарника с помощью UPX..."
                "$upx_binary" --best "$binary" || echo "DEBUG: Ошибка сжатия UPX, продолжаю без сжатия."
                if [ $? -eq 0 ]; then
                    echo "DEBUG: Бинарник успешно сжат с помощью UPX."
                fi
            fi
        fi
    fi

    # Проверяем и создаем директории
    check_and_create_dirs

    # Настройка авторизации
    httpauth=""
    if [ -z "$remove_mode" ]; then
        if [ -n "$auth_credentials" ]; then
            if create_auth_file; then
                httpauth="--httpauth"
            fi
        else
            echo "Настроить HTTP-авторизацию для TorrServer? (y/n)"
            read -t 30 auth_response
            if [ "$auth_response" = "y" ] || [ "$auth_response" = "Y" ]; then
                if create_auth_file; then
                    httpauth="--httpauth"
                fi
            fi
        fi
    fi

    # Создаем скрипт init.d для управления службой
    echo "DEBUG: Создание скрипта $init_script..."
    cat << EOF > "$init_script"
#!/bin/sh /etc/rc.common
# Скрипт запуска Torrent сервера

START=95
STOP=10
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /opt/torrserver/torrserver -d /opt/torrserver -p 8090 --path $torrserver_path --logpath $log_path $httpauth
    procd_set_param respawn
    procd_set_param respawn_threshold 3600 5 5  # Перезапуск до 5 раз в час
    procd_set_param respawn_timeout 5          # Таймаут 5 сек
    procd_close_instance
}
EOF
    if [ $? -eq 0 ]; then
        echo "DEBUG: Скрипт $init_script успешно создан."
    else
        echo "Ошибка создания скрипта $init_script"
        exit 1
    fi

    # Делаем скрипт init.d исполняемым и запускаем службу
    chmod +x "$init_script" || { echo "Ошибка установки прав на $init_script"; exit 1; }
    echo "DEBUG: Установлены права на $init_script."
    "$init_script" enable || { echo "Ошибка активации службы $init_script"; exit 1; }
    echo "DEBUG: Служба $init_script активирована."
    "$init_script" start || { echo "Ошибка запуска службы $init_script. Проверяю логи..."; logread | grep -i "torr\|procd" >> /tmp/torrserver_start.log; cat /tmp/torrserver_start.log; exit 1; }
    echo "DEBUG: Служба $init_script запущена."

    echo "TorrServer успешно установлен и запущен."
}

# Функция для удаления TorrServer
remove_torrserver() {
    # Останавливаем службу, если она запущена
    if [ -f "$init_script" ]; then
        "$init_script" stop || echo "Ошибка остановки службы $init_script"
        "$init_script" disable || echo "Ошибка деактивации службы $init_script"
    fi

    # Удаляем файлы TorrServer
    if [ -f "$binary" ]; then
        rm -f "$binary" || echo "Ошибка удаления бинарного файла $binary"
        echo "Удален бинарный файл TorrServer: $binary"
    fi

    if [ -f "$upx_binary" ]; then
        rm -f "$upx_binary" || echo "Ошибка удаления бинарного файла UPX: $upx_binary"
        echo "Удален бинарный файл UPX: $upx_binary"
    fi

    if [ -d "$dir" ]; then
        rm -rf "$dir" || echo "Ошибка удаления каталога $dir"
        echo "Удален каталог TorrServer: $dir"
    fi

    if [ -f "$init_script" ]; then
        rm -f "$init_script" || echo "Ошибка удаления скрипта $init_script"
        echo "Удален init.d скрипт: $init_script"
    fi

    # Удаляем каталог torrserver и файл авторизации, если они существуют
    if [ -n "$torrserver_path" ] && [ -d "$torrserver_path" ] && [ "$torrserver_path" != "$dir" ]; then
        if [ -f "$torrserver_path/accs.db" ]; then
            rm -f "$torrserver_path/accs.db" || echo "Ошибка удаления файла авторизации $torrserver_path/accs.db"
            echo "Удален файл авторизации: $torrserver_path/accs.db"
        fi
        rm -rf "$torrserver_path" || echo "Ошибка удаления каталога $torrserver_path"
        echo "Удален каталог TorrServer: $torrserver_path"
    fi

    echo "TorrServer успешно удален."
}

# Основная логика скрипта
parse_args "$@"
if [ -n "$remove_mode" ]; then
    remove_torrserver
else
    install_torrserver
fi
