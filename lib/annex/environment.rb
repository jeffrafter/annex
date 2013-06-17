require 'fileutils'
require 'pathname'

module Annex
  # Represents an Annex environment. The basic annex environment contains
  # a config/settings.yml file defining the server cluster.
  class Environment

    # The `cwd` that this environment represents
    attr_reader :cwd

    # Initializes a new environment with the given options. The options
    # is a hash where the main available key is `cwd`, which defines the
    # location of the environment. If `cwd` is nil, then it defaults
    # to the `Dir.pwd` (which is the cwd of the executing process).
    def initialize(opts=nil)
      opts = {
        :cwd => nil,
        :windows => false,
        :supports_colors => true,
        :no_colors => false
      }.merge(opts || {})

      # Set the default working directory
      opts[:cwd] ||= ENV["ANNEX_CWD"] if ENV.has_key?("ANNEX_CWD")
      opts[:cwd] ||= Dir.pwd
      opts[:cwd] = Pathname.new(opts[:cwd])
      raise Errors::AnnexError.new("Unknown current working directory") if !opts[:cwd].directory?

      # Set instance variables for all the configuration parameters.
      @cwd = opts[:cwd]
      @colorize = opts[:supports_colors] || !opts[:no_colors]
    end

    # Return a human-friendly string for pretty printed or inspected
    # instances.
    #
    # @return [String]
    def inspect
      "#<#{self.class}: #{@cwd}>"
    end

    # Makes a call to the CLI with the given arguments as if they
    # came from the real command line (sometimes they do!). An example:
    #
    #     env.cli("provision", "--role", "app", "--environment", "staging")
    #
    def cli(*args)
      CLI.new(args.flatten, self).execute
    end

    # The configuration object represented by this environment. This
    # will trigger the environment to load if it hasn't loaded yet.
    #
    # @return [hash]
    def config
      @config ||= YAML::load_file(File.join(@cwd, "config", "settings.yml"))
    end

    # Output a message, formatted if we support colors
    def info(message, level=:default)
      $stdout.puts colorize(message, level)
    end

    # Output a message, formatted if we support colors
    def error(message)
      $stderr.puts colorize(message, :error)
    end

    private

    def colorize(message, level=:info)
      # Terminal colors
      colors = {
        :error   => "\e[31m", # red
        :info    => "\e[32m", # green
        :command => "\e[33m", # yellow
        :notice  => "\e[34m"  # blue
      }
      @colorize ? "#{colors[level]}#{message}\e[0m" : message
    end
  end
end
