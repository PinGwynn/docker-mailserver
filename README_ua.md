# Docker Mailserver

Готовий до продакшн, контейнеризований стек поштового сервера, побудований за допомогою Docker Compose. Забезпечує повноцінне рішення для SMTP, IMAP/LMTP, фільтрації Sieve, підпису DKIM, захисту від спаму та вірусів, TLS і управління користувачами з використанням:

- **Postfix**: SMTP-релей, submission та LMTP до Dovecot
- **Dovecot**: IMAP/LMTP-сервер із Sieve, квотами та керуванням поштовими скриньками
- **Rspamd**: Фільтрація спаму, підпис DKIM, RBL, байєсівський класифікатор
- **ClamAV**: Антивірусне сканування через інтеграцію з Rspamd
- **ACME Companion**: Автоматичне отримання/оновлення сертифікатів (наприклад, Let's Encrypt) через CloudFlare DNS API

Стек призначений для самостійного хостингу та запускається як кілька контейнерів, визначених у `docker-compose.yml`. Постійні дані зберігаються в каталозі `data/`.

## Можливості

- **SMTP/IMAP** зі STARTTLS/TLS
- **Аутентифікація** через Dovecot
- **Sieve** фільтрація для спаму та автоматичного сортування по теках
- **DKIM** підпис вихідної пошти (Rspamd)
- **Фільтрація спаму** з Rspamd (Байєс, RBL, метрики, заголовки milter)
- **Антивірусне сканування** (ClamAV)
- **Автоматичні сертифікати** через ACME
- **Config-as-code**: декларативна конфігурація у `docker/` та постійні робочі дані в `data/`

## Структура репозиторію

```text
docker-mailserver/
	docker/ # Dockerfile-и та оверлеї rootfs для кожного сервісу
		postfix/
		dovecot/
		filter/ # Rspamd
		virus/ # ClamAV
		acme/
	data/ # Постійні дані та змонтовані конфіги
		certs/ # SSL сертифікати, потрібні для Postfix та Dovecot
		postfix/maps/ # карти postfix, наприклад віртуальні псевдоніми тощо
		filter/dkim/ # DKIM ключ для підпису DKIM
		maildir/ # тут зберігаються реальні поштові скриньки
	docker-compose.yml
	scripts/
		user-manager.sh # Допоміжні скрипти для керування користувачами
	setup.sh # Початкова підготовка проєкту
````

## Попередні вимоги

* Встановлені Docker та Docker Compose
* Домен з DNS-записами, які ви контролюєте
* Можливість відкрити на хості/фаєрволі такі порти:

  * 25/tcp (SMTP) – для вхідної пошти від інших МТА
  * 465/tcp (SMTPS) – опціонально, якщо ввімкнено
  * 587/tcp (Submission) – для вихідної пошти клієнтів з аутентифікацією
  * 993/tcp (IMAPS) – IMAP через TLS для клієнтів
  * 11334/tcp (Rspamd controller, опціонально/адмін)

## DNS-записи

Налаштуйте DNS для вашого домену (замініть `mail.example.com` та `example.com`):

* **A/AAAA**: `mail.example.com` → IP вашого сервера
* **MX**: `example.com` → `mail.example.com` (пріоритет 10)
* **SPF (TXT)**: наприклад `v=spf1 mx -all`
* **DKIM (TXT)**: опублікуйте селектор з `data/filter/dkim/mail.pub` (буде згенеровано після першого запуску)
* **DMARC (TXT)**: наприклад `_dmarc.example.com IN TXT "v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com"`
* **PTR**/rDNS для вашого IP сервера → `mail.example.com`

## Швидкий старт

1. Клонуйте репозиторій та налаштуйте середовище:

```bash
git clone <this-repo-url> docker-mailserver
cd docker-mailserver
# Перегляньте та за потреби відредагуйте docker-compose.yml і файли в docker/*
```

2. Запустіть `setup.sh`, щоб підготувати `.env` та заповнити його вашими значеннями
3. Згенеруйте сильний `dhparams.pem` командою:
   `openssl dhparam -out ./data/certs/dhparams.pem 4096`
4. Побудуйте docker-образи:

   ```bash
   docker compose build acme
   docker compose build acme-init
   ```
5. Згенеруйте сертифікат Let's Encrypt:
   `docker compose --profile init up acme-init`
6. Запустіть стек:
   `docker compose up -d`
7. Створіть користувачів та поштові скриньки:

```bash
./scripts/user-manager.sh add user@example.com
./scripts/user-manager.sh passwd user@example.com
```

8. Налаштуйте свій поштовий клієнт:

   * Вхідний IMAP (IMAPS): `mail.example.com`, порт 993, TLS, логін: повна адреса e-mail
   * Вихідний SMTP (Submission): `mail.example.com`, порт 587, STARTTLS, логін: повна адреса e-mail

## Сервіси та конфігурація

### Postfix

* Конфігураційні файли: `docker/postfix/rootfs/etc/postfix/`
* Постійні карти та додаткові робочі файли: `data/postfix/`
* Налаштовуйте карти у `data/postfix/maps/` (наприклад `virtual_alias_maps`, `access` тощо)

### Dovecot

* Конфіг: `docker/dovecot/rootfs/etc/dovecot/`
* Sieve-скрипти: `docker/dovecot/rootfs/etc/dovecot/sieve/`
* Зберігання пошти: `data/maildir/`

### Rspamd (фільтр спаму та DKIM)

* Конфіг: `docker/filter/rootfs/etc/rspamd/`
* DKIM ключі: `data/filter/dkim/`
* Селектор ключа та домен мають збігатися з вашим DNS TXT DKIM-записом

### ClamAV (Антивірус)

* Конфіг: `docker/virus/rootfs/etc/clamav/`
* Інтеграція через модуль антивірусу Rspamd

### Сертифікати (ACME)

* Контейнер ACME розміщує/оновлює сертифікати в `data/certs/`

## Збереження даних

Усі постійні робочі дані зберігаються в `data/` і монтуються в контейнери:

* `data/maildir/` – поштові скриньки користувачів
* `data/certs/` – TLS-сертифікати
* `data/filter/dkim/` – DKIM ключі
* `data/postfix/` – карти та робочі дані postfix

Робіть резервні копії каталогу `data/` регулярно.

## Керування користувачами

Використовуйте допоміжний скрипт `scripts/user-manager.sh`:

```bash
# Додати користувача
./scripts/user-manager.sh add user@example.com

# Змінити пароль
./scripts/user-manager.sh passwd user@example.com

# Видалити користувача
./scripts/user-manager.sh del user@example.com
```

Поштові скриньки зберігаються в `data/maildir/`.

## Збірка та запуск

```bash
# Зібрати всі образи
docker compose build

# Запустити сервіси
docker compose up -d

# Перегляд логів конкретного сервісу (наприклад, postfix)
docker compose logs -f postfix | cat

# Зупинити сервіси
docker compose down
```

## Налаштування DKIM

1. Переконайтеся, що підпис DKIM у Rspamd увімкнено (див. `docker/filter/rootfs/etc/rspamd/local.d/dkim_signing.conf`).
2. Згенеруйте DKIM ключі, якщо їх немає, та помістіть їх у `data/filter/dkim/`.
3. Опублікуйте публічний ключ DKIM у DNS під обраним селектором.
4. Перезавантажте сервіси filter/postfix за потреби.

```bash
docker compose exec filter /usr/local/bin/entrypoint.sh reload
docker compose exec postfix /usr/local/bin/entrypoint.sh reload
```

## Фільтрація Sieve

Глобальні Sieve-скрипти знаходяться у `docker/dovecot/rootfs/etc/dovecot/sieve/global/` (наприклад, навчання спаму, переміщення спаму в папку). Користувачі можуть вмикати власні правила через поштові клієнти або надаючи власні Sieve-скрипти.

## Резервне копіювання

* Регулярно робіть резервні копії каталогу `data/` (rsync, snapshots тощо).
* Перевіряйте відновлення на тестовому середовищі.

## Усунення несправностей

* Перевіряйте логи сервісів:

```bash
docker compose logs --tail=200 postfix | cat
docker compose logs --tail=200 dovecot | cat
docker compose logs --tail=200 filter | cat
docker compose logs --tail=200 virus | cat
docker compose logs --tail=200 acme | cat
```

* Переконайтеся, що порти відкриті на хості та всередині контейнерів
* Перевіряйте DNS (MX, SPF, DKIM, DMARC) за допомогою зовнішніх інструментів
* Переконайтеся, що rDNS/PTR відповідає імені вашого поштового хоста для кращої доставлюваності

## Примітки з безпеки

* Використовуйте надійні паролі для всіх користувачів
* Обмежуйте доступ до адміністративних інтерфейсів (наприклад, Rspamd controller) лише довіреним мережам
* Регулярно оновлюйте образи: перезбирайте, щоб отримувати останні оновлення безпеки

## Обслуговування

```bash
# Оновити образи та перезапустити
docker compose pull
docker compose up -d

# Перезібрати з Dockerfile після змін
docker compose build --no-cache
docker compose up -d
```

## Ліцензія

Цей проєкт надається за ліцензією MIT.

## Подяки

* Спільноти Postfix, Dovecot, Rspamd, Acme.sh та ClamAV
* Натхнено поширеними самохостинговими стек-проєктами поштових серверів
* [https://gitlab.com/argo-uln](https://gitlab.com/argo-uln) за початкові ідеї для налаштування поштового сервера з docker
