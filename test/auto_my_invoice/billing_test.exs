defmodule AutoMyInvoice.BillingTest do
  use AutoMyInvoice.DataCase

  alias AutoMyInvoice.Billing
  alias AutoMyInvoice.Billing.Subscription
  alias AutoMyInvoice.Accounts

  defp create_user(attrs \\ %{}) do
    email = "user#{System.unique_integer([:positive])}@test.com"

    {:ok, user} =
      Accounts.register_user(%{
        email: Map.get(attrs, :email, email),
        password: "ValidPassword123!"
      })

    if plan = Map.get(attrs, :plan) do
      {:ok, user} = Accounts.update_profile(user, %{plan: plan})
      user
    else
      user
    end
  end

  describe "plans/0" do
    test "returns all available plans" do
      plans = Billing.plans()
      assert Map.has_key?(plans, "free")
      assert Map.has_key?(plans, "starter")
      assert Map.has_key?(plans, "pro")
    end

    test "free plan has 3 monthly invoices" do
      plans = Billing.plans()
      assert plans["free"].monthly_invoices == 3
      assert plans["free"].price == 0
    end

    test "starter and pro plans have unlimited invoices" do
      plans = Billing.plans()
      assert plans["starter"].monthly_invoices == :unlimited
      assert plans["pro"].monthly_invoices == :unlimited
    end
  end

  describe "plans_ordered/0" do
    # Regression: ISSUE-002 — billing page rendered plans alphabetically
    # (Free → Pro $29 → Starter $9) because Elixir maps don't preserve
    # insertion order. plans_ordered/0 sorts by price ascending so the
    # billing UI shows Free → Starter → Pro.
    # Found by /qa on 2026-05-15
    # Report: .gstack/qa-reports/qa-report-localhost-2026-05-15.md
    test "returns plans as a list sorted by price ascending" do
      ordered = Billing.plans_ordered()
      assert is_list(ordered)
      assert Enum.map(ordered, fn {id, _plan} -> id end) == ["free", "starter", "pro"]
      prices = Enum.map(ordered, fn {_id, plan} -> plan.price end)
      assert prices == Enum.sort(prices)
    end
  end

  describe "plan_info/1" do
    test "returns correct plan info" do
      info = Billing.plan_info("starter")
      assert info.name == "Starter"
      assert info.price == 9
    end

    test "returns free plan for unknown plan" do
      info = Billing.plan_info("nonexistent")
      assert info.name == "Free"
    end
  end

  describe "usage_summary/1" do
    test "returns usage data for free plan user" do
      user = create_user()
      summary = Billing.usage_summary(user.id)

      assert summary.plan == "free"
      assert summary.plan_name == "Free"
      assert summary.invoices_limit == 3
      assert summary.invoices_used == 0
      assert summary.can_create == true
      assert summary.usage_percent == 0
    end

    test "returns unlimited for starter plan user" do
      user = create_user(%{plan: "starter"})
      summary = Billing.usage_summary(user.id)

      assert summary.plan == "starter"
      assert summary.invoices_limit == :unlimited
      assert summary.can_create == true
      assert summary.usage_percent == 0
    end
  end

  describe "activate_subscription/1" do
    test "creates subscription and updates user plan" do
      user = create_user()

      data = %{
        "id" => "sub_#{System.unique_integer([:positive])}",
        "customer_id" => "ctm_123",
        "custom_data" => %{"user_id" => user.id, "plan" => "starter"},
        "current_billing_period" => %{
          "starts_at" => DateTime.to_iso8601(DateTime.utc_now()),
          "ends_at" => DateTime.to_iso8601(DateTime.add(DateTime.utc_now(), 30, :day))
        }
      }

      assert :ok = Billing.activate_subscription(data)

      sub = Billing.get_active_subscription(user.id)
      assert sub != nil
      assert sub.plan == "starter"
      assert sub.status == "active"

      updated_user = Accounts.get_user!(user.id)
      assert updated_user.plan == "starter"
    end
  end

  describe "cancel_subscription/1" do
    test "marks subscription as cancelled" do
      user = create_user()

      paddle_sub_id = "sub_cancel_#{System.unique_integer([:positive])}"

      %Subscription{user_id: user.id}
      |> Subscription.changeset(%{
        paddle_subscription_id: paddle_sub_id,
        paddle_customer_id: "ctm_456",
        plan: "starter",
        status: "active"
      })
      |> Repo.insert!()

      data = %{"id" => paddle_sub_id}
      assert :ok = Billing.cancel_subscription(data)

      sub = Repo.get_by(Subscription, paddle_subscription_id: paddle_sub_id)
      assert sub.status == "cancelled"
      assert sub.cancelled_at != nil
    end

    test "handles unknown subscription gracefully" do
      assert :ok = Billing.cancel_subscription(%{"id" => "nonexistent"})
    end
  end

  describe "get_active_subscription/1" do
    test "returns nil when no subscription exists" do
      user = create_user()
      assert Billing.get_active_subscription(user.id) == nil
    end
  end
end
