defmodule AutoMyInvoice.Accounts.UserTest do
  use AutoMyInvoice.DataCase, async: true

  alias AutoMyInvoice.Accounts.User

  describe "profile_changeset/2 brand_color validation" do
    test "accepts a valid hex color like #RRGGBB" do
      changeset = User.profile_changeset(%User{}, %{brand_color: "#ff5722"})
      assert changeset.valid?
      assert get_field(changeset, :brand_color) == "#ff5722"
    end

    test "accepts uppercase hex" do
      changeset = User.profile_changeset(%User{}, %{brand_color: "#FF5722"})
      assert changeset.valid?
    end

    test "allows nil (optional)" do
      changeset = User.profile_changeset(%User{}, %{brand_color: nil})
      assert changeset.valid?
    end

    test "rejects malformed hex (missing hash)" do
      changeset = User.profile_changeset(%User{}, %{brand_color: "ff5722"})
      refute changeset.valid?
      assert %{brand_color: [_]} = errors_on(changeset)
    end

    test "rejects 3-digit shorthand" do
      changeset = User.profile_changeset(%User{}, %{brand_color: "#abc"})
      refute changeset.valid?
    end

    test "rejects non-hex characters" do
      changeset = User.profile_changeset(%User{}, %{brand_color: "#zz5722"})
      refute changeset.valid?
    end
  end
end
