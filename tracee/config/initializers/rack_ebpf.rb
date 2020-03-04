require 'rack-ebpf'

Rails.application.config.middleware.insert_before Rack::Sendfile, Rack::EBPF
