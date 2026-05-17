# socks-to-http-proxy ![Rust](https://github.com/journalehsan/socks-to-http-proxy/workflows/Rust/badge.svg) ![release](https://img.shields.io/github/v/release/journalehsan/socks-to-http-proxy?include_prereleases)

[🇬🇧 English](README.md) | [🇮🇷 فارسی](README.fa.md)

<div dir="rtl">

یک برنامه برای تبدیل پروکسی SOCKS5 به پروکسی HTTP

## درباره

هدف `sthp` ایجاد پروکسی HTTP روی پروکسی Socks5 است.

## نحوه کارکرد

از کتابخانه hyper برای [نمونه پروکسی HTTP](https://github.com/hyperium/hyper/blob/master/examples/http_proxy.rs) استفاده می‌کند و قابلیت اتصال از طریق Socks5 را به آن اضافه می‌کند.

## نصب

### نصب سریع (پیشنهادی)

مخزن را کلون کرده و اسکریپت نصب را اجرا کنید. اسکریپت به‌طور خودکار تشخیص می‌دهد که root هستید یا کاربر عادی.

```bash
git clone https://github.com/journalehsan/socks-to-http-proxy.git
cd socks-to-http-proxy

# نصب برای کاربر (بدون نیاز به sudo)
./scripts/install.sh

# نصب سراسری
sudo ./scripts/install.sh
```

اسکریپت نصب این کارها را انجام می‌دهد:

- باینری را از سورس می‌سازد (نیاز به `cargo`) اگر باینری آماده‌ای موجود نباشد
- **حالت root** — در `/opt/sthp/` نصب می‌شود، لینک نمادین launcher در `/usr/local/bin/socks2http`
- **حالت کاربر** — باینری و launcher در `~/.local/bin/` نصب می‌شود
- فایل پیکربندی در `/etc/sthprc` (root) یا `~/.config/sthprc` (کاربر) ایجاد می‌کند
- یک **سرویس systemd** نصب و در صورت تمایل فعال می‌کند
- دستورات کمکی `set-proxy` / `unset-proxy` را در فایل‌های RC پوسته (bash، zsh، fish) ثبت می‌کند

برای حذف:

```bash
./scripts/install.sh --uninstall        # کاربر
sudo ./scripts/install.sh --uninstall   # سراسری
```

### فایل پیکربندی

`/etc/sthprc` یا `~/.config/sthprc` (پیکربندی کاربر اولویت دارد):

```bash
# پورت پروکسی HTTP که سرویس روی آن گوش می‌دهد (پیش‌فرض: 8080)
HTTP_PORT=8080

# پورت سرور SOCKS5 (پیش‌فرض: 1080)
SOCKS_PORT=1080

# هاست سرور SOCKS5 (پیش‌فرض: 127.0.0.1)
# SOCKS_HOST=127.0.0.1
```

پس از تغییر، سرویس را ری‌استارت کنید:

```bash
systemctl --user restart sthp   # نصب کاربر
sudo systemctl restart sthp     # نصب سراسری
```

### مدیریت سرویس

```bash
# نصب کاربر
systemctl --user {start|stop|restart|status|enable|disable} sthp

# نصب سراسری
sudo systemctl {start|stop|restart|status|enable|disable} sthp
```

### دستورات کمکی پروکسی

بعد از باز کردن پوسته جدید (یا بارگذاری مجدد فایل RC) می‌توانید پروکسی ترمینال را سریعاً تغییر دهید:

```bash
set-proxy      # فعال‌سازی پروکسی → http_proxy / https_proxy روی 127.0.0.1:<HTTP_PORT>
unset-proxy    # غیرفعال‌سازی و پاک کردن متغیرهای محیطی پروکسی
```

## کامپایل دستی

۱. مطمئن شوید که نسخه فعلی `cargo` و [Rust](https://www.rust-lang.org) نصب شده است
۲. مخزن را کلون کنید: `$ git clone https://github.com/journalehsan/socks-to-http-proxy.git && cd socks-to-http-proxy`
۳. پروژه را بسازید: `$ cargo build --release`
۴. پس از اتمام، باینری در `target/release/sthp` قرار دارد

## استفاده

```bash
sthp -p 8080 -s 127.0.0.1:1080
```

یک سرور پروکسی روی پورت ۸۰۸۰ ایجاد می‌کند و از `localhost:1080` به‌عنوان پروکسی Socks5 استفاده می‌کند.

```bash
sthp -p 8080 -s example.com:8080
```

یک سرور پروکسی روی پورت ۸۰۸۰ ایجاد می‌کند و از `example.com:8080` به‌عنوان پروکسی Socks5 استفاده می‌کند.

> [!NOTE]
> فلگ `--socks-address` (یا `-s`) از schema در ابتدا پشتیبانی نمی‌کند (مثل `socks://` یا `socks5h://`). در حال حاضر فقط socks5h پشتیبانی می‌شود، یعنی تفکیک DNS روی سرور SOCKS انجام می‌شود.

> [!WARNING]
> از نسخه v0.5، آدرس IP پیش‌فرض از `0.0.0.0` به `127.0.0.1` تغییر کرد. این تغییر دسترسی به پروکسی را به دستگاه محلی محدود می‌کند. برای بازگشت به رفتار قبلی از `--listen-ip 0.0.0.0` استفاده کنید.

### گزینه‌ها

```text
Usage: sthp [OPTIONS]

Options:
  -p, --port <PORT>                        port where Http proxy should listen [default: 8080]
      --listen-ip <LISTEN_IP>              [default: 127.0.0.1]
  -u, --username <USERNAME>                Socks5 username
  -P, --password <PASSWORD>                Socks5 password
  -s, --socks-address <SOCKS_ADDRESS>      Socks5 proxy address [default: 127.0.0.1:1080]
      --allowed-domains <ALLOWED_DOMAINS>  Comma-separated list of allowed domains
      --http-basic <HTTP_BASIC>            HTTP Basic Auth credentials in the format "user:passwd"
  -d, --detached                           Run process in background ( Only for Unix based systems)
  -h, --help                               Print help
  -V, --version                            Print version
```

</div>
