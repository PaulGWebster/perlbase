# perlbase

A small project to create a all inclusive docker image that is the perfect 
development environment for a perl project.

*Included are:*
- Perl 5.36.3
- Integrated ssh server that can be enabled or disabled (default is disabled)
    - Ability to use ssh keys to connect to the container
- Pre initialized lib::local
- Precreated user with no password auth 'perl'
- PostgreSQL 16.2 (server and client)
- A carton bundled set of system modules
    - see [cpanfile](asset/src/carton/cpanfile) for a list of modules

## Table of Contents

- [perlbase](#perlbase)
  - [Table of Contents](#table-of-contents)
  - [Project Description](#project-description)
  - [Getting Started](#getting-started)
    - [ENV values](#env-values)
    - [DockerHub](#dockerhub)
    - [Source](#source)
    - [Prerequisites](#prerequisites)
    - [Installation](#installation)
  - [Usage](#usage)
  - [Contributing](#contributing)
  - [License](#license)

## Project Description

Provide a brief overview of the project, its purpose, and any relevant background information.

## Getting Started

### ENV values

The following environment variables are used in the project:

* ENTRYPOINT_CMD
  - The command to run when the container starts
  - Default: /nocmd
* SSH_ENABLE
  - Whether to enable the ssh server
  - Default: no

### DockerHub

> The image is available on dockerhub at [paulgwebster/perlbase](https://hub.docker.com/repository/docker/paulgwebster/perlbase)

  - docker run -it -e 'SSH_ENABLE=yes' -p 2222:22 paulgwebster/perlbase:latest /entrypoint.sh
    - This will start the container with ssh enabled and run the entrypoint
    - If you wished for the entrypont to run a different command, you can set the ENTRYPOINT_CMD environment variable
    - an example for docker run would be adding the -e 'ENTRYPOINT_CMD=/bin/bash' 

### Source

To run the project locally, follow these steps:

1. Clone the repository to your local machine.
   - git clone https://github.com/PaulGWebster/perlbase.git
2. cd perlbase
3. read [auth/README.md](auth/README.md)
   - Follow the instructions to create your own ssh keys
4. ./recreateimages.sh
   - When prompted for if the image should be loaded, type 'y' and press enter.
 - docker build . -t perlbase:latest
   - This will take a while!  Go get a cup of tea.
   - It takes around 10 minutes on an AMD Ryzen 7 5800X 8-Core Processor
5. docker-compose up

### Prerequisites

To run the project, you will need the following:

- Docker
- (Optional) Docker Compose
- (Optional) ssh-keygen (depending on whether you have your own pubkey or not)

For development, you will also need:

- Perl
  - Carton
- Docker
- Docker Compose
- (Optional) ssh-keygen (depending on whether you have your own pubkey or not)


### Installation

Provide step-by-step instructions on how to install and set up the project locally. Include any necessary commands or configurations.

## Usage

Explain how to use the project, including any command-line options or arguments. Provide examples or code snippets if applicable.

## Contributing

Thank you for considering contributing to the perlbase project! Contributions are welcome and encouraged. To contribute, please follow these steps:

1. Fork the repository on GitHub.
2. Clone your forked repository to your local machine.
3. Create a new branch for your feature or bug fix.
4. Make your changes and commit them with descriptive commit messages.
5. Push your changes to your forked repository.
6. Submit a pull request to the main repository.

Please ensure that your contributions adhere to the following guidelines:
- Follow the coding style and conventions used in the project.
- Provide clear and concise documentation for any new features or changes.
- Write meaningful commit messages that describe the purpose of your changes.

If you have any questions or need further assistance, please feel free to reach out to us.

Happy contributing!


## License

See the [LICENSE](LICENSE) file for details.

