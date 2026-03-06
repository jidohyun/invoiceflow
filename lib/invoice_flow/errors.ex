defmodule InvoiceFlow.Errors do
  defmodule NotFound do
    defexception [:message, :resource, :id]

    @impl true
    def message(%{resource: resource, id: id}) do
      "#{resource} not found: #{id}"
    end
  end

  defmodule Unauthorized do
    defexception [:message]
  end

  defmodule ValidationError do
    defexception [:message, :changeset]
  end
end
