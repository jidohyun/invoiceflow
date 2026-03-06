defmodule InvoiceFlow.PubSubTopicsTest do
  use ExUnit.Case, async: true

  alias InvoiceFlow.PubSubTopics

  describe "invoice_updated/1" do
    test "returns topic with invoice id" do
      assert PubSubTopics.invoice_updated("abc-123") == "invoice:abc-123"
    end
  end

  describe "user_invoices/1" do
    test "returns topic with user id" do
      assert PubSubTopics.user_invoices("user-456") == "user:user-456:invoices"
    end
  end

  describe "extraction_completed/1" do
    test "returns topic with job id" do
      assert PubSubTopics.extraction_completed("job-789") == "extraction:job-789"
    end
  end

  describe "payment_received/1" do
    test "returns topic with invoice id" do
      assert PubSubTopics.payment_received("inv-101") == "payment:inv-101"
    end
  end
end
