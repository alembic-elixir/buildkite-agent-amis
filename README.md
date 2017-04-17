# Buildkite AMI scripts

Run this script as Ec2 instance user-data to create a new Buildkite agent for
Elixir/Phoenix applications. Includes postgres, nodejs, yarn, lighthouse, brunch.

Caveats: postgres is started in this script but is not installed as a system
service in /etc/init.  If postgres ever crashes you'll need to SSH into the
instance and restart it manually.

TODO: convert this into a Docker set up.
