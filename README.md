# Buildkite AMI scripts

Run this script as Ec2 instance user-data to create a new Buildkite agent for
Elixir/Phoenix applications. Includes postgres, nodejs, yarn, lighthouse, brunch.

TODO: convert this into a Docker set up.

## Starting 

Caveats: postgres is started in this script but is not installed as a system
service in /etc/init.  If postgres ever crashes you'll need to SSH into the
instance and restart it manually.

To start it, SSH in using the SSH command from the AWS EC2 page for the instance. Then:

		sudo su - buildkite-agent
		pg_ctl start

You can log out of the machine and postgres will remain running until the next reboot.
