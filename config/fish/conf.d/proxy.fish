# Proxy settings with fallback - only set if squid is running
if command -s nc >/dev/null 2>&1; and nc -z localhost 3128 2>/dev/null
    set -gx HTTP_PROXY http://localhost:3128
    set -gx HTTPS_PROXY http://localhost:3128
    set -gx http_proxy http://localhost:3128
    set -gx https_proxy http://localhost:3128
end
set -gx NO_PROXY localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
set -gx no_proxy localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
