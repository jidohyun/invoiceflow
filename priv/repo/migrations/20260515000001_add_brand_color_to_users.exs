defmodule AutoMyInvoice.Repo.Migrations.AddBrandColorToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :brand_color, :string
    end
  end
end
