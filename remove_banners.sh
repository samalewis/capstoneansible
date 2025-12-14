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

set SWITCH_IP "192.168.1.202"
set USERNAME "admin"
set PASSWORD "" 

set BEFORE_BANNER [list]

set AFTER_BANNER [list]

set timeout 30

# Connect
spawn ssh -o StrictHostKeyChecking=no -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa $USERNAME@$SWITCH_IP

expect {
  "password:" { send "$PASSWORD\r" }
  "#" { }
  timeout { puts "Timeout awaiting prompt"; exit 1 }
}

# Wait for initial prompt to be stable
expect "#"

# ------------------------------------------------------------------
# STRATEGY: THE "SECURECRT PASTE" METHOD
# Instead of sending line-by-line and waiting for prompts (which fails),
# we build one giant string and send it all at once. 
# This forces the switch to buffer the input just like a paste.
# ------------------------------------------------------------------

# 1. Start with the first command
set paste_buffer "configure banner before-login\r"

# 2. Add the first banner lines
foreach line $BEFORE_BANNER {
    append paste_buffer "$line\r"
}
# 3. Add the blank line to Exit Banner 1
append paste_buffer "\r"

# 4. Add the second command IMMEDIATELY (No waiting!)
append paste_buffer "configure banner after-login\r"

# 5. Add the second banner lines
foreach line $AFTER_BANNER {
    append paste_buffer "$line\r"
}
# 6. Add the blank line to Exit Banner 2
append paste_buffer "\r"

# 7. SEND IT ALL AT ONCE
send "$paste_buffer"

# ------------------------------------------------------------------
# NOW we wait. The switch will process the buffer and eventually
# return to the prompt after finishing both banners.
# ------------------------------------------------------------------

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
