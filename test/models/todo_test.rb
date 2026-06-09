require "test_helper"

class TodoTest < ActiveSupport::TestCase
  test "is invalid without a description" do
    todo = Todo.new(description: "")
    assert_not todo.valid?, "expected a blank description to be invalid"
    assert_includes todo.errors[:description], "can't be blank"
  end

  test "is valid with a description" do
    assert Todo.new(description: "Write the report").valid?
  end
end
