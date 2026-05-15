defmodule AutoMyInvoice.ClientsTest do
  use AutoMyInvoice.DataCase

  alias AutoMyInvoice.Clients
  alias AutoMyInvoice.Clients.Client
  alias AutoMyInvoice.Accounts

  defp create_user(_context \\ %{}) do
    {:ok, user} =
      Accounts.register_user(%{
        email: "client-test-#{System.unique_integer([:positive])}@example.com",
        password: "validpassword123"
      })

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

      assert {:error, changeset} =
               Clients.create_client(user.id, %{name: "Jane", email: "dupe@example.com"})

      assert {msg, _} =
               changeset.errors[:user_id] || changeset.errors[:email] ||
                 changeset.errors[:user_id_email]

      assert msg == "이미 등록된 클라이언트 이메일입니다"
    end

    # C-4: 다른 user는 같은 이메일 허용
    test "allows same email for different users" do
      %{user: user1} = create_user()
      %{user: user2} = create_user()

      attrs = %{name: "John", email: "shared@example.com"}
      assert {:ok, _} = Clients.create_client(user1.id, attrs)

      assert {:ok, _} =
               Clients.create_client(user2.id, %{name: "Jane", email: "shared@example.com"})
    end
  end

  describe "update_client/2" do
    # C-5: 클라이언트 수정
    test "updates client fields" do
      %{user: user} = create_user()

      {:ok, client} =
        Clients.create_client(user.id, %{name: "Old Name", email: "update@example.com"})

      assert {:ok, updated} =
               Clients.update_client(client, %{name: "New Name", company: "New Corp"})

      assert updated.name == "New Name"
      assert updated.company == "New Corp"
    end
  end

  describe "delete_client/1" do
    # C-6: 클라이언트 삭제
    test "deletes client" do
      %{user: user} = create_user()

      {:ok, client} =
        Clients.create_client(user.id, %{name: "Delete Me", email: "delete@example.com"})

      assert {:ok, _} = Clients.delete_client(client)
      assert_raise Ecto.NoResultsError, fn -> Clients.get_client!(user.id, client.id) end
    end
  end

  describe "list_clients/2" do
    # C-7: 목록 검색 (이름)
    test "searches by name" do
      %{user: user} = create_user()

      {:ok, _} =
        Clients.create_client(user.id, %{name: "Alice Smith", email: "alice@example.com"})

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

  describe "recalculate_stats/1" do
    defp create_invoice!(user, client, attrs) do
      defaults = %{
        amount: Decimal.new("1000"),
        currency: "USD",
        due_date: Date.add(Date.utc_today(), 30),
        client_id: client.id,
        status: "draft",
        paid_amount: Decimal.new("0")
      }

      merged = Map.merge(defaults, attrs)

      %AutoMyInvoice.Invoices.Invoice{user_id: user.id}
      |> Ecto.Changeset.change(
        invoice_number: "INV-TEST-#{System.unique_integer([:positive])}",
        amount: merged.amount,
        currency: merged.currency,
        due_date: merged.due_date,
        status: merged.status,
        client_id: merged.client_id,
        sent_at: Map.get(merged, :sent_at),
        paid_at: Map.get(merged, :paid_at),
        paid_amount: merged.paid_amount
      )
      |> AutoMyInvoice.Repo.insert!()
    end

    test "calculates total_invoiced and total_paid" do
      %{user: user} = create_user()

      {:ok, client} =
        Clients.create_client(user.id, %{name: "Stats Client", email: "stats@example.com"})

      create_invoice!(user, client, %{
        amount: Decimal.new("1000"),
        status: "paid",
        paid_amount: Decimal.new("1000"),
        sent_at: ~U[2026-01-01 10:00:00Z],
        paid_at: ~U[2026-01-05 10:00:00Z]
      })

      create_invoice!(user, client, %{
        amount: Decimal.new("2000"),
        status: "partially_paid",
        paid_amount: Decimal.new("500"),
        sent_at: ~U[2026-02-01 10:00:00Z]
      })

      create_invoice!(user, client, %{
        amount: Decimal.new("3000"),
        status: "sent",
        paid_amount: Decimal.new("0"),
        sent_at: ~U[2026-03-01 10:00:00Z]
      })

      {:ok, updated} = Clients.recalculate_stats(client.id)

      assert Decimal.equal?(updated.total_invoiced, Decimal.new("6000"))
      assert Decimal.equal?(updated.total_paid, Decimal.new("1500"))
    end

    test "calculates avg_payment_days for paid invoices" do
      %{user: user} = create_user()

      {:ok, client} =
        Clients.create_client(user.id, %{name: "Avg Client", email: "avg@example.com"})

      # Paid in 4 days
      create_invoice!(user, client, %{
        amount: Decimal.new("1000"),
        status: "paid",
        paid_amount: Decimal.new("1000"),
        sent_at: ~U[2026-01-01 10:00:00Z],
        paid_at: ~U[2026-01-05 10:00:00Z]
      })

      # Paid in 10 days
      create_invoice!(user, client, %{
        amount: Decimal.new("2000"),
        status: "paid",
        paid_amount: Decimal.new("2000"),
        sent_at: ~U[2026-02-01 10:00:00Z],
        paid_at: ~U[2026-02-11 10:00:00Z]
      })

      {:ok, updated} = Clients.recalculate_stats(client.id)

      # Average of 4 and 10 = 7
      assert updated.avg_payment_days == 7
    end

    test "handles client with no invoices" do
      %{user: user} = create_user()

      {:ok, client} =
        Clients.create_client(user.id, %{name: "Empty Client", email: "empty@example.com"})

      {:ok, updated} = Clients.recalculate_stats(client.id)

      assert Decimal.equal?(updated.total_invoiced, Decimal.new("0"))
      assert Decimal.equal?(updated.total_paid, Decimal.new("0"))
      assert updated.avg_payment_days == nil
    end
  end

  describe "on_time_rate/1" do
    test "calculates percentage of on-time payments" do
      %{user: user} = create_user()

      {:ok, client} =
        Clients.create_client(user.id, %{name: "OnTime Client", email: "ontime@example.com"})

      # Paid on time (within due_date + 3 days)
      create_invoice!(user, client, %{
        amount: Decimal.new("1000"),
        status: "paid",
        paid_amount: Decimal.new("1000"),
        due_date: ~D[2026-01-10],
        sent_at: ~U[2026-01-01 10:00:00Z],
        paid_at: ~U[2026-01-12 10:00:00Z]
      })

      # Paid on time (exactly on due_date)
      create_invoice!(user, client, %{
        amount: Decimal.new("2000"),
        status: "paid",
        paid_amount: Decimal.new("2000"),
        due_date: ~D[2026-02-10],
        sent_at: ~U[2026-02-01 10:00:00Z],
        paid_at: ~U[2026-02-10 10:00:00Z]
      })

      # Paid late (after due_date + 3 days)
      create_invoice!(user, client, %{
        amount: Decimal.new("3000"),
        status: "paid",
        paid_amount: Decimal.new("3000"),
        due_date: ~D[2026-03-10],
        sent_at: ~U[2026-03-01 10:00:00Z],
        paid_at: ~U[2026-03-20 10:00:00Z]
      })

      rate = Clients.on_time_rate(client.id)
      # 2 out of 3 on time = 66.7%
      assert rate == 66.7
    end

    test "returns 0 for client with no paid invoices" do
      %{user: user} = create_user()

      {:ok, client} =
        Clients.create_client(user.id, %{name: "NoPaid Client", email: "nopaid@example.com"})

      assert Clients.on_time_rate(client.id) == 0.0
    end
  end

  describe "client_ranking/1" do
    test "returns clients ordered by avg_payment_days" do
      %{user: user} = create_user()

      {:ok, fast_client} =
        Clients.create_client(user.id, %{name: "Fast Payer", email: "fast@example.com"})

      {:ok, slow_client} =
        Clients.create_client(user.id, %{name: "Slow Payer", email: "slow@example.com"})

      # Fast client: 2 paid invoices, ~2 days each
      for _ <- 1..2 do
        create_invoice!(user, fast_client, %{
          amount: Decimal.new("1000"),
          status: "paid",
          paid_amount: Decimal.new("1000"),
          due_date: ~D[2026-01-30],
          sent_at: ~U[2026-01-01 10:00:00Z],
          paid_at: ~U[2026-01-03 10:00:00Z]
        })
      end

      # Slow client: 2 paid invoices, ~20 days each
      for _ <- 1..2 do
        create_invoice!(user, slow_client, %{
          amount: Decimal.new("1000"),
          status: "paid",
          paid_amount: Decimal.new("1000"),
          due_date: ~D[2026-02-28],
          sent_at: ~U[2026-02-01 10:00:00Z],
          paid_at: ~U[2026-02-21 10:00:00Z]
        })
      end

      ranking = Clients.client_ranking(user.id)
      assert length(ranking) == 2
      assert hd(ranking).name == "Fast Payer"
      assert List.last(ranking).name == "Slow Payer"
    end

    test "excludes clients with fewer than 2 paid invoices" do
      %{user: user} = create_user()

      {:ok, one_invoice_client} =
        Clients.create_client(user.id, %{name: "One Invoice", email: "one@example.com"})

      create_invoice!(user, one_invoice_client, %{
        amount: Decimal.new("1000"),
        status: "paid",
        paid_amount: Decimal.new("1000"),
        sent_at: ~U[2026-01-01 10:00:00Z],
        paid_at: ~U[2026-01-03 10:00:00Z]
      })

      ranking = Clients.client_ranking(user.id)
      assert ranking == []
    end
  end

  describe "client_analytics/1" do
    test "returns complete analytics for a client" do
      %{user: user} = create_user()

      {:ok, client} =
        Clients.create_client(user.id, %{name: "Analytics Client", email: "analytics@example.com"})

      # Paid invoice
      create_invoice!(user, client, %{
        amount: Decimal.new("1000"),
        status: "paid",
        paid_amount: Decimal.new("1000"),
        due_date: ~D[2026-01-30],
        sent_at: ~U[2026-01-01 10:00:00Z],
        paid_at: ~U[2026-01-05 10:00:00Z]
      })

      # Unpaid invoice
      create_invoice!(user, client, %{
        amount: Decimal.new("2000"),
        status: "sent",
        paid_amount: Decimal.new("0"),
        sent_at: ~U[2026-02-01 10:00:00Z]
      })

      analytics = Clients.client_analytics(client.id)

      assert analytics.avg_payment_days == 4
      assert Decimal.equal?(analytics.total_invoiced, Decimal.new("3000"))
      assert Decimal.equal?(analytics.total_paid, Decimal.new("1000"))
      assert Decimal.equal?(analytics.outstanding_amount, Decimal.new("2000"))
      assert analytics.invoice_count == 2
      assert analytics.paid_count == 1
      assert analytics.on_time_rate == 100.0
    end
  end

  describe "get_client_by_email/2" do
    test "finds client by user_id and email" do
      %{user: user} = create_user()

      {:ok, client} =
        Clients.create_client(user.id, %{name: "Find Me", email: "find@example.com"})

      found = Clients.get_client_by_email(user.id, "find@example.com")
      assert found.id == client.id
    end

    test "returns nil for nonexistent email" do
      %{user: user} = create_user()
      assert Clients.get_client_by_email(user.id, "nope@example.com") == nil
    end
  end
end
