require File.expand_path(File.join(File.dirname(__FILE__), 'helpers'))

class SchemaTest < Minitest::Test
  def test_dereference_with_ref
    key, value = user_input_schema.dereference(
      '$ref' => '#/definitions/user/definitions/id'
    )
    assert_equal(key,   '#/definitions/user/definitions/id')
    user_id = user_input_schema['definitions']['user']['definitions']['id']
    assert_equal(value, user_id)
  end

  def test_dereference_without_ref
    key, value = user_input_schema.dereference(
      '#/definitions/user/definitions/id'
    )
    assert_equal(key,   '#/definitions/user/definitions/id')
    user_id = user_input_schema['definitions']['user']['definitions']['id']
    assert_equal(value, user_id)
  end

  def test_dereference_with_nested_ref
    key, value = user_input_schema.dereference(
      '$ref' => '#/definitions/user/definitions/identity'
    )
    assert_equal(key,   '#/definitions/user/definitions/id')
    user_id = user_input_schema['definitions']['user']['definitions']['id']
    assert_equal(value, user_id)
  end

  def test_dereference_with_local_context
    key, value = user_input_schema.dereference(
      '$ref'     => '#/definitions/user/properties/id',
      'override' => true
    )
    assert_equal(key,   '#/definitions/user/definitions/id')
    user_id = user_input_schema['definitions']['user']['definitions']['id']
    assert_equal(value, { 'override' => true }.merge(user_id))
  end

  def test_schema_example_for_items
    example = user_input_schema.schema_example(
      'type' => 'array',
      'items' => {
        'anyOf' => [
          { '$ref' => '#/definitions/user/definitions/id' },
          { '$ref' => '#/definitions/user/definitions/created_at' }
        ]
      }
    )
    user_id = user_input_schema['definitions']['user']['definitions']['id']['example']
    assert_equal(example, [user_id])
  end
end
