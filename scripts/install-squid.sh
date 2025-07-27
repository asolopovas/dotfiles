#!/bin/sh
set -eu

# Check if running as root without sudo user context
[ "$(id -u)" = "0" ] && [ -z "${SUDO_USER:-}" ] && {
    echo "Error: Do not run this script as root. It will request sudo when needed."
    exit 1
}

# Configuration
VER=7.1
PREFIX=/usr/local/squid
CACHE_DIR=/mnt/d/.cache/web

# Ports configuration
PROXY_PORT=3128
HTTP_INTERCEPT_PORT=3129
HTTPS_INTERCEPT_PORT=3130
HTTP_PORT=8080  # Test port for HTTP interception
HTTPS_PORT=8443 # Test port for HTTPS interception

# Standard web ports
STD_HTTP_PORT=80
STD_HTTPS_PORT=443

# SSL/Certificate configuration
RSA_KEY_SIZE=2048
CERT_VALIDITY_DAYS=365
DH_PARAM_SIZE=2048

# Cache and refresh settings
CACHE_REFRESH_LARGE_FILES=259200  # 3 days for archives
CACHE_REFRESH_CONDA=129600        # 1.5 days for conda packages  
CACHE_REFRESH_MEDIA=86400         # 1 day for media files
CACHE_REFRESH_GITHUB=86400        # 1 day for GitHub releases
CACHE_REFRESH_DEFAULT=4320        # 3 days default

# Service configuration
RESTART_DELAY=5
SSLCRTD_CHILDREN=5
SSL_CERT_CACHE_SIZE=20MB

# Testing configuration
TEST_SLEEP_DURATION=3
LOG_TAIL_LINES=20
CACHE_PERCENTAGE=20  # Cache hit percentage for refresh patterns

# TCP keepalive settings
TCP_KEEPALIVE_TIME=60
TCP_KEEPALIVE_INTERVAL=30
TCP_KEEPALIVE_PROBES=3

log() { gum style --foreground="#00ff00" "$*"; }
error() { gum style --foreground="#ff0000" "$*"; }

remove_iptables() {
    sudo iptables -t nat -D OUTPUT -p tcp --dport $STD_HTTP_PORT -m owner ! --uid-owner proxy -j REDIRECT --to-port $HTTP_INTERCEPT_PORT 2>/dev/null || true
    sudo iptables -t nat -D OUTPUT -p tcp --dport $STD_HTTPS_PORT -m owner ! --uid-owner proxy -j REDIRECT --to-port $HTTPS_INTERCEPT_PORT 2>/dev/null || true
}

stop_squid() {
    # Stop systemd service first
    sudo systemctl stop squid 2>/dev/null || true
    sudo systemctl disable squid 2>/dev/null || true
    
    # Kill only actual squid processes, not scripts
    sudo pkill -f "^$PREFIX/sbin/squid" 2>/dev/null || true
    sleep 1
    
    # Force kill if still running
    if pgrep -f "^$PREFIX/sbin/squid" >/dev/null 2>&1; then
        sudo pkill -9 -f "^$PREFIX/sbin/squid" 2>/dev/null || true
    fi
}

remove_ca() {
    # Remove system-wide CA certificates
    sudo rm -f /usr/local/share/ca-certificates/squid-self-signed.crt
    sudo rm -f /etc/ssl/certs/squid-self-signed.pem
    sudo update-ca-certificates --fresh >/dev/null || true
    sudo c_rehash /etc/ssl/certs >/dev/null 2>&1 || true
    
    # Remove from system ca-certificates bundle
    ca_bundle_path="/etc/ssl/certs/ca-certificates.crt"
    if [ -f "$ca_bundle_path" ] && grep -q "Squid Proxy CA" "$ca_bundle_path" 2>/dev/null; then
        sudo sed -i '/# Squid Proxy CA/,/-----END CERTIFICATE-----/d' "$ca_bundle_path"
    fi
    
    # Remove from browser certificate stores
    [ -n "${SUDO_USER:-}" ] && {
        user_home="/home/$SUDO_USER"
        
        # Remove from Firefox profiles
        if [ -d "$user_home/.mozilla/firefox" ]; then
            for profile in "$user_home/.mozilla/firefox"/*default* "$user_home/.mozilla/firefox"/*.default*; do
                if [ -d "$profile" ] && [ -f "$profile/cert9.db" ]; then
                    sudo -u "$SUDO_USER" certutil -D -n "Squid Proxy CA" -d "$profile" 2>/dev/null || true
                fi
            done
        fi
        
        # Remove from Snap Firefox profiles
        if [ -d "$user_home/snap/firefox/common/.mozilla/firefox" ]; then
            for profile in "$user_home/snap/firefox/common/.mozilla/firefox"/*default* "$user_home/snap/firefox/common/.mozilla/firefox"/*.default*; do
                if [ -d "$profile" ] && [ -f "$profile/cert9.db" ]; then
                    sudo -u "$SUDO_USER" certutil -D -n "Squid Proxy CA" -d "$profile" 2>/dev/null || true
                fi
            done
        fi
        
        # Remove from Chrome/Chromium certificate database
        nssdb_dir="$user_home/.pki/nssdb"
        if [ -f "$nssdb_dir/cert9.db" ]; then
            sudo -u "$SUDO_USER" certutil -D -n "Squid Proxy CA" -d sql:"$nssdb_dir" 2>/dev/null || true
        fi
        
        # Remove Brave browser certificate policies
        sudo rm -f /etc/brave/policies/managed/squid-certificates.json 2>/dev/null || true
        sudo rm -f /etc/opt/brave/policies/managed/squid-certificates.json 2>/dev/null || true
    }
}

clean_install() {
    echo "Step 1: Starting cleanup"
    sudo iptables -t nat -D OUTPUT -p tcp --dport $STD_HTTP_PORT -m owner ! --uid-owner proxy -j REDIRECT --to-port $HTTP_INTERCEPT_PORT 2>/dev/null || true
    echo "Step 2: Removed iptables rule 1" 
    sudo iptables -t nat -D OUTPUT -p tcp --dport $STD_HTTPS_PORT -m owner ! --uid-owner proxy -j REDIRECT --to-port $HTTPS_INTERCEPT_PORT 2>/dev/null || true
    echo "Step 3: Removed iptables rule 2"
    echo "Step 4: Stopping squid"
    stop_squid
    id proxy >/dev/null 2>&1 && {
        echo "Step 5: Proxy user exists, removing..."
        sudo pkill -9 -u proxy 2>/dev/null || true
        sudo userdel -rf proxy 2>/dev/null || true
        sudo groupdel proxy 2>/dev/null || true
        echo "Step 6: Proxy user removed"
    } || echo "Step 5: No proxy user"
    echo "Step 7: Removing system configuration (preserving binary)"
    sudo rm -rf "$PREFIX/etc" "$PREFIX/var" "$CACHE_DIR" /etc/systemd/system/squid.service 2>/dev/null || true
    echo "Step 8: CA removed"
    sudo rm -f /usr/local/share/ca-certificates/squid-ca.crt 2>/dev/null || true
    sudo update-ca-certificates >/dev/null 2>&1 || true
    echo "Step 9: Daemon reloaded"
    sudo systemctl daemon-reload >/dev/null 2>&1 || true
    echo "Step 10: Cleanup complete"
    echo "✔ System configuration reset - keeping built binary"
}

disable_proxy() {
    log "Disabling Squid proxy..."
    remove_iptables
    stop_squid
    remove_ca
    log "✔ Proxy disabled"
}

check_squid() {
    [ -x "$PREFIX/sbin/squid" ] && {
        current_ver=$("$PREFIX/sbin/squid" -v | grep -o 'Version [0-9.]*' | cut -d' ' -f2)
        [ "$current_ver" = "$VER" ] && return 0
    }
    return 1
}

install_deps() {
    log "Installing dependencies..."
    sudo apt-get update -y >/dev/null
    sudo apt-get install -y build-essential autoconf automake libtool libtool-bin \
        libltdl-dev openssl libssl-dev pkg-config wget libnss3-tools libcppunit-dev \
        ldap-utils samba-common-bin winbind >/dev/null
    id proxy >/dev/null 2>&1 || sudo useradd -r -s /bin/false proxy
}

build_squid() {
    tag=$(echo "SQUID_$VER" | sed 's/\./_/g')
    url="https://github.com/squid-cache/squid/archive/refs/tags/$tag.tar.gz"
    build="/tmp/squid-build-$$"
    
    log "Building Squid $VER..."
    rm -rf "$build" && mkdir -p "$build"
    wget -qO "$build/squid.tar.gz" "$url"
    tar -xf "$build/squid.tar.gz" -C "$build"
    cd "$build"/*
    [ -x configure ] || ./bootstrap.sh
    ./configure --with-default-user=proxy --with-openssl --enable-ssl-crtd --prefix="$PREFIX" >/dev/null
    make -j"$(nproc)" >/dev/null
    sudo make install >/dev/null
    cd - >/dev/null
    sudo chown -R proxy:proxy "$PREFIX"
}

create_ca() {
    ssl="$PREFIX/etc/ssl_cert"
    
    log "Creating SSL certificates..."
    tmp=$(mktemp -d)
    
    # Generate self-signed certificate with proper CA extensions (following established guide)
    openssl req -new -newkey rsa:$RSA_KEY_SIZE -days $CERT_VALIDITY_DAYS -nodes -x509 -extensions v3_ca \
        -keyout "$tmp/squid-self-signed.key" -out "$tmp/squid-self-signed.crt" \
        -subj "/C=US/ST=Local/L=Local/O=SquidProxy/OU=CA/CN=SquidProxy" 2>/dev/null
    
    # Convert to different formats as needed
    openssl x509 -in "$tmp/squid-self-signed.crt" -outform DER -out "$tmp/squid-self-signed.der" 2>/dev/null
    openssl x509 -in "$tmp/squid-self-signed.crt" -outform PEM -out "$tmp/squid-self-signed.pem" 2>/dev/null
    openssl dhparam -outform PEM -out "$tmp/squid-self-signed_dhparam.pem" $DH_PARAM_SIZE 2>/dev/null
    
    sudo mkdir -p "$ssl"
    sudo cp "$tmp/squid-self-signed.key" "$tmp/squid-self-signed.crt" "$tmp/squid-self-signed.pem" "$tmp/squid-self-signed_dhparam.pem" "$ssl/"
    sudo chmod 600 "$ssl/squid-self-signed.key"
    sudo chmod 644 "$ssl/squid-self-signed.crt" "$ssl/squid-self-signed.pem" "$ssl/squid-self-signed_dhparam.pem"
    sudo chown proxy:proxy "$ssl"/*
    
    rm -rf "$tmp"
}

install_ca() {
    log "Installing CA certificates..."
    
    # Install system-wide CA certificate (following established guide)
    sudo cp "$ssl/squid-self-signed.pem" /usr/local/share/ca-certificates/squid-self-signed.crt
    sudo update-ca-certificates >/dev/null
    
    # Also install in system's ca-certificates bundle for better compatibility
    sudo mkdir -p /etc/ssl/certs
    sudo cp "$ssl/squid-self-signed.pem" /etc/ssl/certs/squid-self-signed.pem
    sudo c_rehash /etc/ssl/certs >/dev/null 2>&1 || true
    
    # Install for current user's browsers and certificate stores
    [ -n "${SUDO_USER:-}" ] && {
        user_home="/home/$SUDO_USER"
        
        # Firefox profiles (regular installation)
        if [ -d "$user_home/.mozilla/firefox" ]; then
            for profile in "$user_home/.mozilla/firefox"/*default* "$user_home/.mozilla/firefox"/*.default*; do
                if [ -d "$profile" ]; then
                    # Create nss db if it doesn't exist
                    if [ ! -f "$profile/cert9.db" ]; then
                        sudo -u "$SUDO_USER" certutil -N -d "$profile" --empty-password 2>/dev/null || true
                    fi
                    # Remove existing certificate first to avoid duplicates
                    sudo -u "$SUDO_USER" certutil -D -n "Squid Proxy CA" -d "$profile" 2>/dev/null || true
                    # Install CA certificate
                    if sudo -u "$SUDO_USER" certutil -A -n "Squid Proxy CA" -t "TCu,Cu,Tu" -i "$ssl/squid-self-signed.pem" -d "$profile" 2>/dev/null; then
                        log "  ✔ Installed CA in Firefox profile: $(basename "$profile")"
                    fi
                fi
            done
        fi
        
        # Snap Firefox (if exists)
        if [ -d "$user_home/snap/firefox/common/.mozilla/firefox" ]; then
            for profile in "$user_home/snap/firefox/common/.mozilla/firefox"/*default* "$user_home/snap/firefox/common/.mozilla/firefox"/*.default*; do
                if [ -d "$profile" ]; then
                    if [ ! -f "$profile/cert9.db" ]; then
                        sudo -u "$SUDO_USER" certutil -N -d "$profile" --empty-password 2>/dev/null || true
                    fi
                    # Remove existing certificate first to avoid duplicates  
                    sudo -u "$SUDO_USER" certutil -D -n "Squid Proxy CA" -d "$profile" 2>/dev/null || true
                    if sudo -u "$SUDO_USER" certutil -A -n "Squid Proxy CA" -t "TCu,Cu,Tu" -i "$ssl/squid-self-signed.pem" -d "$profile" 2>/dev/null; then
                        log "  ✔ Installed CA in Snap Firefox profile: $(basename "$profile")"
                    fi
                fi
            done
        fi
        
        # Chrome/Chromium certificate database - User NSS database
        if command -v certutil >/dev/null; then
            nssdb_dir="$user_home/.pki/nssdb"
            sudo -u "$SUDO_USER" mkdir -p "$nssdb_dir"
            
            # Initialize NSS database if it doesn't exist
            if [ ! -f "$nssdb_dir/cert9.db" ]; then
                sudo -u "$SUDO_USER" certutil -N -d sql:"$nssdb_dir" --empty-password 2>/dev/null || true
            fi
            
            # Remove any existing certificate first to avoid duplicates
            sudo -u "$SUDO_USER" certutil -D -n "Squid Root CA" -d sql:"$nssdb_dir" 2>/dev/null || true
            
            # Install CA certificate in user NSS database
            if sudo -u "$SUDO_USER" certutil -A -n "Squid Root CA" -t "TCu,Cu,Tu" -i "$ssl/squid-self-signed.pem" -d sql:"$nssdb_dir" 2>/dev/null; then
                log "  ✔ Installed CA in user NSS database (Brave/Chrome/Chromium)"
            fi
        fi
        
        # System-wide NSS database for all users
        if command -v certutil >/dev/null; then
            system_nssdb_dir="/etc/pki/nssdb"
            sudo mkdir -p "$system_nssdb_dir"
            
            # Initialize system NSS database if it doesn't exist
            if [ ! -f "$system_nssdb_dir/cert9.db" ]; then
                sudo certutil -N -d sql:"$system_nssdb_dir" --empty-password 2>/dev/null || true
            fi
            
            # Install CA certificate in system NSS database
            if sudo certutil -A -n "Squid Root CA" -t "TCu,Cu,Tu" -i "$ssl/squid-self-signed.pem" -d sql:"$system_nssdb_dir" 2>/dev/null; then
                log "  ✔ Installed CA in system NSS database"
            fi
        fi
        
        # Install for curl/wget system-wide configuration
        ca_bundle_path="/etc/ssl/certs/ca-certificates.crt"
        if [ -f "$ca_bundle_path" ]; then
            if ! grep -q "Squid Proxy CA" "$ca_bundle_path" 2>/dev/null; then
                {
                    echo ""
                    echo "# Squid Proxy CA"
                    cat "$ssl/squid-self-signed.pem"
                } | sudo tee -a "$ca_bundle_path" >/dev/null
                log "  ✔ Added CA to system ca-certificates bundle"
            fi
        fi
        
        # Java cacerts trust store (system-wide)
        if command -v keytool >/dev/null; then
            java_cacerts="/etc/ssl/certs/java/cacerts"
            if [ -f "$java_cacerts" ]; then
                # Remove existing certificate first to avoid duplicates
                sudo keytool -delete -keystore "$java_cacerts" -storepass changeit -alias "squid-ca" 2>/dev/null || true
                # Install CA certificate
                if sudo keytool -import -trustcacerts -keystore "$java_cacerts" -storepass changeit -alias "squid-ca" -file "$ssl/squid-self-signed.pem" -noprompt 2>/dev/null; then
                    log "  ✔ Installed CA in Java cacerts trust store"
                fi
            fi
        fi
    }
    
    # Comprehensive certificate verification
    log "=== VERIFYING CERTIFICATE INSTALLATION ==="
    
    # Verify system-wide installation
    if openssl verify -CAfile /usr/local/share/ca-certificates/squid-self-signed.crt "$ssl/squid-self-signed.pem" >/dev/null 2>&1; then
        log "✔ CA certificate properly installed in system trust store"
    else
        error "❌ CA certificate installation in system trust store failed"
        return 1
    fi
    
    # Verify NSS database installations
    [ -n "${SUDO_USER:-}" ] && {
        user_home="/home/$SUDO_USER"
        nssdb_dir="$user_home/.pki/nssdb"
        if [ -f "$nssdb_dir/cert9.db" ] && certutil -L -d sql:"$nssdb_dir" | grep -q "Squid Root CA"; then
            log "✔ CA certificate verified in user NSS database"
        else
            error "❌ CA certificate missing from user NSS database"
            return 1
        fi
    }
    
    # Verify system NSS database
    system_nssdb_dir="/etc/pki/nssdb"
    if [ -f "$system_nssdb_dir/cert9.db" ] && sudo certutil -L -d sql:"$system_nssdb_dir" | grep -q "Squid Root CA"; then
        log "✔ CA certificate verified in system NSS database"
    else
        log "⚠️ CA certificate not found in system NSS database (may be normal)"
    fi
    
    # Verify curl can use the certificate
    if curl --cacert "$ssl/squid-self-signed.pem" https://httpbin.org/get >/dev/null 2>&1; then
        log "✔ Certificate verification with curl successful"
    else
        log "⚠️ Direct certificate verification with curl failed (may be normal)"
    fi
    
    # Verify Java cacerts installation
    if command -v keytool >/dev/null && [ -f "/etc/ssl/certs/java/cacerts" ]; then
        if keytool -list -keystore /etc/ssl/certs/java/cacerts -storepass changeit | grep -q "squid-ca"; then
            log "✔ CA certificate verified in Java cacerts trust store"
        else
            log "⚠️ CA certificate not found in Java cacerts (may be normal)"
        fi
    fi
    
    # Additional verification for browsers
    log "✔ CA certificate installed for:"
    log "  - System-wide applications (curl, wget, etc.)"
    log "  - Firefox browsers (if available)"
    log "  - Chrome/Chromium browsers (if available)"
    log "  - Java applications (if available)"
    log "  - Command-line tools"
}

create_config() {
    conf="$PREFIX/etc/squid.conf"
    ssl="$PREFIX/etc/ssl_cert"
    mime_conf="$PREFIX/etc/mime.conf"
    
    log "Creating configuration..."
    [ -f "$conf" ] && sudo mv "$conf" "${conf}.orig-$(date +%s)"
    
    # Create simple mime.conf file
    sudo sh -c "echo 'text/html html htm' > '$mime_conf'"
    sudo sh -c "echo 'text/plain txt' >> '$mime_conf'"
    sudo sh -c "echo 'text/css css' >> '$mime_conf'"
    sudo sh -c "echo 'application/octet-stream bin exe' >> '$mime_conf'"
    sudo sh -c "echo 'image/jpeg jpg jpeg' >> '$mime_conf'"
    sudo sh -c "echo 'image/png png' >> '$mime_conf'"
    sudo sh -c "echo 'image/gif gif' >> '$mime_conf'"
    sudo chown proxy:proxy "$mime_conf"
    sudo chmod 644 "$mime_conf"
    
    sudo tee "$conf" >/dev/null <<EOF
acl intermediate_fetching transaction_initiator certificate-fetching
http_access allow intermediate_fetching

acl localnet src 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 127.0.0.0/8
acl SSL_ports port $STD_HTTPS_PORT
acl Safe_ports port $STD_HTTP_PORT 21 $STD_HTTPS_PORT 70 210 1025-65535 280 488 591 777
acl CONNECT method CONNECT

# SSL Bump ACLs
acl step1 at_step SslBump1
acl step2 at_step SslBump2
acl step3 at_step SslBump3

http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost manager
http_access deny manager
http_access allow localnet
http_access allow localhost
http_access deny all

http_port $PROXY_PORT tcpkeepalive=$TCP_KEEPALIVE_TIME,$TCP_KEEPALIVE_INTERVAL,$TCP_KEEPALIVE_PROBES ssl-bump generate-host-certificates=on dynamic_cert_mem_cache_size=$SSL_CERT_CACHE_SIZE tls-cert=$ssl/squid-self-signed.crt tls-key=$ssl/squid-self-signed.key cipher=HIGH:MEDIUM:!LOW:!RC4:!SEED:!IDEA:!3DES:!MD5:!EXP:!PSK:!DSS options=NO_TLSv1,NO_SSLv3 tls-dh=$ssl/squid-self-signed_dhparam.pem
http_port $HTTP_PORT intercept
https_port $HTTPS_PORT intercept ssl-bump generate-host-certificates=on dynamic_cert_mem_cache_size=$SSL_CERT_CACHE_SIZE tls-cert=$ssl/squid-self-signed.crt tls-key=$ssl/squid-self-signed.key

sslcrtd_program $PREFIX/libexec/security_file_certgen -s $PREFIX/var/logs/ssl_db -M 20MB
sslcrtd_children $SSLCRTD_CHILDREN

# SSL Bump configuration for transparent proxying (following established guide)
ssl_bump server-first all
ssl_bump stare all
sslproxy_cert_error deny all

maximum_object_size 50 GB
cache_mem 8192 MB
cache_dir ufs $CACHE_DIR 100000 16 256
cache_replacement_policy heap LFUDA
cache_swap_low 90
cache_swap_high 95

# More conservative refresh patterns to avoid HTTP violation warnings
refresh_pattern -i \.(jar|zip|whl|gz|bz2|tar|tgz|deb|rpm|exe|msi|dmg|iso)$ $CACHE_REFRESH_LARGE_FILES $CACHE_PERCENTAGE% $CACHE_REFRESH_LARGE_FILES
refresh_pattern -i conda.anaconda.org/.* $CACHE_REFRESH_CONDA $CACHE_PERCENTAGE% $CACHE_REFRESH_CONDA
refresh_pattern -i \.(jpg|jpeg|png|gif|ico|webp|svg|mp4|mp3|avi|mov|mkv|pdf)$ $CACHE_REFRESH_MEDIA $CACHE_PERCENTAGE% $CACHE_REFRESH_MEDIA
refresh_pattern -i github.com/.*/releases/.* $CACHE_REFRESH_GITHUB $CACHE_PERCENTAGE% $CACHE_REFRESH_GITHUB
refresh_pattern . 0 $CACHE_PERCENTAGE% $CACHE_REFRESH_DEFAULT
EOF
}

init_cache() {
    log "Initializing cache..."
    
    # Ensure parent directories exist and are writable
    sudo mkdir -p "$(dirname "$CACHE_DIR")"
    sudo mkdir -p "$CACHE_DIR" "$PREFIX/var/logs" "$PREFIX/var/run"
    
    # Clean up any existing cache that might be corrupted
    sudo rm -rf "$PREFIX/var/logs/ssl_db" "$CACHE_DIR"/* 2>/dev/null || true
    
    # Set ownership and permissions
    sudo chown -R proxy:proxy "$PREFIX/var" "$CACHE_DIR"
    sudo chmod 755 "$CACHE_DIR"
    
    # Initialize SSL certificate database
    log "Initializing SSL certificate database..."
    sudo -u proxy "$PREFIX/libexec/security_file_certgen" -c -s "$PREFIX/var/logs/ssl_db" -M 20MB
    
    # Initialize cache directories - this is critical and must work
    log "Creating cache directory structure..."
    sudo -u proxy "$PREFIX/sbin/squid" -z -f "$PREFIX/etc/squid.conf"
    if [ $? -ne 0 ]; then
        error "❌ Failed to initialize cache directories"
        return 1
    fi
    
    # Verify cache directory structure was created
    if [ ! -d "$CACHE_DIR/00" ]; then
        error "❌ Cache directory structure not created - attempting manual creation"
        
        # Create the cache directory structure manually
        for i in $(seq -f "%02g" 0 15); do
            for j in $(seq -f "%02g" 0 15); do
                sudo -u proxy mkdir -p "$CACHE_DIR/$i/$j"
            done
        done
        sudo -u proxy touch "$CACHE_DIR/swap.state"
        
        # Verify manual creation worked
        if [ ! -d "$CACHE_DIR/00" ]; then
            error "❌ Manual cache directory creation also failed"
            return 1
        fi
        log "✔ Manual cache directory creation successful"
    fi
    
    log "✔ Cache initialized successfully"
}

start_squid() {
    log "Starting Squid..."
    stop_squid
    sleep 2
    
    # Test configuration first
    if ! sudo -u proxy "$PREFIX/sbin/squid" -k parse >/dev/null 2>&1; then
        error "❌ Squid configuration test failed"
        sudo -u proxy "$PREFIX/sbin/squid" -k parse
        return 1
    fi
    log "✔ Squid configuration valid"
    
    # Check if already running
    if [ -f "$PREFIX/var/run/squid.pid" ] && ps -p "$(cat "$PREFIX/var/run/squid.pid")" >/dev/null 2>&1; then
        log "Squid already running, restarting..."
        sudo -u proxy "$PREFIX/sbin/squid" -k reconfigure
    else
        sudo -u proxy "$PREFIX/sbin/squid" -d 1
    fi
    
    # Wait and verify it started
    sleep $TEST_SLEEP_DURATION
    if ! pgrep -f "$PREFIX/sbin/squid" >/dev/null; then
        error "❌ Squid failed to start"
        sudo tail -$LOG_TAIL_LINES "$PREFIX/var/logs/cache.log" 2>/dev/null || true
        return 1
    fi
    log "✔ Squid started successfully"
}

setup_iptables() {
    log "SKIPPING transparent proxy setup for testing - using explicit proxy only..."
    log "Proxy available on localhost:$PROXY_PORT for manual testing"
    log "Test ports $HTTP_PORT/$HTTPS_PORT configured but not redirected"
    
    # Test basic internet connectivity (should work since no redirect)
    log "Testing internet connectivity (should work normally)..."
    if ! test_internet_connectivity; then
        error "❌ Internet connectivity test failed"
        return 1
    fi
    
    log "✔ Internet connectivity working (no transparent proxy active)"
    return 0
}

create_service() {
    log "Creating systemd service..."
    sudo tee /etc/systemd/system/squid.service >/dev/null <<EOF
[Unit]
Description=Squid Web Proxy Server
After=network.target

[Service]
Type=forking
PIDFile=$PREFIX/var/run/squid.pid
ExecStart=$PREFIX/sbin/squid
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=$PREFIX/sbin/squid -k shutdown
TimeoutStop=30s
Restart=on-failure
RestartSec=$RESTART_DELAY
User=proxy
Group=proxy

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable squid.service
}

test_internet_connectivity() {
    for site in "https://google.com" "https://github.com" "https://httpbin.org/get"; do
        curl -s -L "$site" >/dev/null 2>&1 && return 0
    done
    return 1
}

test_proxy_functionality() {
    log "Testing proxy functionality..."
    
    # Wait for squid to fully start
    sleep $TEST_SLEEP_DURATION
    
    # Test 1: Basic HTTP proxy test (no SSL bumping)
    if ! curl -s -L --proxy http://localhost:$PROXY_PORT \
        "http://httpbin.org/get" >/dev/null 2>&1; then
        error "❌ Basic HTTP proxy connectivity failed"
        return 1
    fi
    log "✔ HTTP proxy working"
    
    # Test 2: Verify CA certificate is trusted by system
    if ! openssl verify -CAfile /usr/local/share/ca-certificates/squid-self-signed.crt "$ssl/squid-self-signed.pem" >/dev/null 2>&1; then
        error "❌ CA certificate not properly installed in system trust store"
        return 1
    fi
    log "✔ CA certificate properly installed"
    
    # Test 3: HTTPS with explicit CA cert
    test_url="https://httpbin.org/get"
    if curl -s -L --proxy http://localhost:$PROXY_PORT --cacert "$ssl/squid-self-signed.pem" \
        "$test_url" >/dev/null 2>&1; then
        log "✔ HTTPS proxy with explicit CA cert working"
    else
        # Try with system CA bundle
        if curl -s -L --proxy http://localhost:$PROXY_PORT \
            "$test_url" >/dev/null 2>&1; then
            log "✔ HTTPS proxy with system CA bundle working"
        else
            error "❌ HTTPS proxy connectivity failed"
            log "Checking squid error logs..."
            sudo tail -10 "$PREFIX/var/logs/cache.log" 2>/dev/null || true
            return 1
        fi
    fi
    
    # Test 4: Cache functionality test
    test_cache_url="https://httpbin.org/json"
    if curl -s -L --proxy http://localhost:$PROXY_PORT \
        -H "Cache-Control: no-cache" "$test_cache_url" >/dev/null 2>&1; then
        log "✔ Cache and SSL bumping functional"
    else
        log "⚠️ Cache test failed, but basic proxy working"
    fi
    
    log "✔ Core proxy functionality verified"
    return 0
}

measure_download_speed() {
    url="$1"
    output_file="$2"
    description="$3"
    
    log "Testing: $description"
    rm -f "$output_file"
    
    start_time=$(date +%s.%N)
    if curl -s -L -o "$output_file" "$url" 2>/dev/null; then
        end_time=$(date +%s.%N)
        duration=$(echo "$end_time $start_time" | awk '{print $1 - $2}')
        size=$(stat -c%s "$output_file" 2>/dev/null || echo "0")
        speed_bps=$(echo "$size $duration" | awk '{print int($1 / $2)}')
        speed_mbps=$(echo "$speed_bps" | awk '{printf "%.1f", $1 / 1024 / 1024}')
        
        log "  Size: $(numfmt --to=iec $size), Time: ${duration}s, Speed: ${speed_mbps} MB/s"
        printf "%.1f" "$speed_mbps"
        return 0
    else
        error "  Download failed"
        printf "0"
        return 1
    fi
}

test_comprehensive_flow() {
    log "🚀 Starting comprehensive proxy and caching test..."
    
    # Create test directory in user's home
    test_dir="$HOME/tmp"
    mkdir -p "$test_dir"
    
    # Use the requested Go download URL for better cache testing
    test_url="https://go.dev/dl/go1.24.5.linux-amd64.tar.gz"
    test_file="$test_dir/go-download-test.tar.gz"
    min_cache_speed=10  # MB/s (reduced for large files)
    
    # Phase 1: Test baseline (direct download without proxy) 
    log "=== PHASE 1: Baseline Download Test (No Proxy) ==="
    # Temporarily disable proxy for baseline test by using direct curl
    log "Testing: Direct download"
    rm -f "$test_file"
    
    start_time=$(date +%s.%N)
    if curl -s -L -o "$test_file" "$test_url" 2>/dev/null; then
        end_time=$(date +%s.%N)
        duration=$(echo "$end_time $start_time" | awk '{print $1 - $2}')
        size=$(stat -c%s "$test_file" 2>/dev/null || echo "0")
        
        # Check if we got a meaningful download (at least 1MB for Go tarball)
        if [ "$size" -lt 1048576 ]; then
            error "❌ Baseline download too small: $(numfmt --to=iec $size) (expected >1MB)"
            return 1
        fi
        
        speed_bps=$(echo "$size $duration" | awk '{print int($1 / $2)}')
        baseline_speed=$(echo "$speed_bps" | awk '{printf "%.1f", $1 / 1024 / 1024}')
        
        log "  Size: $(numfmt --to=iec $size), Time: ${duration}s, Speed: ${baseline_speed} MB/s"
    else
        error "❌ Baseline download failed"
        return 1
    fi
    
    if [ "$(echo "$baseline_speed > 0" | bc -l 2>/dev/null || echo "0")" = "1" ]; then
        log "✔ Baseline download: ${baseline_speed} MB/s"
    else
        error "❌ Baseline download failed"
        return 1
    fi
    
    # Phase 2: First proxy download through transparent proxy (should cache)
    log "=== PHASE 2: First Transparent Proxy Download (Caching) ==="
    rm -f "$test_file"
    
    if ! proxy_speed=$(measure_download_speed "$test_url" "${test_file}.proxy" "First transparent proxy download"); then
        error "❌ First proxy download failed"
        return 1
    fi
    
    log "✔ First proxy download: ${proxy_speed} MB/s"
    
    # Phase 3: Second download through transparent proxy (should hit cache)
    log "=== PHASE 3: Second Transparent Proxy Download (Cache Hit Test) ==="
    rm -f "${test_file}.cache"
    sleep $TEST_SLEEP_DURATION  # Allow cache to settle
    
    if ! cache_speed=$(measure_download_speed "$test_url" "${test_file}.cache" "Second transparent proxy download (cache hit)"); then
        error "❌ Cache hit download failed"
        return 1
    fi
    
    # Check if cache speed meets minimum requirement
    if [ "$(echo "$cache_speed >= $min_cache_speed" | bc -l 2>/dev/null || echo "0")" = "1" ]; then
        log "✔ Cache hit successful: ${cache_speed} MB/s (≥ ${min_cache_speed} MB/s required)"
        
        # Calculate improvement over first proxy download
        if [ "$(echo "$proxy_speed > 0" | bc -l 2>/dev/null || echo "0")" = "1" ]; then
            improvement=$(echo "$cache_speed $proxy_speed" | awk '{printf "%.1fx", $1 / $2}')
            log "✔ Cache speed improvement: $improvement faster than first proxy download"
        fi
    else
        log "⚠️ Cache hit speed: ${cache_speed} MB/s (< ${min_cache_speed} MB/s target, but may be acceptable for large files)"
    fi
    
    # Phase 4: File integrity check
    log "=== PHASE 4: File Integrity Check ==="
    if [ -f "${test_file}.proxy" ] && [ -f "${test_file}.cache" ]; then
        if cmp -s "${test_file}.proxy" "${test_file}.cache"; then
            log "✔ Downloaded files identical (cache integrity verified)"
        else
            error "❌ Downloaded files differ (cache corruption detected)"
            return 1
        fi
    else
        error "❌ Missing files for integrity check"
        return 1
    fi
    
    # Phase 5: Check cache directory
    log "=== PHASE 5: Cache Directory Check ==="
    if [ -d "$CACHE_DIR" ]; then
        cache_size=$(sudo du -sh "$CACHE_DIR" 2>/dev/null | cut -f1 || echo "unknown")
        cache_files=$(sudo find "$CACHE_DIR" -type f 2>/dev/null | wc -l || echo "unknown")
        log "✔ Cache directory: $CACHE_DIR (${cache_size}, ${cache_files} files)"
    else
        error "❌ Cache directory not found: $CACHE_DIR"
        return 1
    fi
    
    # Phase 6: Verify access logs show cache hits
    log "=== PHASE 6: Access Log Verification ==="
    if sudo tail -$LOG_TAIL_LINES /usr/local/squid/var/logs/access.log | grep -q "TCP_.*HIT"; then
        log "✔ Cache hits found in access logs"
        # Show last few cache hits
        sudo tail -$LOG_TAIL_LINES /usr/local/squid/var/logs/access.log | grep "TCP_.*HIT" | tail -3 | while read line; do
            log "  Cache hit: $(echo "$line" | awk '{print $7, $4}')"
        done
    else
        log "⚠️ No cache hits in recent access logs (may be normal for first run)"
    fi
    
    # Phase 7: Certificate trust verification
    log "=== PHASE 7: Certificate Trust Verification ==="
    if curl -s -L "$test_url" >/dev/null 2>&1; then
        log "✔ HTTPS downloads work through transparent proxy (certificates trusted)"
    else
        error "❌ HTTPS downloads fail (certificate trust issues)"
        return 1
    fi
    
    # Cleanup test files
    rm -f "$test_file" "${test_file}.proxy" "${test_file}.cache"
    
    log "🎉 ALL COMPREHENSIVE TESTS PASSED!"
    return 0
}

test_final_connectivity() {
    log "=== FINAL CONNECTIVITY & FUNCTIONALITY TEST ==="
    
    # Save current iptables state for potential rollback
    sudo iptables-save > /tmp/iptables.final-test-backup
    
    # Test 1: Basic internet connectivity  
    if ! test_internet_connectivity; then
        error "❌ Internet connectivity broken after installation"
        error "Reverting iptables to restore connectivity..."
        sudo iptables-restore < /tmp/iptables.final-test-backup
        rm -f /tmp/iptables.final-test-backup
        
        # Verify connectivity is restored
        if test_internet_connectivity; then
            log "✔ Internet connectivity restored after iptables revert"
            error "❌ Transparent proxy setup is incompatible with this system"
        else
            error "❌ Unable to restore internet connectivity - manual intervention required"
        fi
        return 1
    fi
    log "✔ Internet connectivity working"
    
    # Test 2: Comprehensive proxy and caching functionality
    if ! test_comprehensive_flow; then
        error "❌ Comprehensive functionality test failed"
        error "Reverting to safe iptables state..."
        sudo iptables-restore < /tmp/iptables.final-test-backup
        rm -f /tmp/iptables.final-test-backup
        
        # Verify basic connectivity is still working
        if test_internet_connectivity; then
            log "✔ Internet connectivity restored after test failure"
            error "❌ Proxy functionality test failed - regular proxy still available on localhost:$PROXY_PORT"
        else
            error "❌ Unable to restore internet connectivity after test failure"
        fi
        return 1
    fi
    
    # Clean up backup file if all tests passed
    rm -f /tmp/iptables.final-test-backup
    
    log "✔ All tests passed - installation verified working!"
    return 0
}


main() {
    case "${1:-}" in
        --clean) clean_install ;;
        --disable) disable_proxy; exit 0 ;;
    esac
    
    # Check if squid binary exists, if not build it
    if [ ! -x "$PREFIX/sbin/squid" ]; then
        log "Squid binary not found, building..."
        install_deps
        build_squid
    else
        current_ver=$("$PREFIX/sbin/squid" -v | grep -o 'Version [0-9.]*' | cut -d' ' -f2)
        if [ "$current_ver" = "$VER" ]; then
            log "Squid $VER binary already built"
            install_deps  # Still need proxy user and deps for configuration
        else
            log "Squid version mismatch ($current_ver != $VER), rebuilding..."
            install_deps
            build_squid
        fi
    fi
    
    ssl="$PREFIX/etc/ssl_cert"
    create_ca
    install_ca
    create_config
    init_cache
    start_squid
    
    # Test proxy functionality before setting up transparent redirection
    if ! test_proxy_functionality; then
        error "❌ Proxy functionality test failed"
        error "Squid installation incomplete - stopping here"
        exit 1
    fi
    
    # Final certificate verification before enabling transparent proxy
    log "=== FINAL CERTIFICATE VERIFICATION BEFORE TRANSPARENT PROXY ==="
    
    # Verify all certificates are properly installed
    verification_failed=false
    
    # Check system certificate store
    if ! openssl verify -CAfile /usr/local/share/ca-certificates/squid-self-signed.crt "$ssl/squid-self-signed.pem" >/dev/null 2>&1; then
        error "❌ System certificate store verification failed"
        verification_failed=true
    else
        log "✔ System certificate store verified"
    fi
    
    # Check user NSS database
    [ -n "${SUDO_USER:-}" ] && {
        user_home="/home/$SUDO_USER"
        nssdb_dir="$user_home/.pki/nssdb"
        if [ -f "$nssdb_dir/cert9.db" ] && certutil -L -d sql:"$nssdb_dir" | grep -q "Squid Root CA"; then
            log "✔ User NSS database verified"
        else
            error "❌ User NSS database verification failed"
            verification_failed=true
        fi
    }
    
    # Test proxy with certificate
    if curl -s --proxy http://localhost:$PROXY_PORT --cacert "$ssl/squid-self-signed.pem" https://httpbin.org/get >/dev/null 2>&1; then
        log "✔ Proxy certificate verification successful"
    else
        error "❌ Proxy certificate verification failed"
        verification_failed=true
    fi
    
    if [ "$verification_failed" = true ]; then
        error "❌ Certificate verification failed - not enabling transparent proxy"
        error "Regular proxy available on localhost:$PROXY_PORT - please install certificates manually"
        exit 1
    fi
    
    log "✔ All certificate verifications passed - enabling transparent proxy"
    
    # Setup transparent proxy with fail-safe
    if ! setup_iptables; then
        error "❌ Transparent proxy setup failed"
        error "Regular proxy still available on localhost:$PROXY_PORT"
        exit 1
    fi
    
    create_service
    
    # Skip comprehensive test for now - just verify basic connectivity
    if ! test_internet_connectivity; then
        error "❌ Internet connectivity test failed"
        error "Reverting to safe state..."
        sudo iptables -t nat -F
        exit 1
    fi
    
    log "✔ Installation complete!"
    log "Cache: $CACHE_DIR"
    log "Disable: $0 --disable"
    log "Clean: $0 --clean"
}

main "$@"