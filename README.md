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

## Clone Repository

Salin project ke mesin Anda dengan **Git**. Pilih salah satu metode di bawah.

**SSH** (disarankan jika kunci SSH GitHub sudah terpasang):

```bash
git clone git@github.com:brampratowo/moodle-enhanced.git
cd moodle-enhanced
```

**HTTPS** (tanpa kunci SSH; GitHub dapat meminta token personal saat push):

```bash
git clone https://github.com/brampratowo/moodle-enhanced.git
cd moodle-enhanced
```

Untuk branch atau tag tertentu, tambahkan `-b <nama-branch>` setelah `git clone`.

## Cara Pakai Cepat

```bash
cd moodle-enhanced
cp .env.example .env
# Edit .env (sand DB, port, dll. — lihat Parameter Penting .env)
```

Pilih **satu** skrip instalasi sesuai stack yang dibutuhkan:

| Skrip | Stack |
|-------|--------|
| `./scripts/install-moodle-mariadb-redis.sh` | Moodle + MariaDB + Redis |
| `./scripts/install-moodle-mariadb-redis-minio.sh` | di atas + MinIO |
| `./scripts/install.sh` | Moodle saja (database/Redis di luar Docker; atur `DB_HOST` dll. di `.env`) |

Skrip wrapper MariaDB/Redis/MinIO menyalin `*.example` → `my.cnf` / `redis.conf` jika belum ada. Sesuaikan `config/mariadb/my.cnf` dan `config/redis/redis.conf` bila perlu.

Setelah sukses, buka `http://<APP_HOST>:<APP_PORT>` dan lanjutkan wizard Moodle di browser. Nilai database di wizard harus sama dengan `.env`.

**Operasional harian:** uncomment baris `INSTALL_COMPOSE_FILES` yang sesuai di `.env` (contoh ada di `.env.example`) agar `up` / `down` / `logs` mengelola stack yang sama dengan instalasi. Tanpa itu, skrip operasional hanya memakai `docker-compose-moodle.yml`.

## Parameter Penting `.env`

Urutan di bawah mengikuti **`.env.example`** (Moodle → MariaDB → Redis → MinIO → path mount → opsional compose).

- `MOODLE_SERIES` — contoh: `501` (paket resmi dari `packaging.moodle.org`)
- `MOODLE_DOWNLOAD_URL` — opsional (baris bisa dikomentari di `.env`), override URL paket resmi
- `APP_PORT` — default: `8080`
- `APP_HOST` — default: `localhost` (ubah ke IP/domain jika akses dari mesin lain)
- `DB_HOST` — host database dari sudut pandang **container Moodle** (contoh `moodle-db` jika memakai `docker-compose-mariadb.yml` pada jaringan yang sama)
- `DB_PORT` — default: `3306`
- `DB_TYPE` — default: `mariadb`
- `DB_PREFIX` — default: `mdl_`
- `PERMISSION_MODE` — `compat` (longgar), atau `prod` / `secure` (lebih ketat)
- `WWW_DATA_UID` / `WWW_DATA_GID` — default `33` (`www-data`)
- `MYSQL_ROOT_PASSWORD` — sandi root MariaDB di container (wajib ada jika memakai `docker-compose-mariadb.yml`)
- `DB_NAME`, `DB_USER`, `DB_PASSWORD` — dipakai Moodle dan (jika memakai compose MariaDB) inisialisasi database di container
- `REDIS_HOST` — host Redis dari sudut pandang **container Moodle** (contoh `moodle-redis` jika memakai `docker-compose-redis.yml` pada jaringan yang sama)
- `REDIS_PORT` — port Redis, biasanya `6379`
- `REDIS_DATABASE` — indeks logical database Redis (integer, biasanya `0`) untuk penyimpanan sesi
- `REDIS_PREFIX` — awalan kunci sesi di Redis agar tidak bentrok dengan aplikasi lain yang memakai instance yang sama (contoh `sess_`)
- `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD` — akun root MinIO (wajib diisi jika memakai `docker-compose-minio.yml`)
- `MOODLE_SOURCE_PATH`, `MOODLEDATA_PATH`, `MOODLE_CONFIG_PATH` — mount source Moodle, moodledata, dan lokasi `config.php`
- `MOODLE_CONFIG_SKIP_SYNC=1` — jangan timpa `config.php` saat menjalankan `install.sh`
- `DOCKER_NETWORK_NAME` — opsional; default `docker_network`
- `INSTALL_COMPOSE_FILES` — uncomment di `.env` setelah instalasi agar `up`/`down`/`logs` selaras dengan skrip yang dipakai (lihat `.env.example`)

## MariaDB & Redis dari Compose

Penjelasan di bawah mengikuti blok yang sama seperti di **`.env.example`**: MariaDB dulu, lalu Redis, lalu MinIO.

- Data MariaDB ada di **`data/mariadb`**. Konfigurasi aktif: **`config/mariadb/my.cnf`**. Jika belum ada, skrip instalasi menyalin otomatis dari `my.cnf.example`; Anda tetap boleh menyalin manual dan mengedit sebelum atau sesudah instalasi. Variabel **`DB_HOST`**, **`DB_PORT`**, **`DB_TYPE`**, **`DB_PREFIX`**, **`PERMISSION_MODE`**, **`WWW_DATA_UID`**, **`WWW_DATA_GID`** (dibahas di atas) dipakai skrip seperti **`.env`**: koneksi dan mode izin/pemilik untuk `install.sh`/compose.
- **`MYSQL_ROOT_PASSWORD`** hanya untuk akun root MariaDB **di container database** (compose MariaDB); **`DB_NAME`**, **`DB_USER`**, dan **`DB_PASSWORD`** dipakai Moodle lewat **`config.php`** dan bersama untuk inisialisasi database aplikasi di container.
- Redis memakai **`config/redis/redis.conf`**; jika belum ada, skrip menyalin dari `redis.conf.example` seperti MariaDB.
- Variabel **`REDIS_HOST`**, **`REDIS_PORT`**, **`REDIS_DATABASE`**, dan **`REDIS_PREFIX`** di `.env` dipakai saat **`install.sh`** menulis `config.php`: Moodle diatur memakai handler sesi Redis (`\core\session\redis`) dengan nilai tersebut (`session_redis_*`). Pastikan host/port benar-benar terjangkau dari container Moodle; jika Anda **tidak** menjalankan Redis, ubah `config.php` atau sesuaikan stack agar sesi tidak mengarah ke layanan yang tidak ada.
- MinIO memakai **`data/minio`** dan **`config/minio`** (folder dibuat otomatis saat instalasi stack ber-MinIO). Kredensial root: **`MINIO_ROOT_USER`** dan **`MINIO_ROOT_PASSWORD`** di `.env`.

## MinIO dan plugin ObjectFS (`tool_objectfs`)

### MinIO pada Docker host yang berbeda dengan Moodle

MinIO berjalan di **mesin Docker lain** (bukan stack `docker-compose-minio.yml` di server Moodle). Moodle tetap di container; MinIO di container/server terpisah yang bisa dijangkau lewat jaringan (IP privat, VPN, atau hostname DNS).

**Tidak perlu patch plugin** (poin 1 dan 2 di bawah). Cukup atur **`config.php`** — setara poin 3, dengan endpoint yang **terjangkau dari container Moodle**, bukan nama layanan Docker internal (`moodle-minio` hanya valid di host yang sama).

```php
$CFG->alternative_file_system_class = '\tool_objectfs\s3_file_system';
$CFG->forced_plugin_settings['tool_objectfs'] = [
    'filesystem' => '\tool_objectfs\s3_file_system',
    's3_key' => '...',
    's3_secret' => '...',
    's3_bucket' => 'nama-bucket-minio',
    's3_region' => 'us-east-1',
    's3_base_url' => 'http://IP-ATAU-HOST-SERVER-MINIO:9000',
    's3_use_path_style_endpoint' => 1,
    'key_prefix' => 'filedir/',
];
```

- **`s3_base_url`**: IP atau hostname **server tempat MinIO Docker berjalan**, misalnya `http://192.168.1.20:9000` atau `http://minio.internal:9000`. Uji dari container Moodle (`curl http://…:9000/minio/health/live`).
- **`s3_bucket`**: nama bucket di MinIO (bukan host atau port).
- Instalasi Moodle: pakai `./scripts/install-moodle-mariadb-redis.sh` (tanpa MinIO di stack yang sama), atau `./scripts/install.sh` jika layanan lain juga eksternal.
- Buka port **9000** (atau port MinIO Anda) dari server MinIO ke server/container Moodle.

MinIO di luar Docker (bare metal, layanan cloud) mengikuti pola yang sama: endpoint publik/privat yang bisa di-resolve dari Moodle, tanpa patch plugin.

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

**3. `config.php`** — setelah patch (1)–(2), contoh untuk MinIO di jaringan Docker yang sama:

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

- Urutan variabel dokumentasi mengikuti **`.env.example`** (lihat **Parameter Penting `.env`**).
- `config.php` di host ditulis ulang dari `.env` setiap kali `install.sh` dijalankan, kecuali `MOODLE_CONFIG_SKIP_SYNC=1`.
- Unduh source Moodle dilakukan **sebelum** penulisan `config.php`, agar `config.php` tidak terhapus saat folder `moodle` dikosongkan untuk ekstrak arsip.
- `moodle-cron` menjalankan `admin/cli/cron.php` setiap 60 detik.
- Source Moodle diambil dari channel resmi `packaging.moodle.org` (bukan GitHub).
