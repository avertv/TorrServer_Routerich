### Скрипт найден в тг канале TorrVPS и немного доработан

По умолчанию установка будет использовать путь `/opt/torrserver`, если `--path` не указан.  

Опция `--path` позволяет переопределить путь ( например, `/mnt/sda2/torrserver` ).  
Опция `--auth` добавить авторизацию (например, `--auth admin:passw0rd` ).  
Опция `--path` и `--auth` добавить авторизацию и путь (например, `--path /opt/torrserver --auth admin:password` ).  
Опция `--remove` удаление TorrServer.  
- [x] __Автоматическая установка с указанием пути:__
      
  Устанавливает TorrServer в указанный каталог например, `/mnt/sda2/torrserver` .  
```bash
wget -O - https://raw.githubusercontent.com/avertv/TorrServer_Routerich/refs/heads/main/TSinstall.sh | sh -s -- --path /mnt/sda2/torrserver
```  
- [x] __Интерактивная установка:__
      
  Позволяет указать путь, создать каталог (по желанию) и настроить `HTTP-авторизацию` с вводом `логина и пароля`.  
```bash
cd /tmp
wget -O TSinstall.sh https://raw.githubusercontent.com/avertv/TorrServer_Routerich/refs/heads/main/TSinstall.sh
chmod +x TSinstall.sh
./TSinstall.sh
```
- [x] __Удаление:__

```bash
wget -O - https://raw.githubusercontent.com/avertv/TorrServer_Routerich/refs/heads/main/TSinstall.sh | sh -s -- --remove
```
