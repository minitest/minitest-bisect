require "minitest"

module Minitest
  @server = false

  def self.plugin_server_options opts, options # :nodoc:
    opts.on "--server=pid", Integer, "Connect to minitest server w/ pid." do |s|
      @server = s
    end
  end

  def self.plugin_server_init options
    if @server then
      require "minitest/server"
      self.reporter << Minitest::ServerReporter.new(@server)
    end
  end
end

module Minitest
  class ServerReporter < Minitest::AbstractReporter
    def initialize pid
      DRb.start_service
      uri = Minitest::Server.path(pid)
      @mt_server = DRbObject.new_with_uri uri
      super()
    end

    def start
      @mt_server.start
    end

    def record result
      r = result
      c = r.class
      file, = c.instance_method(r.name).source_location
      @mt_server.result file, c.name, r.name, r.failures, r.assertions, r.time
    end

    def report
      @mt_server.report
    end
  end
end
