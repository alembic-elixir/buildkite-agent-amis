#!/bin/bash

# Paste this file into the user-data script field when launching a new EC2
# instance.  After it boots successfully you can make an AMI from the instance
# and spin up as many as you like without having to run this installation
# script again.

# Verbose output, and abort on error
# You can run `tail -F /var/log/cloud-init-output.log` on the instance.
set -e -x -v

# Replace "xxx" with your Buildkite API token.
export BUILDKITE_TOKEN=xxx

# Required by asdf and all build pipelines we'll be running.
yum install -y git

# Toolchain required by asdf
yum -y groupinstall "Development Tools"

# Required by Postgres
yum install -y readline-devel
yum install -y zlib-devel

# Required by Erlang
yum install -y openssl-devel

# Register the Buildkite agent repo
sh -c 'echo -e "[buildkite-agent]\nname = Buildkite Pty Ltd\nbaseurl = https://yum.buildkite.com/buildkite-agent/stable/x86_64/\nenabled=1\ngpgcheck=0\npriority=1" > /etc/yum.repos.d/buildkite-agent.repo'

yum -y install buildkite-agent

sed -i "s/xxx/$BUILDKITE_TOKEN/g" /etc/buildkite-agent/buildkite-agent.cfg

# Required by a specific Alembic client project
pip install twisted

# Run all commands from here under ec2-user account.
time su - ec2-user <<EC2USER

set -e -x -v

git clone https://github.com/asdf-vm/asdf.git /home/ec2-user/.asdf --branch v0.3.0

echo -e '\n. /home/ec2-user/.asdf/asdf.sh' >> ~/.bashrc
echo -e '\n. /home/ec2-user/.asdf/completions/asdf.bash' >> ~/.bashrc

export PATH=/home/ec2-user/.asdf/bin:$PATH

asdf plugin-add erlang https://github.com/asdf-vm/asdf-erlang.git
asdf plugin-add elixir https://github.com/asdf-vm/asdf-elixir.git
asdf plugin-add nodejs https://github.com/asdf-vm/asdf-nodejs.git
asdf plugin-add postgres https://github.com/smashedtoatoms/asdf-postgres.git

# Erlang compilation requires $HOME to be set. We aren't in a login
# shell so we need to set it manually.
export HOME=/home/ec2-user

asdf install erlang 19.3
asdf install elixir 1.4.2
# This is required for successful nodejs installation
bash /home/ec2-user/.asdf/plugins/nodejs/bin/import-release-team-keyring
asdf install nodejs 6.10.2
asdf install postgres 9.5.6

asdf local erlang 19.3
asdf local elixir 1.4.2
asdf local nodejs 6.10.2
asdf local postgres 9.5.6

source /home/ec2-user/.asdf/asdf.sh

# --force is supposed to not read from STDIN but it does, so we need
# to pipe from "yes" to avoid termination of the heredoc.
yes | head -n 1 | mix local.hex --force
yes | head -n 1 | mix local.rebar --force

npm install -g yarn
yarn global add brunch
yarn global add amphtml-validator
yarn global add lighthouse
yarn global add phantomjs-prebuilt

echo -e "export PATH=$(yarn global bin):\$PATH" >> /home/ec2-user/.bashrc

EC2USER

sudo service buildkite-agent start

