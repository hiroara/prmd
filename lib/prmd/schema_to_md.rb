require 'erubis'
require 'json'

def dereference(data)
  if data.has_key?('$ref')
    schema_id, key = data['$ref'].split('#')
    schema_id = schema_id.gsub(%r{^/}, '') # drop leading slash if one exists
    definition = key.gsub('/definitions/', '')
    SCHEMATA[schema_id]['definitions'][definition]
  else
    expand_references(data)
  end
end

def expand_references(data)
  data.keys.each do |key|
    value = data[key]
    data[key] = case value
    when Hash
      dereference(value)
    when Array
      if key == 'anyOf'
        value
      else
        value.map do |item|
          if item.is_a?(Hash)
            dereference(item)
          else
            item
          end
        end
      end
    else
      value
    end
  end
  data
end

def extract_attributes(properties)
  attributes = []
  properties.each do |key, value|
    # found a reference to another element:
    if value.has_key?('anyOf')
      descriptions = []
      examples = []

      # sort anyOf! always show unique identifier first
      anyof = value['anyOf'].sort_by do |property|
        property['$ref'].split('/').last.gsub('id', 'a')
      end

      anyof.each do |ref|
        nested_field = dereference(ref)
        descriptions << nested_field['description']
        examples << nested_field['example']
      end

      # avoid repetition :}
      if descriptions.size > 1
        descriptions.first.gsub!(/ of (this )?.*/, "")
        descriptions[1..-1].map { |d| d.gsub!(/unique /, "") }
      end
      description = descriptions.join(" or ")
      example = doc_example(*examples)
      attributes << [key, "string", description, example]

    # found a nested object
    elsif value['type'] == ['object'] && value['properties']
      properties = value['properties'].sort_by { |k, v| k }

      properties.each do |prop_name, prop_value|
        new_key = "#{key}:#{prop_name}"
        attributes << [new_key, doc_type(prop_value),
          prop_value['description'], doc_example(prop_value['example'])]
      end

    # just a regular attribute
    else
      example = doc_example(value['example'])
      attributes << [key, doc_type(value),
        value['description'], example]
    end
  end
  return attributes
end

def doc_type(property)
  schema_type = property["type"].dup
  type = "nullable " if schema_type.delete("null")
  type.to_s + (property["format"] || schema_type.first)
end

def doc_example(*examples)
  examples.map { |e| "<code>#{e.to_json}</code>" }.join(" or ")
end

SCHEMATA = {}
Dir.glob(File.join(File.dirname(__FILE__), 'schema/*.*')).each do |path|
  data = JSON.parse(File.read(path))
  SCHEMATA[data['id']] = data
end

SCHEMATA.each do |key,value|
  SCHEMATA[key] = expand_references(value)
end

devcenter_header_path = File.join(File.dirname(__FILE__), 'devcenter_header.md')
if File.exists?(devcenter_header_path)
  puts File.read(File.join(File.dirname(__FILE__), 'devcenter_header.md'))
end
overview_path = File.join(File.dirname(__FILE__), 'overview.md')
if File.exists?(overview_path)
  puts File.read(File.join(File.dirname(__FILE__), 'overview.md'))
end

SCHEMATA.each do |_, schema|
  next if (schema['links'] || []).empty?
  resource = schema['id'].split('/').last
  if schema['definitions'].has_key?('identity')
    identifiers = schema['definitions']['identity']['anyOf'].map {|ref| ref['$ref'].split('/').last }
    identity = resource + '_' + identifiers.join('_or_')
  end
  serialization = {}
  if schema['properties']
    schema['properties'].each do |key, value|
      unless value.has_key?('properties')
        serialization[key] = value['example']
      else
        serialization[key] = {}
        value['properties'].each do |k,v|
          serialization[key][k] = v['example']
        end
      end
    end
  else
    serialization.merge!(schema['example'])
  end

  title = schema['title'].split(' - ', 2).last

  puts Erubis::Eruby.new(File.read(File.dirname(__FILE__) + "/endpoint.erb")).result({
    identifiers:     identifiers,
    identity:        identity,
    resource:        resource,
    schema:          schema,
    serialization:   serialization,
    title:           title,
    params_template: File.read(File.dirname(__FILE__) + "/parameters.erb"),
  })
end
