require 'active_model'
require 'active_support/core_ext/hash'
require 'active_support/inflector'

module SimpleSDKBuilder
module Resource

  def self.included(klass)
    klass.class_eval do
      extend ActiveModel::Naming
      include ActiveModel::Conversion
      include ActiveModel::Serializers::JSON
      self.include_root_in_json = false
    end

    klass.extend ClassMethods
  end

  def initialize(attrs = {})
    @attributes = {}.with_indifferent_access
    #self.class.simple_sdk_attributes.each do |attr|
    #  @attributes[attr] = nil
    #end
    self.attributes = attrs
  end

  def attributes
    @attributes
  end

  def attributes=(attributes)
    attributes.each do |key, value|
      if self.class.simple_sdk_attributes.include?(key.to_s)
        self.send("#{key}=", value)
      end
    end
  end

  def persisted?
    !!id
  end

  private

  def write_attribute(attr, value, options = {})
    @attributes[attr] = build_attribute(attr, value, options)
  end

  def build_attribute(attr, value, options)
    options = {
      :class_name => nil,
      :nested => false
    }.merge(options)

    if options[:nested] && value.is_a?(Array)
      value.collect { |v| build_attribute(attr, v, options) }
    elsif options[:nested] && value.is_a?(Hash) && value.include?("0")
      arr = []
      (0...(value.size)).each do |i|
        arr.push value[i.to_s]
      end
      build_attribute(attr, arr, options)
    elsif options[:nested] && value.is_a?(Hash)
      class_name = options[:class_name] || guess_class_name(attr)
      nested_class = eval(class_name)
      nested_class.new(value)
    else
      value
    end
  end

  def guess_class_name(attr)
    namespace = ''
    class_name = self.class.name
    if class_name.rindex(':')
      namespace = class_name[0..class_name.rindex(':')]
    end
    attr.chomp!("_attributes")
    result = "#{namespace}#{attr.camelize.singularize}"
    result
  end

  module ClassMethods

    def simple_sdk_attribute(*attrs)
      attrs.each do |attr|
        attr = attr.to_s
        simple_sdk_attributes.push(attr)
        define_method attr do
          @attributes[attr]
        end
        define_method "#{attr}=" do |value|
          write_attribute(attr, value)
        end
      end
    end

    def simple_sdk_nested_attribute(attr, options = {})
      options = {
        :nested => true
      }.merge(options)
      attr = attr.to_s
      simple_sdk_attributes.push(attr)
      simple_sdk_attributes.push("#{attr}_attributes") # for ActiveRecord nested attributes
      define_method attr do
        @attributes[attr] ||= []
      end
      alias_method :"#{attr}_attributes", :"#{attr}" # for ActiveRecord nested attributes
      define_method "#{attr}=" do |value|
        write_attribute(attr, value, options)
      end
      alias_method :"#{attr}_attributes=", :"#{attr}=" # for ActiveRecord nested attributes
    end

    def simple_sdk_attributes
      @simple_sdk_attributes ||= []
    end

  end

end
end
