require "drb"
require "tmpdir"
require "minitest"

module Minitest
  class Server
    TOPDIR = Dir.pwd + "/"

    def self.path pid = $$
      "drbunix:#{Dir.tmpdir}/minitest.#{pid}"
    end

    def self.run client
      DRb.start_service path, new(client)
    end

    def self.stop
      DRb.stop_service
    end

    attr_accessor :client

    def initialize client
      self.client = client
    end

    def quit
      self.class.stop
    end

    def start
      client.failures.clear
    end

    def result file, klass, method, fails, assertions, time
      file = file.sub(/^#{TOPDIR}/, "")

      client.result file, klass, method, fails, assertions, time
    end

    def report
      # do nothing
    end
  end
end
