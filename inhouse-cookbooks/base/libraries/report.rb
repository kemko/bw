require 'rubygems'

module Express42
  class ReportHandler < Chef::Handler
    def initialize
    end

    def report
      run_status.updated_resources.each do |r|
        puts r.to_s
      end
    end
  end
end


