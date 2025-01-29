#!/bin/bash
#SECRETS:

# Değişkenlerin tanımlanması
BACKUP_DIR="/var/lib/pgsql/9.6/backups/yeni_backups/"
DATE=$(date +"%Y-%m-%d-%H:%M:%S")
OLD_BACKUP_COUNT=14
EXIT_CODE=0

# Loglama
log() {
    local TYPE=$1
    local MESSAGE=$2
    echo "$DATE [$TYPE] $MESSAGE" >> /var/lib/pgsql/9.6/backups/yeni_backups/hata_log
}

# Hata durumunda e-posta gönderimi
mailat() {
    local SUBJECT=$1
    local MESSAGE=$2
    echo "$MESSAGE" | mail -s "$SUBJECT" ${MAIL_NOTIFICATION}
}

# BACKUP_DIR kontrolü
if [ ! -d "$BACKUP_DIR" ]; then
    log "ERROR" "BACKUP_DIR = $BACKUP_DIR dizini mevcut değil. Betik sonlandırıldı."
    mailat "Yedekleme Yapılamadı!" "BACKUP_DIR = $BACKUP_DIR dizini mevcut değil. Acil müdahale edilmeli."
    exit 10
fi

# PostgreSQL Dump işlemi
log "INFO" "SQL Dump başlatıldı."
DUMP_FILE="$BACKUP_DIR/dump_$DATE.sql"
ERROR_LOG="$BACKUP_DIR/dump_hata-$DATE.log"

# SQL Dump işlemi
su - postgres -c "pg_dumpall -c -o -f $DUMP_FILE 2> $ERROR_LOG"
EXIT_CODE=$?


# SQL Dump işlemi sonrası kontrol
if [ "$EXIT_CODE" -ne 0 ]; then
    log "ERROR" "SQL Dump başarısız oldu. Hata kodu: $EXIT_CODE. Hata log dosyası: $ERROR_LOG"
    mailat "Yedekleme Hatası!" "SQL Dump işlemi başarısız oldu. Hata kodu: $EXIT_CODE. Hata log dosyasını inceleyin: $ERROR_LOG"
    exit 20
fi

# Hata log dosyasının boş olup olmadığının kontrolü
if [ -s "$ERROR_LOG" ]; then
    log "ERROR" "Hata tespit edildi. Hata log dosyasını inceleyin: $ERROR_LOG"
    mailat "Yedekleme Hatası!" "Yedekleme sonrası hata tespit edildi. Hata log dosyasını inceleyin: $ERROR_LOG"
    exit 30
else
    log "INFO" "SQL Dump başarılı. Hata yok, işlemler devam ediyor."
    gzip -vf "$DUMP_FILE" 2>&1 | log "INFO"
    mv "$DUMP_FILE" "$BACKUP_DIR/dump_$DATE.sql.gz"

    rm -vf "$ERROR_LOG" 2>&1 | log "INFO"

    # Eski yedeklerin temizlenmesi
    find "$BACKUP_DIR" -type f -name "dump_*.sql.gz" -mtime +"$OLD_BACKUP_COUNT" -exec rm -vf {} \; 2>&1 | log "INFO"
    
    # 2 günden eski yedekleri sıkıştırma işlemi
	log "INFO" "2 günden eski dump dosyaları sıkıştırılıyor."
    find "$BACKUP_DIR" -type f -name "dump_*.sql" -mtime +2 -exec gzip -v {} \; 2>&1 | log "INFO"

    log "INFO" "Tüm işlemler başarıyla tamamlandı. Betik çıkıyor."
    exit 0
fi
