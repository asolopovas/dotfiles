#!/bin/bash

# install-squid.sh
#
# This script builds and configures Squid proxy version 7.1 from source on
# Debian/Ubuntu based systems (such as Linux Mint). It automates the
# installation of prerequisites, downloads the Squid 7.1 source code,
# compiles it with SSL bumping support, configures OpenSSL and Squid for
# HTTPS caching, and initializes the proxy.  The configuration is based on
# the guide provided by the user, but adapted to use Squid 7.1 instead
# of 5.1.  You can run this script as a normal user; it will invoke
# `sudo` where necessary.  For unattended operation you may be prompted
# for your sudo password.

# Stop on any error.
set -e

# Define variables for the Squid version and download URL.  The
# GitHub release tarball is used as the source.  The original URL is
# documented on Fossies as the canonical location for the SQUID_7_1
# release【942562258824788†L18-L20】.
SQUID_VERSION="7.1"
SQUID_TAG="SQUID_7_1"
SQUID_TARBALL="squid-${SQUID_VERSION}.tar.gz"
SQUID_DOWNLOAD_URL="https://github.com/squid-cache/squid/archive/refs/tags/${SQUID_TAG}.tar.gz"

echo "Installing Squid ${SQUID_VERSION} from source..."

# ----------------------------------------------------------------------
# Step 1: Install build dependencies
# ----------------------------------------------------------------------
echo "Updating package index and installing build dependencies..."
sudo apt-get update -y
sudo apt-get install -y build-essential openssl libssl-dev pkg-config wget vim \
                        autoconf automake libtool libltdl-dev perl

# ----------------------------------------------------------------------
# Step 2: Download and extract Squid source
# ----------------------------------------------------------------------
echo "Downloading Squid source from ${SQUID_DOWNLOAD_URL}..."
rm -f "$SQUID_TARBALL"
wget -O "$SQUID_TARBALL" "$SQUID_DOWNLOAD_URL"

echo "Extracting ${SQUID_TARBALL}..."
tar -xf "$SQUID_TARBALL"

# The source extracts into squid-SQUID_7_1 by default.  Determine the
# directory name programmatically so the script doesn't depend on a
# hard‑coded folder.
SQUID_SRC_DIR=$(tar -tf "$SQUID_TARBALL" | head -n1 | cut -f1 -d"/" || true)

if [ ! -d "$SQUID_SRC_DIR" ]; then
  echo "Error: failed to find Squid source directory after extraction."
  exit 1
fi

# ----------------------------------------------------------------------
# Step 3: Compile and install Squid
# ----------------------------------------------------------------------
echo "Compiling Squid ${SQUID_VERSION} (this may take several minutes)..."
pushd "$SQUID_SRC_DIR"

# Some Squid release tarballs (particularly beta versions) may not include a
# pre‑generated ./configure script.  If it is missing, run bootstrap.sh
# to generate the build system.  The bootstrap step requires autoconf,
# automake and libtool to be installed, which we added above.
if [ ! -x "./configure" ]; then
  echo "configure script not found; running ./bootstrap.sh to generate it..."
  if [ -x "./bootstrap.sh" ]; then
    ./bootstrap.sh
  else
    echo "Error: bootstrap.sh not found; cannot generate configure script."
    exit 1
  fi
fi

# Configure the build with SSL support.  See the guide for explanation of
# options.
./configure --with-default-user=proxy \
            --with-openssl \
            --enable-ssl-crtd

# Compile and install.
make
sudo make install
popd

# ----------------------------------------------------------------------
# Step 4: Configure OpenSSL
# ----------------------------------------------------------------------
echo "Configuring OpenSSL for SSL bumping..."

# Ensure the KeyUsage directive is present in the OpenSSL config.
OPENSSL_CONF="/etc/ssl/openssl.cnf"
sudo cp "$OPENSSL_CONF" "${OPENSSL_CONF}.bak"  # backup
if ! sudo grep -q "^keyUsage =" "$OPENSSL_CONF"; then
  # Insert keyUsage under the [ v3_ca ] block.  Append if block is missing.
  sudo sed -i "/^\[ *v3_ca *\]/a keyUsage = cRLSign, keyCertSign" "$OPENSSL_CONF"
fi

# Create a temporary directory for certificate generation.
SSL_TMP="/tmp/ssl_cert"
sudo rm -rf "$SSL_TMP"
sudo mkdir -p "$SSL_TMP"
sudo chown "$(whoami)" "$SSL_TMP"

# Generate a self‑signed root CA certificate.  The subject fields are
# supplied via -subj to avoid interactive prompts.  Adjust these values
# as desired.
cd "$SSL_TMP"
openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
        -extensions v3_ca \
        -keyout squid-self-signed.key \
        -out squid-self-signed.crt \
        -subj "/C=UK/ST=England/L=London/O=LocalSquid/OU=Proxy/CN=SquidProxy"

# Convert certificate formats and generate Diffie‑Hellman parameters.
openssl x509 -in squid-self-signed.crt -outform DER -out squid-self-signed.der
openssl x509 -in squid-self-signed.crt -outform PEM -out squid-self-signed.pem
openssl dhparam -outform PEM -out squid-self-signed_dhparam.pem 2048

# Copy generated certificates into Squid configuration directory.
sudo mkdir -p /usr/local/squid/etc/ssl_cert
sudo cp -f squid-self-signed.* /usr/local/squid/etc/ssl_cert/

# Install the CA cert into the system trust store.
sudo cp /usr/local/squid/etc/ssl_cert/squid-self-signed.pem \
          /usr/local/share/ca-certificates/squid-self-signed.crt
sudo update-ca-certificates

# ----------------------------------------------------------------------
# Step 5: Configure Squid
# ----------------------------------------------------------------------
echo "Configuring Squid..."

SQUID_CONF="/usr/local/squid/etc/squid.conf"
sudo cp "$SQUID_CONF" "${SQUID_CONF}.bak"  # backup original

# Function to insert lines at the top of the configuration file.
insert_at_top() {
  local file="$1"
  shift
  local tmp="$(mktemp)"
  {
    printf '%s\n' "$@"
    cat "$file"
  } > "$tmp"
  sudo mv "$tmp" "$file"
}

# 1. Add the intermediate_fetching ACL and http_access rule at the top.
insert_at_top "$SQUID_CONF" \
  "# Custom ACL for certificate fetching" \
  "acl intermediate_fetching transaction_initiator certificate-fetching" \
  "http_access allow intermediate_fetching"

# 2. Ensure CONNECT method ACL is present and allow port 777 for Safe_ports.
if ! sudo grep -q "acl CONNECT method CONNECT" "$SQUID_CONF"; then
  sudo sed -i "/acl Safe_ports/a acl CONNECT method CONNECT" "$SQUID_CONF"
fi

if ! sudo grep -q "acl Safe_ports port 777" "$SQUID_CONF"; then
  sudo sed -i "/acl Safe_ports/a acl Safe_ports port 777  # multiling http" "$SQUID_CONF"
fi

# 3. Replace existing http_port directive with SSL bump configuration.
sudo sed -i \
  -e '/^http_port/s/.*/http_port 3128 tcpkeepalive=60,30,3 ssl-bump generate-host-certificates=on dynamic_cert_mem_cache_size=20MB tls-cert=\/usr\/local\/squid\/etc\/ssl_cert\/squid-self-signed.crt tls-key=\/usr\/local\/squid\/etc\/ssl_cert\/squid-self-signed.key cipher=HIGH:MEDIUM:!LOW:!RC4:!SEED:!IDEA:!3DES:!MD5:!EXP:!PSK:!DSS options=NO_TLSv1,NO_SSLv3,SINGLE_DH_USE,SINGLE_ECDH_USE tls-dh=prime256v1:\/usr\/local\/squid\/etc\/ssl_cert\/squid-self-signed_dhparam.pem/' \
  "$SQUID_CONF"

# 4. Configure sslcrtd and ssl_bump directives.  Remove existing definitions first.
sudo sed -i '/^sslcrtd_program/d' "$SQUID_CONF"
sudo sed -i '/^sslcrtd_children/d' "$SQUID_CONF"
sudo sed -i '/^ssl_bump/d' "$SQUID_CONF"
sudo sed -i '/^sslproxy_cert_error/d' "$SQUID_CONF"
printf '\nsslcrtd_program /usr/local/squid/libexec/security_file_certgen -s /usr/local/squid/var/logs/ssl_db -M 20MB\n' | sudo tee -a "$SQUID_CONF" > /dev/null
printf 'sslcrtd_children 5\n' | sudo tee -a "$SQUID_CONF" > /dev/null
printf 'ssl_bump server-first all\n' | sudo tee -a "$SQUID_CONF" > /dev/null
printf 'ssl_bump stare all\n' | sudo tee -a "$SQUID_CONF" > /dev/null
printf 'sslproxy_cert_error deny all\n' | sudo tee -a "$SQUID_CONF" > /dev/null

# 5. Adjust cache settings.  Remove commented cache_dir line if present and
#    insert our custom values.  Also set maximum object size and cache_mem.
sudo sed -i '/^#cache_dir .*/d' "$SQUID_CONF"
sudo sed -i '/^maximum_object_size/d' "$SQUID_CONF"
sudo sed -i '/^cache_mem/d' "$SQUID_CONF"
sudo sed -i '/^cache_dir ufs /d' "$SQUID_CONF"
printf 'maximum_object_size 6 GB\n' | sudo tee -a "$SQUID_CONF" > /dev/null
printf 'cache_mem 8192 MB\n' | sudo tee -a "$SQUID_CONF" > /dev/null
printf 'cache_dir ufs /usr/local/squid/var/cache/squid 32000 16 256 # 32GB as Cache\n' | sudo tee -a "$SQUID_CONF" > /dev/null

# 6. Configure refresh patterns.  Append our custom patterns before the generic
#    catch‑all pattern.  We first remove any existing refresh_pattern lines to
#    avoid duplication.
sudo sed -i '/^refresh_pattern/d' "$SQUID_CONF"
printf 'refresh_pattern -i .(jar|zip|whl|gz|bz)  259200 20%% 259200 ignore-reload ignore-no-store ignore-private override-expire\n' | sudo tee -a "$SQUID_CONF" > /dev/null
printf 'refresh_pattern -i conda.anaconda.org\/.* 259200 20%% 259200 ignore-reload ignore-no-store ignore-private override-expire\n' | sudo tee -a "$SQUID_CONF" > /dev/null
printf 'refresh_pattern .  0 20%% 4320\n' | sudo tee -a "$SQUID_CONF" > /dev/null

# 7. Ensure ownership of /usr/local/squid is correct.
echo "Setting permissions on /usr/local/squid..."
sudo chown -R proxy:proxy /usr/local/squid

# ----------------------------------------------------------------------
# Step 6: Initialize SSL DB and cache directories
# ----------------------------------------------------------------------
echo "Initializing Squid SSL database and cache directories..."
sudo -u proxy -- /usr/local/squid/libexec/security_file_certgen -c -s /usr/local/squid/var/logs/ssl_db -M 20MB
sudo -u proxy -- /usr/local/squid/sbin/squid -z

# ----------------------------------------------------------------------
# Step 7: Start Squid
# ----------------------------------------------------------------------
echo "Starting Squid proxy..."
# You can adjust the debug level by changing -d 10.  Omit -d for silent start.
sudo -u proxy -- /usr/local/squid/sbin/squid -d 10

echo "Squid ${SQUID_VERSION} installation and configuration complete."
echo "To stop Squid gracefully, run: sudo -u proxy -- /usr/local/squid/sbin/squid -k shutdown"
echo "To stop Squid immediately, run: sudo -u proxy -- /usr/local/squid/sbin/squid -k interrupt"
echo "You can monitor cache activity via /usr/local/squid/var/logs/access.log."
