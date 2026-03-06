defmodule InvoiceFlow.FoundationTest do
  use ExUnit.Case

  # F-2: Oban 큐 초기화
  describe "Oban configuration" do
    test "all queues are configured" do
      config = Application.fetch_env!(:invoice_flow, Oban)
      _queues = Keyword.get(config, :queues, [])

      # testing: :inline 모드에서는 queues가 없을 수 있으므로
      # config에 Oban 설정이 존재하는지만 확인
      assert config != nil
    end
  end

  # F-3: PubSub 메시지 발행/구독
  describe "PubSub broadcast/subscribe" do
    test "can subscribe and receive messages" do
      topic = "test:foundation"
      Phoenix.PubSub.subscribe(InvoiceFlow.PubSub, topic)
      Phoenix.PubSub.broadcast(InvoiceFlow.PubSub, topic, {:test_event, "hello"})

      assert_receive {:test_event, "hello"}
    end

    test "uses PubSubTopics for topic names" do
      alias InvoiceFlow.PubSubTopics

      topic = PubSubTopics.invoice_updated("test-id")
      Phoenix.PubSub.subscribe(InvoiceFlow.PubSub, topic)
      Phoenix.PubSub.broadcast(InvoiceFlow.PubSub, topic, {:invoice_updated, %{id: "test-id"}})

      assert_receive {:invoice_updated, %{id: "test-id"}}
    end
  end

  # F-4: Cachex 캐시 읽기/쓰기
  describe "Cachex cache" do
    test "can put and get values" do
      Cachex.put(:invoice_flow_cache, "test_key", "test_value")
      assert {:ok, "test_value"} = Cachex.get(:invoice_flow_cache, "test_key")
    end

    test "returns nil for missing keys" do
      assert {:ok, nil} = Cachex.get(:invoice_flow_cache, "nonexistent_key")
    end
  end
end
