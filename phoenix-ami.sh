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

# Set ulimit to something more than default of 1024
echo -e "<domain> <type> <item>  <value>\n*       soft  nofile  20000\n*       hard  nofile  20000\n" > /etc/security/limits.d/buildkite.conf

# Run all commands from here under buildkite-agent account.
time su - buildkite-agent <<SCRIPT

set -e -x -v

export BUILD_USER_HOME_DIR=/var/lib/buildkite-agent

export ERLANG_VERSION=19.3
export ELIXIR_VERSION=1.4.2
export NODEJS_VERSION=6.10.2
export POSTGRES_VERSION=9.5.6

git clone https://github.com/asdf-vm/asdf.git \$BUILD_USER_HOME_DIR/.asdf --branch v0.3.0

echo -e "\n. \$BUILD_USER_HOME_DIR/.asdf/asdf.sh" >> ~/.bashrc
echo -e "\n. \$BUILD_USER_HOME_DIR/.asdf/completions/asdf.bash" >> ~/.bashrc

export PATH=\$BUILD_USER_HOME_DIR/.asdf/bin:\$PATH

asdf plugin-add erlang https://github.com/asdf-vm/asdf-erlang.git
asdf plugin-add elixir https://github.com/asdf-vm/asdf-elixir.git
asdf plugin-add nodejs https://github.com/asdf-vm/asdf-nodejs.git
asdf plugin-add postgres https://github.com/smashedtoatoms/asdf-postgres.git

# Erlang compilation requires $HOME to be set. We aren't in a login
# shell so we need to set it manually.
export HOME=\$BUILD_USER_HOME_DIR

asdf install erlang \$ERLANG_VERSION
asdf install elixir \$ELIXIR_VERSION
# This is required for successful nodejs installation
bash \$BUILD_USER_HOME_DIR/.asdf/plugins/nodejs/bin/import-release-team-keyring
asdf install nodejs \$NODEJS_VERSION
asdf install postgres \$POSTGRES_VERSION

asdf local erlang \$ERLANG_VERSION
asdf local elixir \$ELIXIR_VERSION
asdf local nodejs \$NODEJS_VERSION
asdf local postgres \$POSTGRES_VERSION

source \$BUILD_USER_HOME_DIR/.asdf/asdf.sh

# --force is supposed to not read from STDIN but it does, so we need
# to pipe from "yes" to avoid termination of the heredoc.
yes | head -n 1 | mix local.hex --force
yes | head -n 1 | mix local.rebar --force

npm install -g yarn
yarn global add brunch
yarn global add amphtml-validator
yarn global add lighthouse
yarn global add phantomjs-prebuilt

# We should be able to call 'yarn global bin' to get the path but for some
# reason during user-data initialisation it is returning nothing.
export YARN_GLOBAL_BIN_PATH=\$BUILD_USER_HOME_DIR/.asdf/installs/nodejs/\$NODEJS_VERSION/bin
echo -e "export PATH=\$YARN_GLOBAL_BIN_PATH:\$PATH" >> \$BUILD_USER_HOME_DIR/.bashrc

ssh-keygen -t rsa -N "" -f \$BUILD_USER_HOME_DIR/.ssh/id_rsa

pg_ctl start
# createuser will fail if postgres has not started up
sleep 5
createuser postgres
echo "ALTER USER postgres CREATEDB;" | psql -U buildkite-agent postgres

# Install CloudFoundry CLI
cd \$BUILD_USER_HOME_DIR
curl -L "https://cli.run.pivotal.io/stable?release=linux64-binary&source=github" | tar -zx

SCRIPT

sudo cp /etc/buildkite-agent/hooks/{pre-command.sample,pre-command}
sudo chown buildkite-agent:buildkite-agent /etc/buildkite-agent/hooks/pre-command
sudo chmod +x /etc/buildkite-agent/hooks/pre-command

cat <<SCRIPT | sudo tee -a /etc/buildkite-agent/hooks/pre-command
export PATH=/var/lib/buildkite-agent/.asdf/installs/nodejs/$NODEJS_VERSION/bin:/var/lib/buildkite-agent/.asdf/bin:/var/lib/buildkite-agent/.asdf/shims:/var/lib/buildkite-agent/.asdf/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/opt/aws/bin:$PATH
SCRIPT

sudo service buildkite-agent start
