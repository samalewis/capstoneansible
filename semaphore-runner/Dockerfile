# Start from the official Semaphore image (ensure version matches what you use)
FROM semaphoreui/semaphore:latest

# Switch to root to install packages
USER root

# Install dependencies
# - expect: for your script
# - openssh-client: for ssh/scp
# - bash: for the wrapper script
# - git: usually needed for repo cloning
RUN apk update && \
    apk add --no-cache \
    expect \
    openssh-client \
    bash \
    git \
    curl

# (Optional) If you need Ansible collections that aren't included:
#RUN pip3 install netmiko ansible-pylibssh

# Switch back to the default semaphore user so permissions remain correct
USER 1001
