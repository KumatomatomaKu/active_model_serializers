require 'test_helper'

module ActiveModel
  class Serializer
    class HashSerializerTest < ActiveSupport::TestCase
      class SingularModel < ::Model
        attributes :id, :name
      end
      class SingularModelSerializer < ActiveModel::Serializer
        attributes :id, :name
      end
      class HasManyModel < ::Model
        associations :singular_models
      end
      class HasManyModelSerializer < ActiveModel::Serializer
        has_many :singular_models

        def custom_options
          instance_options
        end
      end

      def setup
        @singular_model = SingularModel.new
        @has_many_model = HasManyModel.new
        @resource = {
          single: @singular_model,
          many:   @has_many_model
        }
        @serializer = HashSerializer.new(@resource, some: :options)
      end

      def test_has_object_reader_serializer_interface
        assert_equal @serializer.object, @resource
      end

      def test_respond_to_each
        assert_respond_to @serializer, :each
      end

      def test_each_object_should_be_serialized_with_appropriate_serializer
        serializers =  @serializer.values

        assert_kind_of SingularModelSerializer, serializers.first
        assert_kind_of SingularModel, serializers.first.object

        assert_kind_of HasManyModelSerializer, serializers.last
        assert_kind_of HasManyModel, serializers.last.object

        assert_equal :options, serializers.last.custom_options[:some]
      end

      def test_serializer_option_not_passed_to_each_serializer
        serializers = HashSerializer.new({ many: @has_many_model }, serializer: HasManyModelSerializer).values

        refute serializers.first.custom_options.key?(:serializer)
      end

      def test_serializer_option_set_to_uniform_collection_sub_serializer
        serializers = HashSerializer.new({ many: [@has_many_model] }, serializer: SingularModelSerializer, uniform_collection: true).values

        assert_equal serializers.first.instance_variable_get(:@options)[:serializer], HasManyModelSerializer
      end

      def test_root
        expected = 'custom_root'
        @serializer = HashSerializer.new({ single: @singular_model, many: @has_many_model }, root: expected)
        assert_equal expected, @serializer.root
      end

      def test_json_key_with_root
        expected = 'custom_root'
        @serializer = HashSerializer.new({ single: @singular_model, many: @has_many_model }, root: expected)
        assert_equal expected, @serializer.json_key
      end

      def test_as_json
        expected = {
          value: 123,
          single: {id: 1, name: 'name'},
          many: {
            singular_models: [
              {id: 2, name: 'mena'}
            ]
          },
          array: [
            {id: 1, name: 'name'},
            {id: 2, name: 'mena'}
          ]
        }
        single_1 = SingularModel.new(id: 1, name: 'name')
        single_2 = SingularModel.new(id: 2, name: 'mena')
        @serializer = HashSerializer.new({ value: 123, single: single_1, many: HasManyModel.new(singular_models: [single_2]), array: [single_1, single_2] }, root: expected)
        assert_equal expected, @serializer.as_json
      end
    end
  end
end
