# Public Key Authentication for Docker Image

This directory, `auth/`, is intended for storing your public SSH key. The key will be copied into the Docker image during the build process, allowing you to securely access the container via SSH.

## Instructions

1. Generate a new SSH key pair if you don't have one already. You can do this using the following command:

    ```bash
    ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
    ```

    This will create a new SSH key pair with a 4096 bit RSA key. Replace `"your_email@example.com"` with your email address.

2. Copy your public SSH key into this directory. If you used the default file locations when generating your key, you can do this with:

    ```bash
    cp ~/.ssh/id_rsa.pub ./auth/
    ```

3. After the image is built, you can start a container from it and access it via SSH using your private key.

Please remember to never share your private key and to keep it secure on your local machine.

