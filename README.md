# Moodle Install Dari Nol (Script Lengkap)

Folder ini berisi skrip dan berkas untuk menginstal Moodle dari nol hingga stack Docker berjalan.

## Struktur File

| Berkas / folder | Keterangan |
|-----------------|------------|
| `.env.example` | Template konfigurasi; salin ke `.env` lalu sesuaikan |
| `Dockerfile` | Image Moodle (PHP Apache + ekstensi) |
| `docker-compose-moodle.yml` | Layanan `app` (moodle-app) + `cron` (moodle-cron) |
| `docker-compose-mariadb.yml` | MariaDB (`moodle-db`) |
| `docker-compose-redis.yml` | Redis (`moodle-redis`) |
| `docker-compose-minio.yml` | MinIO (`moodle-minio`) |
| `config/mariadb/my.cnf.example` | Template MariaDB; jika **`my.cnf`** belum ada, skrip menyalin ke **`config/mariadb/my.cnf`** |
| `config/redis/redis.conf.example` | Template Redis; jika **`redis.conf`** belum ada, skrip menyalin ke **`config/redis/redis.conf`** |
| `scripts/compose-common.sh` | Fungsi bersama: muat `.env`, argumen compose, jaringan, persiapan mount |
| `scripts/install.sh` | Instalasi penuh (unduh Moodle, `config.php`, build & `up`) — default hanya stack Moodle |
| `scripts/install-moodle-mariadb-redis.sh` | Sama seperti `install.sh`, plus MariaDB + Redis |
| `scripts/install-moodle-mariadb-redis-minio.sh` | Sama seperti di atas, plus MinIO |
| `scripts/install-from-zero.sh` | Alias ke `install.sh` |
| `scripts/up.sh` / `down.sh` / `logs.sh` | Menjalankan, menghentikan, atau melihat log stack |
| `scripts/start.sh` / `scripts/stop.sh` | Alias ke `up.sh` / `down.sh` |

Semua berkas compose memakai jaringan eksternal **`docker_network`**. Skrip instalasi akan membuatnya otomatis jika belum ada.

## Cara Pakai Cepat

Dari folder project:

```bash
cd /path/ke/waskita-installer
cp .env.example .env
# Edit .env (wajib simpan file setelah mengubah)

# MariaDB + Redis: skrip instalasi menyalin *.example -> my.cnf / redis.conf jika belum ada;
# edit config/mariadb/my.cnf dan config/redis/redis.conf sesuai server bila perlu.

# Pilih salah satu sesuai kebutuhan server:
./scripts/install.sh
# atau satu server: Moodle + MariaDB + Redis
./scripts/install-moodle-mariadb-redis.sh
# atau ditambah MinIO
./scripts/install-moodle-mariadb-redis-minio.sh
```

Setelah sukses, buka:

`http://<APP_HOST>:<APP_PORT>`

Lanjutkan wizard instalasi Moodle di browser. Nilai database di wizard harus konsisten dengan `.env` (dan dengan `docker-compose-mariadb.yml` jika Anda memakai MariaDB dari compose).

## Stack Compose & `INSTALL_COMPOSE_FILES`

Beberapa berkas compose digabung dengan perintah `docker compose -f ... -f ...`. Daftar berkas diatur lewat variabel lingkungan **`INSTALL_COMPOSE_FILES`**, dipisah **titik dua** (`:`), urutan bebas asal semua path relatif ke root project.

Contoh:

```env
INSTALL_COMPOSE_FILES=docker-compose-moodle.yml:docker-compose-mariadb.yml:docker-compose-redis.yml
```

- Skrip **`install-moodle-mariadb-redis.sh`** dan **`install-moodle-mariadb-redis-minio.sh`** mengatur `INSTALL_COMPOSE_FILES` untuk Anda, lalu menjalankan `install.sh`.
- **`install.sh`** saja memakai default `docker-compose-moodle.yml` (hanya Moodle; database harus sudah tersedia dan `DB_HOST` di `.env` menunjuk ke host yang bisa dijangkau dari container).

**Penting:** isi **`INSTALL_COMPOSE_FILES` yang sama di `.env`** agar `./scripts/up.sh`, `./scripts/down.sh`, dan `./scripts/logs.sh` memanipulasi stack yang sama dengan yang Anda instal. Jika tidak diisi, skrip operasional itu hanya memakai `docker-compose-moodle.yml`.

## Parameter Penting `.env`

- `MOODLE_SERIES` — contoh: `501` (paket resmi dari `packaging.moodle.org`)
- `MOODLE_DOWNLOAD_URL` — opsional, override URL paket resmi
- `APP_PORT` — default: `8080`
- `APP_HOST` — default: `localhost` (ubah ke IP/domain jika akses dari mesin lain)
- `DB_HOST` — host database dari sudut pandang **container Moodle** (contoh `moodle-db` jika memakai `docker-compose-mariadb.yml` pada jaringan yang sama)
- `DB_PORT` — default: `3306`
- `DB_TYPE` — default: `mariadb`
- `DB_PREFIX` — default: `mdl_`
- `DB_NAME`, `DB_USER`, `DB_PASSWORD` — dipakai Moodle dan (jika memakai compose MariaDB) inisialisasi database di container
- `MYSQL_ROOT_PASSWORD` — sandi root MariaDB di container (wajib ada jika memakai `docker-compose-mariadb.yml`)
- `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD` — akun root MinIO (wajib diisi jika memakai `docker-compose-minio.yml`)
- `PERMISSION_MODE` — `compat` (longgar), atau `prod` / `secure` (lebih ketat)
- `WWW_DATA_UID` / `WWW_DATA_GID` — default `33` (`www-data`)
- `MOODLE_SOURCE_PATH`, `MOODLEDATA_PATH`, `MOODLE_CONFIG_PATH` — mount source Moodle, moodledata, dan lokasi `config.php`
- `MOODLE_CONFIG_SKIP_SYNC=1` — jangan timpa `config.php` saat menjalankan `install.sh`
- `INSTALL_COMPOSE_FILES` — daftar berkas compose (pemisah `:`), selaras dengan stack instalasi
- `DOCKER_NETWORK_NAME` — opsional; default `docker_network`

## MariaDB & Redis dari Compose

- Data MariaDB ada di **`data/mariadb`**. Konfigurasi aktif: **`config/mariadb/my.cnf`**. Jika belum ada, skrip instalasi menyalin otomatis dari `my.cnf.example`; Anda tetap boleh menyalin manual dan mengedit sebelum atau sesudah instalasi.
- **`DB_NAME` / `DB_USER` / `DB_PASSWORD`** di `.env` dipakai bersama oleh `config.php` Moodle dan inisialisasi MariaDB di compose; **`MYSQL_ROOT_PASSWORD`** hanya untuk akun root di container database.
- Redis memakai **`config/redis/redis.conf`**; jika belum ada, skrip menyalin dari `redis.conf.example` seperti MariaDB.
- MinIO memakai **`data/minio`** dan **`config/minio`** (folder dibuat otomatis saat instalasi stack ber-MinIO). Kredensial root: **`MINIO_ROOT_USER`** dan **`MINIO_ROOT_PASSWORD`** di `.env`.

## MinIO dan plugin ObjectFS (`tool_objectfs`)

### MinIO pada server/host berbeda dengan Moodle

Jika **MinIO** dan Moodle (beserta plugin **`tool_objectfs`**) tidak berada di stack atau host Docker yang sama—misalnya MinIO eksternal, IP publik lain, atau layanan yang sudah bisa di-resolve lewat DNS—biasanya Anda **tidak perlu patch** sumber plugin seperti pada skenario satu-host di bawah.

Langsung aktifkan penyimpanan S3 di **`config.php`**, sesuaikan kredensial, nama bucket, host, dan URL:

```php
$CFG->alternative_file_system_class = '\tool_objectfs\s3_file_system';
$CFG->forced_plugin_settings['tool_objectfs'] = [
    'filesystem' => '\tool_objectfs\s3_file_system',
    's3_key' => '...',
    's3_secret' => '...',
    's3_bucket' => 'nama-bucket-minio',
    's3_region' => 'us-east-1',
    's3_base_url' => 'http://IP-ATAU-HOST:9000',
    's3_use_path_style_endpoint' => 1,
    'key_prefix' => 'filedir/',
];
```

Ganti `s3_key` / `s3_secret` dengan access key MinIO, **`s3_bucket`** dengan **nama bucket** MinIO Anda (nilai seperti `host:9000` bukan nama bucket; host endpoint hanya **`s3_base_url`**), dan **`s3_base_url`** dengan **`http://…:9000`** yang **benar-benar terjangkau dari Moodle**, misalnya IP publik/private server MinIO lain, atau hostname internal jika Moodle mengenalinya dari container.

### MinIO pada Docker host yang sama dengan Moodle

Jika Anda menjalankan **MinIO** di stack Docker **yang sama** dengan Moodle (misalnya lewat `docker-compose-minio.yml` dan jaringan `docker_network`), lalu memakai plugin **ObjectFS** dengan penyimpanan S3-kompatibel menuju MinIO:

- AWS SDK secara bawaan memakai URL **virtual-hosted** (`http://<nama-bucket>.<host>:9000/`). Nama host seperti `moodledata.moodle-minio` **tidak bisa di-resolve** oleh DNS bawaan Docker, sehingga muncul error *Could not resolve host*.
- Mengatur `s3_use_path_style_endpoint` saja di `config.php` / pengaturan plugin **belum cukup** pada beberapa versi `tool_objectfs`: klien S3 di plugin **tidak meneruskan** opsi `use_path_style_endpoint` ke SDK.

**Perlu patch sumber plugin** (setelah source Moodle tersedia), setara dengan berikut.

**1. `admin/tool/objectfs/classes/local/store/s3/client.php`** — di dalam `set_client()`, setelah blok `s3_base_url`, sebelum `S3Client::factory`:

```php
        // Support base_url config for aws api compatible endpoints.
        if ($config->s3_base_url) {
            $options['endpoint'] = $config->s3_base_url;
        }

        if (!empty($config->s3_use_path_style_endpoint)) {
            $options['use_path_style_endpoint'] = true;
        }

        $this->client = \Aws\S3\S3Client::factory($options);
```

**2. `admin/tool/objectfs/classes/local/manager.php`** — di `get_objectfs_config()`, bersama default S3 lainnya:

```php
        $config->s3_base_url = '';
        $config->s3_use_path_style_endpoint = 0;
        $config->key_prefix = '';
```

**3. `config.php` (contoh)** — aktifkan path-style dan endpoint MinIO di jaringan Docker yang sama:

```php
$CFG->alternative_file_system_class = '\tool_objectfs\s3_file_system';
$CFG->forced_plugin_settings['tool_objectfs'] = [
    'filesystem' => '\tool_objectfs\s3_file_system',
    's3_key' => '...',
    's3_secret' => '...',
    's3_bucket' => 'moodledata',
    's3_region' => 'us-east-1',
    's3_base_url' => 'http://moodle-minio:9000',
    's3_use_path_style_endpoint' => 1,
    'key_prefix' => 'filedir/',
];
```

Dengan patch di (1)–(2), nilai `s3_use_path_style_endpoint` di (3) benar-benar diteruskan ke SDK sehingga request memakai **path-style** (`http://moodle-minio:9000/<bucket>/...`).

**Catatan:** jika Anda menjalankan ulang `install.sh` dan **mengunduh ulang** arsip Moodle ke folder kosong, berkas plugin akan kembali seperti upstream — patch di atas perlu diterapkan lagi (atau otomatisasi dengan skrip / image custom).

## Operasional Harian

```bash
./scripts/up.sh
./scripts/down.sh
./scripts/logs.sh
```

## Catatan

- `config.php` di host ditulis ulang dari `.env` setiap kali `install.sh` dijalankan, kecuali `MOODLE_CONFIG_SKIP_SYNC=1`.
- Unduh source Moodle dilakukan **sebelum** penulisan `config.php`, agar `config.php` tidak terhapus saat folder `moodle` dikosongkan untuk ekstrak arsip.
- `moodle-cron` menjalankan `admin/cli/cron.php` setiap 60 detik.
- Source Moodle diambil dari channel resmi `packaging.moodle.org` (bukan GitHub).
