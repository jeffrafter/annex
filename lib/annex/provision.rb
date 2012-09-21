require 'erb'

module Annex
  class Provision < Command
    def execute
      which = servers.select do |server|
        choose = server.state == "running"
        choose = choose && server.tags["Name"] =~ /^#{role}/ if role
        choose = choose && server.tags["Name"] =~ /#{environment}$/ if environment
        choose
      end

      msg = "We have #{which.length} servers"
      msg << " for the #{role} role"
      msg << " in the environment #{environment}"
      @env.info(msg, :info)

      count = @env.config['roles'][role]['count']
      @env.info("We should have #{count}", :info)

      # For each server we do have, update
      which.each do |server|
        update(server, @env.config['users']['update'])
      end

      # For each server we need, bootstrap
      (count - which.length).times do
        image = @env.config['roles'][role]['image']
        kind = @env.config['amazon']['images'][image]
        bootstrap(connection, kind['image_id'], kind['flavor_id'], @env.config['users']['bootstrap'])
      end
    end

    private

    def node_name
      "#{role}-#{environment}"
    end

    def ruby_script
      if @env.config['roles'][role]['ruby'] == "package"
        template("ruby-apt.sh")
      elsif @env.config['roles'][role]['ruby'] == "1.9.3"
        template("ruby-1.9.3.sh")
      else
        template("ruby-ree")
      end
    end

    # Bootstrap the environment with chef to handle chef-roles
    def bootstrap_script
      template("bootstrap.sh")
    end

    # Bootstrap the environment with chef to handle chef-roles
    def update_script
      template("update.sh")
    end

    def bootstrap(connection, image_id, flavor_id, user)
      @env.info("Bootstrapping #{role} server", :info)

      server = connection.servers.bootstrap({
        :private_key_path => '~/.ssh/id_rsa',
        :public_key_path => '~/.ssh/id_rsa.pub',
        :availability_zone => 'us-east-1a',
        :username => user,
        :image_id => image_id,
        :flavor_id => flavor_id
      })

      # Add the tags
      connection.tags.create(
        :resource_id => server.identity,
        :key => 'Name',
        :value => node_name)

      ssh_options = { :forward_agent => true }
      ssh = Fog::SSH.new(server.public_ip_address, server.username, ssh_options)

      begin
        return if image_id == "windows"
        bootstrap_script.split(/\n/).each do |cmd|
          next if cmd == ''
          @env.info("")
          @env.info("Running command:", :info)
          @env.info("")
          @env.info("  #{cmd}", :command)
          ssh.run(cmd)
        end
      ensure
        @env.info("")
        @env.info("Done", :info)
        @env.info("  #{server.dns_name}", :notice)
        @env.info("  Public: #{server.public_ip_address}", :notice)
        @env.info("  Private: #{server.private_ip_address}", :notice)
      end
    end

    def update(server, user)
      @env.info("Updating #{server.public_ip_address} (#{server.id})", :info)
      ssh_options = { :forward_agent => true }
      ssh = Fog::SSH.new(server.public_ip_address, user, ssh_options)
      begin
        update_script.split(/\n/).each do |cmd|
          next if cmd == ''
          @env.info("")
          @env.info("Running command:", :info)
          @env.info("")
          @env.info("  #{cmd}", :command)
          ssh.run(cmd)
        end
      ensure
        @env.info("")
        @env.info("Done", :info)
        @env.info("  #{server.dns_name}", :notice)
        @env.info("  Public: #{server.public_ip_address}", :notice)
        @env.info("  Private: #{server.private_ip_address}", :notice)
      end
    end
  end
end
