#!/bin/bash
# ==============================
# User Manager for Docker Mail Server
# ==============================

set -e

# ------------------------------
# Load .env
# ------------------------------
if [ ! -f ".env" ]; then
    echo "[ERROR] .env file not found. Stopping execution."
    exit 1
fi

set -o allexport
source .env
set +o allexport

# ==============================
# Colors
# ==============================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ==============================
# Variables
# ==============================
DOMAIN="${DOMAIN:-example.com}"
DOMAIN_DIR="./data/maildir/${DOMAIN}"
PASSWD_FILE="${PASSWD_FILE:-${DOMAIN_DIR}/passwd}"

# ==============================
# Logging
# ==============================
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# ==============================
# Check utilities
# ==============================
for cmd in openssl; do
    command -v "$cmd" >/dev/null 2>&1 || { log_error "$cmd not found"; exit 1; }
done

# Check if domain directory exists
if [ ! -d "$DOMAIN_DIR" ]; then
    log_error "Domain directory not found: $DOMAIN_DIR"
    exit 1
fi

# ==============================
# Email validation
# ==============================
validate_email() {
    local email="$1"
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log_error "Invalid email format: $email"
        return 1
    fi
    return 0
}

# ==============================
# Password generation
# ==============================
generate_password() {
    local length="${1:-12}"
    openssl rand -base64 $((length*2)) | tr -dc 'A-Za-z0-9' | head -c "$length"
}

# ==============================
# Password hashing (Dovecot)
# ==============================
hash_password() {
    local password="$1"
    openssl passwd -6 "$password"
}

# ==============================
# Escape email for sed
# ==============================
escape_sed() {
    echo "$1" | sed -e 's/[]\/$*.^[]/\\&/g'
}

# ==============================
# Add user
# ==============================
add_user() {
    local email="$1"
    local password="$2"

    validate_email "$email" || return 1

    if grep -q "^$email:" "$PASSWD_FILE" 2>/dev/null; then
        log_warning "User $email already exists"
        return 1
    fi

    if [ -z "$password" ]; then
        password=$(generate_password)
        log_info "Generated password: $password"
    fi

    local hashed
    hashed=$(hash_password "$password")
    echo "$email:$hashed" >> "$PASSWD_FILE"

    log_success "User $email added"
    echo "Email: $email"
    echo "Password: $password"
}

# ==============================
# Remove user
# ==============================
remove_user() {
    local email="$1"

    validate_email "$email" || return 1

    if ! grep -q "^$email:" "$PASSWD_FILE" 2>/dev/null; then
        log_warning "User $email not found"
        return 1
    fi

    local safe_email
    safe_email=$(escape_sed "$email")
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i "" "/^$safe_email:/d" "$PASSWD_FILE"
    else
        sed -i "/^$safe_email:/d" "$PASSWD_FILE"
    fi

    log_success "User $email removed"
}

# ==============================
# Change password
# ==============================
change_password() {
    local email="$1"
    local new_pass="$2"

    validate_email "$email" || return 1

    if ! grep -q "^$email:" "$PASSWD_FILE" 2>/dev/null; then
        log_error "User $email not found"
        return 1
    fi

    if [ -z "$new_pass" ]; then
        new_pass=$(generate_password)
        log_info "Generated new password: $new_pass"
    fi

    local hashed
    hashed=$(hash_password "$new_pass")
    local safe_email
    safe_email=$(escape_sed "$email")

    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i "" "s|^$safe_email:.*|$safe_email:$hashed|" "$PASSWD_FILE"
    else
        sed -i "s|^$safe_email:.*|$safe_email:$hashed|" "$PASSWD_FILE"
    fi

    log_success "Password for $email changed"
    echo "Email: $email"
    echo "New Password: $new_pass"
}

# ==============================
# List users
# ==============================
list_users() {
    if [ ! -f "$PASSWD_FILE" ]; then
        log_warning "User file not found: $PASSWD_FILE"
        return 1
    fi
    log_info "User list:"
    cut -d: -f1 "$PASSWD_FILE" | sort
}

# ==============================
# Bulk add users
# ==============================
bulk_add_users() {
    local file="$1"
    if [ ! -f "$file" ]; then
        log_error "File not found: $file"
        return 1
    fi
    log_info "Bulk adding users from $file"

    while IFS=: read -r email password; do
        [[ -z "$email" || "$email" =~ ^# ]] && continue
        add_user "$email" "$password"
    done < "$file"

    log_success "Bulk addition completed"
}

# ==============================
# Check user
# ==============================
check_user() {
    local email="$1"
    validate_email "$email" || return 1

    if grep -q "^$email:" "$PASSWD_FILE" 2>/dev/null; then
        log_success "User $email exists"
        return 0
    else
        log_warning "User $email not found"
        return 1
    fi
}

# ==============================
# Export users
# ==============================
export_users() {
    local out="$1"
    out="${out:-users-export-$(date +%Y%m%d-%H%M%S).txt}"

    if [ ! -f "$PASSWD_FILE" ]; then
        log_error "User file not found"
        return 1
    fi

    cp "$PASSWD_FILE" "$out"
    log_success "Users exported to: $out"
}

# ==============================
# Help
# ==============================
show_help() {
    cat <<EOF
User Manager for Docker Mail Server

Usage:
    $0 <command> [options]

Commands:
    add <email> [password]            Add user
    remove <email>                    Remove user
    change-password <email> [password] Change password
    list                               Show all users
    bulk-add <file>                    Bulk add users from file
    check <email>                      Check if user exists
    export [file]                      Export users
    help                               Show this help
EOF
}

# ==============================
# Main logic
# ==============================
main() {
    mkdir -p "$(dirname "$PASSWD_FILE")"

    case "${1:-help}" in
        add) add_user "$2" "$3" ;;
        remove) remove_user "$2" ;;
        change-password) change_password "$2" "$3" ;;
        list) list_users ;;
        bulk-add) bulk_add_users "$2" ;;
        check) check_user "$2" ;;
        export) export_users "$2" ;;
        help|"-h"|"--help") show_help ;;
        *) log_error "Unknown command: $1"; show_help; exit 1 ;;
    esac
}

main "$@"

