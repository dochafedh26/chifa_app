#!/bin/bash

# XAMPP Control Script

echo "=========================="
echo "XAMPP Service Controller"
echo "=========================="

XAMPP_PATH="/opt/lampp"

# Check if XAMPP exists
if [ ! -d "$XAMPP_PATH" ]; then
    echo "Error: XAMPP not found at $XAMPP_PATH"
    echo "Please install XAMPP or update XAMPP_PATH in this script"
    exit 1
fi

# Function to check if a service is running
is_running() {
    if pgrep -x "mysqld" > /dev/null 2>&1; then
        return 0
    elif pgrep -x "httpd" > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Check MySQL status
check_mysql() {
    if pgrep -x "mysqld" > /dev/null 2>&1; then
        echo "[✓] MySQL is running"
        return 0
    else
        echo "[✗] MySQL is stopped"
        return 1
    fi
}

# Check Apache status
check_apache() {
    if pgrep -x "httpd" > /dev/null 2>&1; then
        echo "[✓] Apache is running"
        return 0
    else
        echo "[✗] Apache is stopped"
        return 1
    fi
}

# Start MySQL
start_mysql() {
    echo "Starting MySQL..."
    sudo $XAMPP_PATH/lampp startmysql
    if [ $? -eq 0 ]; then
        echo "[✓] MySQL started successfully"
    else
        echo "[✗] Failed to start MySQL"
        exit 1
    fi
}

# Start Apache
start_apache() {
    echo "Starting Apache..."
    sudo $XAMPP_PATH/lampp startapache
    if [ $? -eq 0 ]; then
        echo "[✓] Apache started successfully"
    else
        echo "[✗] Failed to start Apache"
        exit 1
    fi
}

# Stop MySQL
stop_mysql() {
    echo "Stopping MySQL..."
    sudo $XAMPP_PATH/lampp stopmysql
    echo "[✓] MySQL stopped"
}

# Stop Apache
stop_apache() {
    echo "Stopping Apache..."
    sudo $XAMPP_PATH/lampp stopapache
    echo "[✓] Apache stopped"
}

# Main menu
case "${1:-status}" in
    start)
        start_mysql
        start_apache
        ;;
    startmysql)
        start_mysql
        ;;
    startapache)
        start_apache
        ;;
    stop)
        stop_mysql
        stop_apache
        ;;
    stopmysql)
        stop_mysql
        ;;
    stopapache)
        stop_apache
        ;;
    status|*)
        echo ""
        echo "--- MySQL Status ---"
        check_mysql
        echo ""
        echo "--- Apache Status ---"
        check_apache
        echo ""
        ;;
esac