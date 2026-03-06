defmodule InvoiceFlow.ErrorsTest do
  use ExUnit.Case, async: true

  alias InvoiceFlow.Errors

  describe "NotFound" do
    test "generates message from resource and id" do
      error = %Errors.NotFound{resource: "Invoice", id: "abc-123"}
      assert Exception.message(error) == "Invoice not found: abc-123"
    end

    test "can be raised" do
      assert_raise Errors.NotFound, "User not found: xyz", fn ->
        raise Errors.NotFound, resource: "User", id: "xyz"
      end
    end
  end

  describe "Unauthorized" do
    test "has custom message" do
      error = %Errors.Unauthorized{message: "Access denied"}
      assert Exception.message(error) == "Access denied"
    end
  end

  describe "ValidationError" do
    test "has custom message" do
      error = %Errors.ValidationError{message: "Invalid email format"}
      assert Exception.message(error) == "Invalid email format"
    end
  end
end
