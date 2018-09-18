# frozen_string_literal: true

module AppPerfRpm
  module Instruments
    module TyphoeusRequest
      def run_with_trace
        span = ::AppPerfRpm.tracer.start_span(tags: {
          "component" => "Typhoeus"
        })
        AppPerfRpm.tracer.inject(span.context, OpenTracing::FORMAT_RACK, options[:headers])

        response = run_without_trace
        span.exit
        uri = URI(response.effective_url)

        span.set_tag "status_code", response.code
        span.set_tag "url", uri.to_s
        span.set_tag "method", options[:method]
        span.log_source_and_backtrace(:typhoeus)

        response
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

    module TyphoeusHydra
      def run_with_trace
        span = ::AppPerfRpm.tracer.start_span("app.http.requests", tags: {
          "component" => "Typhoeus",
          "method" => "hydra",
          "queued_requests" => queued_requests.count,
          "max_concurrency" => max_concurrency
        })
        span.log_source_and_backtrace(:typhoeus)

        run_without_trace
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

if ::AppPerfRpm.config.instrumentation[:typhoeus][:enabled] && defined?(::Typhoeus)
  ::AppPerfRpm.logger.info "Initializing typhoeus tracer."

  ::Typhoeus::Request::Operations.send(:include, AppPerfRpm::Instruments::TyphoeusRequest)
  ::Typhoeus::Request::Operations.class_eval do
    alias_method :run_without_trace, :run
    alias_method :run, :run_with_trace
  end

  ::Typhoeus::Hydra.send(:include, AppPerfRpm::Instruments::TyphoeusHydra)
  ::Typhoeus::Hydra.class_eval do
    alias_method :run_without_trace, :run
    alias_method :run, :run_with_trace
  end
end
