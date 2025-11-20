# Пошаговое Руководство по Настройке Сервера для AURA

Это руководство проведет вас через все этапы настройки вашего мини-ПК с нуля до полностью работающего стека сервисов, необходимых для разработки и запуска проекта AURA.

---

### **Часть 1: Начальная Настройка Сервера**

**Шаг 1.1: Установка Операционной Системы**
1.  Скачайте образ **Ubuntu Server 22.04 LTS**.
2.  Создайте загрузочную флешку и установите систему на ваш мини-ПК.
3.  **Важно:** Во время установки отметьте пункт **"Install OpenSSH server"** для удаленного доступа.
4.  После установки подключитесь к серверу по SSH: `ssh ваш_логин@<IP-адрес_сервера>`

**Шаг 1.2: Обновление Системы**
```bash
sudo apt update && sudo apt upgrade -y
```

**Шаг 1.3: Установка Базовых Утилит**
```bash
sudo apt install -y git curl wget nano
```

---

### **Часть 2: Установка Docker и Docker Compose**

**Шаг 2.1: Установка Docker Engine**
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

**Шаг 2.2: Настройка Docker для работы без `sudo`**
```bash
sudo usermod -aG docker $USER
```
**Важно:** После этого **перелогиньтесь** на сервер (выйдите и зайдите по SSH снова).

**Шаг 2.3: Проверка Установки**
```bash
docker --version
```
Вы должны увидеть версию Docker.

---

### **Часть 3: Настройка и Запуск Сервисов AURA**

**Шаг 3.1: Создание Структуры Директорий**
На сервере выполните следующие команды для создания структуры проекта:
```bash
# Создаем основную директорию
sudo mkdir -p /srv/docker/aurahome
cd /srv/docker/aurahome

# Создаем директории для данных каждого сервиса
sudo mkdir -p mosquitto/config mosquitto/data mosquitto/log
sudo mkdir -p zigbee2mqtt/data
sudo mkdir -p postgres/data
sudo mkdir -p redis/data
sudo mkdir -p homeassistant/config
sudo mkdir -p ollama/data
```

**Шаг 3.2: Создание Конфигурационных Файлов**

1.  **Конфигурация Mosquitto (MQTT Брокер):**
    Создайте файл `sudo nano /srv/docker/aurahome/mosquitto/config/mosquitto.conf` и добавьте в него:
    ```conf
    persistence true
    persistence_location /mosquitto/data/
    log_dest file /mosquitto/log/mosquitto.log
    allow_anonymous true
    listener 1883
    ```

2.  **Конфигурация Zigbee2MQTT:**
    Создайте файл `sudo nano /srv/docker/aurahome/zigbee2mqtt/data/configuration.yaml` и добавьте в него:
    ```yaml
    homeassistant: true
    permit_join: true
    mqtt:
      base_topic: zigbee2mqtt
      server: 'mqtt://mosquitto:1883'
    serial:
      # --- ВАЖНО: Укажите здесь путь к вашему Zigbee-стику ---
      # Узнать его можно командой: ls -l /dev/serial/by-id
      port: /dev/ttyUSB0
    advanced:
      log_level: info
    ```

**Шаг 3.3: Создание `docker-compose.yml`**
Это главный файл, управляющий всеми нашими контейнерами. Создайте его:
```bash
sudo nano /srv/docker/aurahome/docker-compose.yml
```
И вставьте в него следующее содержимое:
```yaml
version: '3.8'

services:
  homeassistant:
    container_name: homeassistant
    image: "ghcr.io/home-assistant/home-assistant:stable"
    volumes:
      - ./homeassistant/config:/config
      - /etc/localtime:/etc/localtime:ro
    restart: unless-stopped
    privileged: true
    network_mode: host

  mosquitto:
    container_name: mosquitto
    image: eclipse-mosquitto:2
    volumes:
      - ./mosquitto/config:/mosquitto/config
      - ./mosquitto/data:/mosquitto/data
      - ./mosquitto/log:/mosquitto/log
    ports:
      - "1883:1883"
    restart: unless-stopped

  zigbee2mqtt:
    container_name: zigbee2mqtt
    image: koenkk/zigbee2mqtt:latest
    volumes:
      - ./zigbee2mqtt/data:/app/data
      - /run/udev:/run/udev:ro
    ports:
      - "8080:8080" # Веб-интерфейс Zigbee2MQTT
    devices:
      # --- Убедитесь, что путь совпадает с указанным в configuration.yaml ---
      - /dev/ttyUSB0:/dev/ttyACM0 
    environment:
      - TZ=Europe/Moscow
    restart: unless-stopped
    depends_on:
      - mosquitto

  postgres:
    container_name: postgres_aura
    image: timescale/timescaledb-ha:pg16-ts2.13-all
    volumes:
      - ./postgres/data:/var/lib/postgresql/data
    environment:
      # --- ВАЖНО: Задайте здесь свой надежный пароль ---
      - POSTGRES_PASSWORD=your_strong_password 
      - POSTGRES_USER=aura
      - POSTGRES_DB=auradb
    ports:
      - "5432:5432"
    restart: unless-stopped

  redis:
    container_name: redis_aura
    image: redis:7-alpine
    volumes:
      - ./redis/data:/data
    restart: unless-stopped

  ollama:
    container_name: ollama
    image: ollama/ollama:latest
    volumes:
      - ./ollama/data:/root/.ollama
    ports:
      - "11434:11434"
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
    restart: unless-stopped
```

**Шаг 3.4: Запуск Всего Стека**
Теперь, находясь в директории `/srv/docker/aurahome`, выполните команду:
```bash
sudo docker-compose up -d
```
Docker скачает все образы и запустит контейнеры в фоновом режиме.

---

### **Часть 4: Проверка и Дальнейшие Шаги**

1.  **Проверьте статус контейнеров:**
    ```bash
    docker ps
    ```
    Вы должны увидеть все запущенные сервисы: `homeassistant`, `mosquitto`, `zigbee2mqtt`, `postgres_aura`, `redis_aura`, `ollama`.

2.  **Откройте Home Assistant:**
    Перейдите в браузере по адресу `http://<IP-адрес_сервера>:8123`. Пройдите первоначальную настройку.

3.  **Откройте Zigbee2MQTT:**
    Перейдите по адресу `http://<IP-адрес_сервера>:8080`. Вы должны увидеть веб-интерфейс, готовый к сопряжению устройств.

4.  **Проверьте Ollama:**
    Выполните на сервере: `curl http://localhost:11434`. Вы должны получить ответ `Ollama is running`.

Поздравляю! Ваша среда для разработки AURA полностью готова.