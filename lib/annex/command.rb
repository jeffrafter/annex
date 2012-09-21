require 'fog'

# Need some better logging
require 'mixins/fog'

module Annex
  class Command
    def initialize(env, options)
      @env = env
      @options = options
    end

    def execute
      raise NotImplementedError
    end

    protected

    def template(name)
      content = File.read(File.join(File.expand_path(File.dirname(__FILE__)),"..","..","templates","#{name}.erb")) rescue nil
      erb = ERB.new(content)
      erb.result(binding)
    end

    def connection
      @connection = Fog::Compute.new({
        :provider => 'AWS',
        :aws_access_key_id => @env.config['amazon']['access_key_id'],
        :aws_secret_access_key => @env.config['amazon']['secret_access_key']
      })
    end

    def servers
      @servers ||= connection.servers.all
    end

    def role
      @role ||= @options[:role]
    end

    def environment
      @environment ||= @options[:environment]
    end
  end
end
