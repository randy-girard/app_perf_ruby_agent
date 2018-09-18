# frozen_string_literal: true

module AppPerfRpm
  module Instruments
    module GrapeMiddleware

      def call_with_trace(env)
        req = ::Rack::Request.new(env)

        request_method = req.request_method.to_s.upcase
        path = req.path
        endpoint = env["api.endpoint"]

        if endpoint && endpoint.options
          options = endpoint.options
          request_method = options[:method].first.to_s.upcase
          klass = options[:for]
          namespace = endpoint.namespace
          namespace = "" if namespace == "/"

          path = options[:path].first.to_s
          path = "/#{path}" if path[0] != "/"
          path = "#{namespace}#{path}"
        end

        action = path.to_s.split("/").last

        span = AppPerfRpm.tracer.start_span(tags: {
          "component" => "Grape",
          "name" => @app.class.name,
          "controller" => klass,
          "action" => action,
          "path" => path,
          "method" => request_method
        })
        span.log_source_and_backtrace(:rack)

        begin
          call_without_trace(env)
        rescue Exception => e
          if span
            span.set_tag('error', true)
            span.log_error(e)
          end
          raise
        ensure
          span.finish if span
        end
      end
    end
  end
end

if ::AppPerfRpm.config.instrumentation[:grape][:enabled] && defined?(::Grape)
  ::AppPerfRpm.logger.info "Initializing grape tracer."
  ::Grape::Middleware::Base.send(:include, AppPerfRpm::Instruments::GrapeMiddleware)
  ::Grape::Middleware::Base.class_eval do
    alias_method :call_without_trace, :call
    alias_method :call, :call_with_trace
  end
end
