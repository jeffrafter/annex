module Annex
  class List < Command
    def execute
      which = servers.select do |server|
        name_tag = server.tags["Name"]
        name_tag = name_tag.gsub(/-i-[0-9a-f]+$/, '') rescue ''

        choose = server.state == "running"
        choose = choose && name_tag =~ /^#{role}/ if role
        choose = choose && name_tag =~ /#{environment}$/ if environment
        choose
      end

      which.each do |server|
        @env.info(server.tags["Name"], :info)
        @env.info("  #{server.dns_name}\n  Public: #{server.public_ip_address}\n  Private: #{server.private_ip_address}\n", :notice)
      end
    end
  end
end
