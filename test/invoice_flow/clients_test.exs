defmodule InvoiceFlow.ClientsTest do
  use InvoiceFlow.DataCase

  alias InvoiceFlow.Clients
  alias InvoiceFlow.Clients.Client
  alias InvoiceFlow.Accounts

  defp create_user(_context \\ %{}) do
    {:ok, user} =
      Accounts.register_user(%{email: "client-test-#{System.unique_integer([:positive])}@example.com", password: "validpassword123"})

    %{user: user}
  end

  describe "create_client/2" do
    # C-1: 클라이언트 생성 성공
    test "creates client with valid attrs" do
      %{user: user} = create_user()

      attrs = %{name: "John Doe", email: "john@example.com", company: "Acme Inc"}
      assert {:ok, %Client{} = client} = Clients.create_client(user.id, attrs)
      assert client.name == "John Doe"
      assert client.email == "john@example.com"
      assert client.company == "Acme Inc"
      assert client.user_id == user.id
    end

    # C-2: 필수 필드 누락 시 실패
    test "fails without required fields" do
      %{user: user} = create_user()

      assert {:error, changeset} = Clients.create_client(user.id, %{})
      assert {"can't be blank", _} = changeset.errors[:name]
      assert {"can't be blank", _} = changeset.errors[:email]
    end

    # C-3: 동일 user의 중복 이메일 거부
    test "rejects duplicate email for same user" do
      %{user: user} = create_user()

      attrs = %{name: "John", email: "dupe@example.com"}
      assert {:ok, _} = Clients.create_client(user.id, attrs)
      assert {:error, changeset} = Clients.create_client(user.id, %{name: "Jane", email: "dupe@example.com"})
      assert {msg, _} = changeset.errors[:user_id] || changeset.errors[:email] || changeset.errors[:user_id_email]
      assert msg == "이미 등록된 클라이언트 이메일입니다"
    end

    # C-4: 다른 user는 같은 이메일 허용
    test "allows same email for different users" do
      %{user: user1} = create_user()
      %{user: user2} = create_user()

      attrs = %{name: "John", email: "shared@example.com"}
      assert {:ok, _} = Clients.create_client(user1.id, attrs)
      assert {:ok, _} = Clients.create_client(user2.id, %{name: "Jane", email: "shared@example.com"})
    end
  end

  describe "update_client/2" do
    # C-5: 클라이언트 수정
    test "updates client fields" do
      %{user: user} = create_user()
      {:ok, client} = Clients.create_client(user.id, %{name: "Old Name", email: "update@example.com"})

      assert {:ok, updated} = Clients.update_client(client, %{name: "New Name", company: "New Corp"})
      assert updated.name == "New Name"
      assert updated.company == "New Corp"
    end
  end

  describe "delete_client/1" do
    # C-6: 클라이언트 삭제
    test "deletes client" do
      %{user: user} = create_user()
      {:ok, client} = Clients.create_client(user.id, %{name: "Delete Me", email: "delete@example.com"})

      assert {:ok, _} = Clients.delete_client(client)
      assert_raise Ecto.NoResultsError, fn -> Clients.get_client!(user.id, client.id) end
    end
  end

  describe "list_clients/2" do
    # C-7: 목록 검색 (이름)
    test "searches by name" do
      %{user: user} = create_user()
      {:ok, _} = Clients.create_client(user.id, %{name: "Alice Smith", email: "alice@example.com"})
      {:ok, _} = Clients.create_client(user.id, %{name: "Bob Jones", email: "bob@example.com"})

      results = Clients.list_clients(user.id, search: "Alice")
      assert length(results) == 1
      assert hd(results).name == "Alice Smith"
    end

    # C-8: 목록 검색 (이메일)
    test "searches by email" do
      %{user: user} = create_user()
      {:ok, _} = Clients.create_client(user.id, %{name: "Alice", email: "alice@search.com"})
      {:ok, _} = Clients.create_client(user.id, %{name: "Bob", email: "bob@other.com"})

      results = Clients.list_clients(user.id, search: "search.com")
      assert length(results) == 1
      assert hd(results).email == "alice@search.com"
    end

    # C-9: 목록 정렬
    test "sorts by name ascending and descending" do
      %{user: user} = create_user()
      {:ok, _} = Clients.create_client(user.id, %{name: "Charlie", email: "c@example.com"})
      {:ok, _} = Clients.create_client(user.id, %{name: "Alice", email: "a@example.com"})
      {:ok, _} = Clients.create_client(user.id, %{name: "Bob", email: "b@example.com"})

      asc = Clients.list_clients(user.id, sort_by: :name, sort_order: :asc)
      assert Enum.map(asc, & &1.name) == ["Alice", "Bob", "Charlie"]

      desc = Clients.list_clients(user.id, sort_by: :name, sort_order: :desc)
      assert Enum.map(desc, & &1.name) == ["Charlie", "Bob", "Alice"]
    end
  end

  describe "get_client_by_email/2" do
    test "finds client by user_id and email" do
      %{user: user} = create_user()
      {:ok, client} = Clients.create_client(user.id, %{name: "Find Me", email: "find@example.com"})

      found = Clients.get_client_by_email(user.id, "find@example.com")
      assert found.id == client.id
    end

    test "returns nil for nonexistent email" do
      %{user: user} = create_user()
      assert Clients.get_client_by_email(user.id, "nope@example.com") == nil
    end
  end
end
