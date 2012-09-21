module Fog
  module SSH
    class Real
      def run(commands)
        commands = [*commands]
        results  = []
        begin
          Net::SSH.start(@address, @username, @options) do |ssh|
            commands.each do |command|
              result = Result.new(command)
              ssh.open_channel do |ssh_channel|
                ssh_channel.request_pty
                ssh_channel.exec(command) do |channel, success|
                  unless success
                    raise "Could not execute command: #{command.inspect}"
                  end

                  channel.on_data do |ch, data|
                    result.stdout << handle_data(channel, data)
                  end

                  channel.on_extended_data do |ch, type, data|
                    next unless type == 1
                    result.stderr << handle_error(channel, data)
                  end

                  channel.on_request('exit-status') do |ch, data|
                    result.status = data.read_long
                  end

                  channel.on_request('exit-signal') do |ch, data|
                    result.status = 255
                  end
                end
              end
              ssh.loop
              results << result
            end
          end
        rescue Net::SSH::HostKeyMismatch => exception
          exception.remember_host!
          sleep 0.2
          retry
        end
        results
      end

      def handle_data(channel, data)
        data
      end

      def handle_error(channel, error)
        error
      end
    end

    class Real
      def handle_data(channel, data)
        puts data
        data
      end

      def handle_error(channel, error)
        puts error.red
        error
      end
    end
  end
end
