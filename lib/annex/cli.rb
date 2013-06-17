require 'optparse'

module Annex
  # Manages the command line interface to Annex
  class CLI
    COMMANDS = %w(provision list)

    def initialize(argv, env)
      @argv = argv
      @env  = env
    end

    def execute
      exit_code = 0
      return exit_code unless options = parse(@argv.dup)
      command = case options[:command]
      when "provision"
        Annex::Provision.new(@env, options)
      when "list"
        Annex::List.new(@env, options)
      end
      env.info("Executing #{options[:command]}", :command)
      command.execute
      exit_code
    end

    private

    def env
      @env
    end

    def parse(argv)
      # Global option parser
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: annex [-v] [-h] command [<args>]"
        opts.separator ""
        opts.separator "Available commands: "
        opts.separator ""

        COMMANDS.each do |c| opts.separator "    #{c}" end

        opts.separator ""
        opts.separator "Global options:"
        opts.separator ""

        opts.on_tail("-h", "--help", "Show this message") do
          env.info opts
          return
        end

        opts.on_tail("-v", "--version", "Show version") do
          env.info "annex version #{Annex::VERSION}"
          return
        end
      end

      # If there were no options then we show the usage and exit
      if argv.nil? || argv.length == 0
        env.info parser
        return
      end

      # Grab the first arg, and setup the command options hash
      options = {:command => argv.shift}

      # Verify the commands
      parser.order!([options[:command]]) do |unknown|
        next if COMMANDS.include?(unknown)
        env.error "Unknown command #{unknown.inspect}"
        env.info opts
        return
      end

      # Create a command specific parser
      parser = case options[:command]
      when "provision"
        OptionParser.new do |opts|
          opts.banner = "Usage: annex provision <args>"
          opts.on("-r ROLE", "--role ROLE", "Specify the role for the server you are provisioning") do |role|
            options[:role] = role
          end
          opts.on("-e ENVIRONMENT", "--environment ENVIRONMENT", "Specify the environment for the server you are provisioning") do |environment|
            options[:environment] = environment
          end
        end
      when "list"
        OptionParser.new do |opts|
          opts.banner = "Usage: annex list <args>"
          opts.on("-r ROLE", "--role ROLE", "List all servers matching the specified role") do |role|
            options[:role] = role
          end
          opts.on("-e ENVIRONMENT", "--environment ENVIRONMENT", "List all servers in the specified environment") do |environment|
            options[:environment] = environment
          end
          opts.on("-a", "--all", "List all servers in all environments") do
            options[:all] = true
          end
        end
      end

      # If there were no command options then we show the usage and exit
      if argv.length == 0
        env.info parser
        return
      end

      # Verify the commands
      parser.parse!(argv) do |unknown|
        env.error "Unknown option for #{options[:command]} command: #{unknown.inspect}"
        env.info opts
        return
      end

      # Send back the parsed options
      options
    end
  end
end
