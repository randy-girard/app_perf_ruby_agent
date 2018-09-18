# frozen_string_literal: true

if ::AppPerfRpm.config.instrumentation[:action_view][:enabled] &&
  defined?(::ActiveModel) &&
  defined?(::ActiveModel::Serializer) &&
  defined?(::ActiveModel::Serializer::CollectionSerializer) &&
  defined?(::ActiveModel::Serializer::ArraySerializer)
  [
    ::ActiveModel::Serializer,
    ::ActiveModel::Serializer::CollectionSerializer,
    ::ActiveModel::Serializer::ArraySerializer
  ].each do |klass|
    klass.class_eval do
      alias :as_json_without_trace :as_json
      def as_json(*args)
        span = AppPerfRpm.tracer.start_span(tags: {
          "serializer" => self.class.to_s
        })
        span.log_source_and_backtrace(:active_model_serializer)

        as_json_without_trace(*args)
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

  AppPerfRpm.logger.info "Initializing activemodel/serializer tracer."
end
