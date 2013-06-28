require 'erb'
require 'json'
require 'tempfile'

module Annex
  class Provision < Command
    def execute
      if !role && !environment
        @env.info("Sorry, you must include the role and the environment when provisioning", :error)
        return
      end

      begin
        # Try to determine the environment
        write_environment

        which = servers.select do |server|
          name_tag = server.tags["Name"]
          name_tag = name_tag.gsub(/-i-[0-9a-f]+$/, '') rescue ''

          choose = server.state == "running"
          choose = choose && name_tag =~ /^#{role}/ if role
          choose = choose && name_tag =~ /#{environment}$/ if environment
          choose
        end

        msg = "We have #{which.length} servers"
        msg << " for the #{role} role"
        msg << " in the environment #{environment}"
        @env.info(msg, :info)

        count = @env.config['roles'][role]['count']
        @env.info("We should have #{count}", :info)

        # Try to be graceful
        Thread.abort_on_exception = false
        threads = []

        # For each server we do have, update
        which.each do |server|
          threads << update(server, @env.config['users']['update']) unless ENV['SKIP_UPDATE']
        end

        # For each server we need, bootstrap
        (count - which.length).times do
          image = @env.config['roles'][role]['image']
          kind = @env.config['amazon']['images'][image]
          threads << bootstrap(connection, kind['image_id'], kind['flavor_id'], kind['az_id'], @env.config['users']['bootstrap'])
        end

        threads.each do |thr|
          thr.join unless ENV['SYNC']
        end

      ensure
        cleanup_environment
      end
    end

    private

    def ruby_script
      if @env.config['roles'][role]['ruby'] == "package"
        template("ruby-apt.sh")
      elsif @env.config['roles'][role]['ruby'] == "1.9.3"
        template("ruby-1.9.3.sh")
      else
        template("ruby-ree.sh")
      end
    end

    # Bootstrap the environment with chef to handle chef-roles
    def bootstrap_script(options={})
      template_binding = OpenStruct.new(options)
      template("bootstrap.sh", template_binding.instance_eval { binding })
    end

    # Bootstrap the environment with chef to handle chef-roles
    def update_script(options={})
      template_binding = OpenStruct.new(options)
      template("update.sh", template_binding.instance_eval { binding })
    end

    def bootstrap(connection, image_id, flavor_id, az_id, user)
      thr = Thread.new(connection, image_id, flavor_id, az_id, user) do |_connection, _image_id, _flavor_id, _az_id, _user|
        sleep 1

        @env.info("Bootstrapping #{role} server...", :info)

        begin
          # Build the server from the base AMI
          server = _connection.servers.bootstrap({
            :private_key_path => '~/.ssh/id_rsa',
            :public_key_path => '~/.ssh/id_rsa.pub',
            :availability_zone => _az_id,
            :username => _user,
            :image_id => _image_id,
            :flavor_id => _flavor_id
          })

          node_name = "#{role}-#{environment}-#{server.identity}"

          # Add the tags
          _connection.tags.create(
            :resource_id => server.identity,
            :key => 'Name',
            :value => node_name)
        rescue Exception => e
          @env.error("Error for #{server.id} (#{e.message})\n\n#{e.backtrace}", :error)
          return
        end

        scp_options = { :forward_agent => true }
        scp = Fog::SCP.new(server.public_ip_address, server.username, scp_options)
        scp.upload(@envfile.path.to_s, "#{environment}.json")

        ssh_options = { :forward_agent => true }
        ssh = Fog::SSH.new(server.public_ip_address, server.username, ssh_options)

        begin
          return if _image_id == "windows"
          script = bootstrap_script({
            :environment => environment,
            :node_name => node_name,
            :role => role,
            :user => @env.config['users']['bootstrap'],
            :ruby_script => ruby_script,
            :repository => @env.config['repository']
          })
          script.split(/\n/).each do |cmd|
            next if cmd == ''
            @env.info("")
            @env.info("Running command:", :info)
            @env.info("")
            @env.info("  #{cmd}", :command)
            ssh.run(cmd)
          end
        rescue Exception => e
          @env.error("Error for #{server.id} (#{e.message})\n\n#{e.backtrace}", :error)
        end

        begin
          @env.info("")
          @env.info("Done", :info)
          @env.info("  #{server.dns_name}", :notice)
          @env.info("  Public: #{server.public_ip_address}", :notice)
          @env.info("  Private: #{server.private_ip_address}", :notice)
        rescue
        end
      end
      thr.join if ENV['SYNC']
      thr
    end

    def update(server, user)
      thr = Thread.new(server, user) do |_server, _user|
        sleep 1

        @env.info("Updating #{_server.public_ip_address} (#{_server.id})\n", :info)

        scp_options = { :forward_agent => true }
        scp = Fog::SCP.new(_server.public_ip_address, _user, scp_options)
        scp.upload(@envfile.path.to_s, "#{environment}.json")

        ssh_options = { :forward_agent => true }
        ssh = Fog::SSH.new(_server.public_ip_address, _user, ssh_options)

        node_name = "#{role}-#{environment}-#{_server.identity}"

        begin
          script = update_script({
            :environment => environment,
            :node_name => node_name,
            :role => role,
            :user => @env.config['users']['update']
          })
          script.split(/\n/).each do |cmd|
            next if cmd == ''
            @env.info("")
            @env.info("Running command:", :info)
            @env.info("")
            @env.info("  #{cmd}", :command)
            ssh.run(cmd)
          end
        rescue Exception => e
          @env.error("Error for #{_server.id} (#{e.message})\n\n#{e.backtrace}", :error)
        end

        begin
          @env.info("")
          @env.info("Done", :info)
          @env.info("  #{_server.dns_name}", :notice)
          @env.info("  Public: #{_server.public_ip_address}", :notice)
          @env.info("  Private: #{_server.private_ip_address}", :notice)
        rescue
        end
      end
      thr.join if ENV['SYNC']
      thr
    end

    def write_environment
      @nodes = []
      servers.each do |server|
        name = server.tags["Name"]
        next unless server.state == "running"
        next unless name && name != ''

        role = name.slice(0, name.rindex("-")) rescue name
        env = name.slice(name.rindex("-")+1, name.length) rescue name
        next unless env == environment

        @nodes << {
          :name => name,
          :role => role,
          :environment => env,
          :public_fqdn => server.dns_name,
          :public_ip => server.public_ip_address,
          :private_ip => server.private_ip_address
        }
      end
      @nodes

      @envfile = Tempfile.new("annex-#{environment}.json")
      @envfile.puts({:id => environment, :nodes => @nodes}.to_json)
      @envfile.flush
      @envfile
    end

    def cleanup_environment
      return unless @envfile
      @envfile.close
      @envfile.unlink
      @envfile = nil
    end

  end
end
