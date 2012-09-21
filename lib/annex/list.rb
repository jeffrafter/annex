module Annex
  class List < Command
    def execute
      which = servers.select do |server|
        choose = server.state == "running"
        choose = choose && server.tags["Name"] =~ /^#{role}/ if role
        choose = choose && server.tags["Name"] =~ /#{environment}-\d+$/ if environment
        choose
      end

      which.each do |server|
        @env.info(server.tags["Name"], :info)
        @env.info("  #{server.dns_name}\n  Public: #{server.public_ip_address}\n  Private: #{server.private_ip_address}\n", :notice)
      end
    end
  end
end
