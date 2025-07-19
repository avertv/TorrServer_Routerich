#!/bin/sh
# Этот скрипт устанавливает TorrServer на OpenWRT.

# Каталог для TorrServer
dir="/opt/torrserver"
binary="${dir}/torrserver"
init_script="/etc/init.d/torrserver"

echo "Проверяем наличие TorrServer..."

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
        if upx --lzma --best ${binary}; then
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
            if upx --lzma --best ${binary}; then
                echo "Бинарный файл TorrServer успешно сжат."
            else
                echo "Ошибка сжатия TorrServer. Продолжаем установку без сжатия."
            fi
        else
            echo "Не удалось установить UPX. Продолжаем установку без сжатия."
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
    procd_set_param command /opt/torrserver/torrserver \
        -d /opt/torrserver \
        -p 8090 \
        --path /mnt/sda2/torrserver \
        --logpath /mnt/sda2/torrserver.log \
        --httpauth
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

    echo "TorrServer успешно удален."
}

# Основная логика скрипта
case "$1" in
    --remove|-r)
        remove_torrserver
        ;;
    *)
        install_torrserver
        ;;
esac
