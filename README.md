### Скрипт найден в тг канале TorrVPS и немного доработан

 По умолчанию установка будет использовать `/opt/torrserver`, если `--path` не указан.
  Опция `--path` позволяет переопределить путь (например, `/mnt/sda2/torrserver`).
  Опция `--auth` сохранена для настройки авторизации.
 Скрипт продолжает поддерживать интерактивный ввод с таймаутом.


* __Неинтерактивная установка с указанием пути:__

  Устанавливает TorrServer в указанный каталог например, `/mnt/sda2/torrserver` .

Команда:
```bash
wget -O - https://raw.githubusercontent.com/avertv/TorrServer_Routerich/refs/heads/main/TSinstall.sh | sh -s -- --path /mnt/sda2/torrserver
```
Результат: Установка в `/mnt/sda2/torrserver` без авторизации.

* __Интерактивная установка:__
  Позволяет указать путь, создать каталог (по желанию) и настроить `HTTP-авторизацию` с вводом `логина и пароля`.
Команда:
```bash
cd /tmp
wget -O TSinstall.sh https://raw.githubusercontent.com/avertv/TorrServer_Routerich/refs/heads/main/TSinstall.sh
chmod +x TSinstall.sh
./TSinstall.sh
```

