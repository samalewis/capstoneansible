#!/bin/bash

# 1. Install 'expect' if it is missing
if ! command -v expect &> /dev/null; then
    echo "Installing expect..."
    if [ -x "$(command -v apt-get)" ]; then
        sudo apt-get update && sudo apt-get install -y expect
    elif [ -x "$(command -v yum)" ]; then
        sudo yum install -y expect
    elif [ -x "$(command -v apk)" ]; then
        sudo apk add expect
    fi
fi

# 2. Create the Expect script
cat << 'EOF' > /tmp/deploy_banners.exp
#!/usr/bin/expect -f

set SWITCH_IP "10.1.200.3"
set USERNAME "admin"
set PASSWORD "" 

set BEFORE_BANNER [list \
    "***********************************************************************" \
    "*                                                                     *" \
    "*  WARNING: UNAUTHORIZED ACCESS IS PROHIBITED                         *" \
    "*                                                                     *" \
    "*  This system is property of Capstone Labs. All activity is          *" \
    "*  monitored and logged. Unauthorized use is a violation of federal   *" \
    "*  and state laws (18 USC 1030, etc.) and may result in criminal      *" \
    "*  prosecution.                                                       *" \
    "*                                                                     *" \
    "*  https://capstonelabs.net/security-policy                           *" \
    "*                                                                     *" \
    "***********************************************************************" \
]

# Note: If these special characters look weird on the switch, change 
# '╔' to '+' and '═' to '-'
set AFTER_BANNER [list \
    "╔══════════════════════════════════════════════════════════════════════╗" \
    "║                 CAPSTONE LABS CORE SWITCH - CORE-02                  ║" \
    "╠══════════════════════════════════════════════════════════════════════╣" \
    "║  Unauthorized changes are strictly prohibited.                       ║" \
    "║  All configuration changes must be approved and documented.          ║" \
    "╚══════════════════════════════════════════════════════════════════════╝" \
]

set timeout 30

spawn ssh -o StrictHostKeyChecking=no -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa $USERNAME@$SWITCH_IP

expect {
  "password:" { send "$PASSWORD\r" }
  "#" { }
  timeout { puts "Timeout awaiting prompt"; exit 1 }
}

# --- Deploy Before-Login Banner ---
expect "#"
send "configure banner before-login\r"
sleep 1
foreach line $BEFORE_BANNER {
    send "$line\r"
}
# Send ONE return to finish the last line of text
send "\r"
# Wait briefly to ensure the line is processed
sleep 0.5
# Send SECOND return to tell EXOS we are done with the banner
send "\r"

# CRITICAL FIX: Wait for the prompt specifically before moving on
expect "#"
# Sleep to flush any lingering newlines from the buffer
sleep 2

# --- Deploy After-Login Banner ---
send "configure banner after-login\r"
# Wait specifically for the switch to enter input mode
sleep 2

foreach line $AFTER_BANNER {
    send "$line\r"
}
send "\r"
sleep 0.5
send "\r"
expect "#"

# --- Save and Exit ---
send "save configuration\r"
expect "save"
send "y\r"
expect "#"
send "exit\r"
EOF

# 3. Execute
chmod +x /tmp/deploy_banners.exp
/usr/bin/expect -f /tmp/deploy_banners.exp

# 4. Cleanup
rm /tmp/deploy_banners.exp
