module ActiveModel
  class Serializer
    class HashSerializer
      include Enumerable
      delegate :each, :keys, :values, to: :@serializer_hash

      attr_reader :object, :root

      def initialize(object, options={})
        @object  = object
        @options = options
        @root    = options[:root]
        @serializer_hash = to_serializable_values(object, options)
        @serializer_values = @serializer_hash.values.select { |v| v.is_a?(ActiveModel::Serializer) }
      end

      def success?
        true
      end

      def serializable_hash(adapter_options = nil, options = {}, adapter_instance = self.class.serialization_adapter_instance)
        adapter_options ||= {}
        include_directive = ActiveModel::Serializer.include_directive_from_options(adapter_options)
        adapter_options[:cached_attributes] ||= ActiveModel::Serializer.cache_read_multi(@serializer_values, adapter_instance, include_directive)
        adapter_options_with_include = adapter_options.merge(include_directive: include_directive)
        @serializer_hash.each_with_object({}) do |(key, value), output|
          output[key] = if value.respond_to?(:serializable_hash)
            value.serializable_hash(adapter_options_with_include, options, adapter_instance) || value
          else
            value
          end
        end
      end
      alias to_hash serializable_hash
      alias to_h serializable_hash

      def json_key
        root
      end

      def as_json(adapter_options = nil)
        serializable_hash(adapter_options)
      end

      def self.serialization_adapter_instance
        @serialization_adapter_instance ||= ActiveModelSerializers::Adapter::Attributes
      end

      private

      def to_serializable_values(object, options)
        serializer_context_class = options.fetch(:serializer_context_class, ActiveModel::Serializer)
        object.each_with_object({}) do |(key, value), output|
          output[key] = serializer_for_resource(value, serializer_context_class, options) || value
        end
      end
    
      def serializer_for_resource(resource, serializer_context_class, options)
        serializer_class = serializer_context_class.serializer_for(resource, namespace: options[:namespace])
        return unless serializer_class.present?
    
        catch(:no_serializer) do
          if serializer_class == ActiveModel::Serializer::CollectionSerializer && options[:uniform_collection] && !resource.empty?
            element_serializer = serializer_context_class.serializer_for(resource.first, namespace: options[:namespace])
            serializer_class.new(resource, options.merge(serializer: element_serializer))
          else
            serializer_class.new(resource, options.except(:serializer))
          end
        end
      end
    end
  end
end
