defmodule InvoiceFlowWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use InvoiceFlowWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :current_user, :any, default: nil, doc: "the current user"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <%!-- Sidebar (desktop: always visible, mobile: hidden) --%>
    <aside class="fixed inset-y-0 left-0 w-64 bg-base-100 border-r border-base-300 z-40 hidden lg:flex lg:flex-col">
      <%!-- Logo --%>
      <div class="p-6">
        <a href="/" class="text-2xl font-display font-bold flex items-center gap-2 text-primary">
          <span class="material-icons">receipt_long</span>
          InvoiceFlow
        </a>
      </div>

      <%!-- Navigation --%>
      <nav class="flex-1 mt-2 px-4 space-y-1">
        <.sidebar_nav_item href="/" icon="dashboard" label="Dashboard" />
        <.sidebar_nav_item href="/invoices" icon="description" label="Invoices" />
        <.sidebar_nav_item href="/clients" icon="people" label="Clients" />
        <.sidebar_nav_item href="/upload" icon="cloud_upload" label="Upload" />
      </nav>

      <%!-- Bottom section --%>
      <div class="border-t border-base-300 p-4 space-y-2">
        <.sidebar_nav_item href="/settings" icon="settings" label="Settings" />

        <%= if @current_user do %>
          <div class="flex items-center gap-3 px-4 py-2 mt-2">
            <div class="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
              <span class="text-xs font-bold text-primary">
                <%= String.first(@current_user.email) |> String.upcase() %>
              </span>
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium truncate"><%= @current_user.email %></p>
              <span class={"text-xs #{plan_text_class(@current_user.plan)}"}>
                <%= String.capitalize(@current_user.plan || "free") %>
              </span>
            </div>
          </div>
          <.link
            href={~p"/users/log_out"}
            method="delete"
            class="flex items-center gap-3 px-4 py-2 text-sm rounded-lg text-base-content/60 hover:text-base-content hover:bg-base-200 transition-colors w-full"
          >
            <span class="material-icons text-xl">logout</span>
            Log out
          </.link>
        <% end %>

        <div class="flex justify-center pt-2">
          <.theme_toggle />
        </div>
      </div>
    </aside>

    <%!-- Mobile top bar --%>
    <header class="sticky top-0 z-30 bg-base-100 border-b border-base-300 lg:hidden">
      <div class="flex items-center justify-between px-4 py-3">
        <div class="flex items-center gap-3">
          <button onclick="document.getElementById('mobile-sidebar').classList.toggle('hidden')" class="btn btn-ghost btn-sm btn-square">
            <span class="material-icons">menu</span>
          </button>
          <span class="text-lg font-display font-bold text-primary">InvoiceFlow</span>
        </div>
        <.theme_toggle />
      </div>
    </header>

    <%!-- Mobile sidebar overlay --%>
    <div id="mobile-sidebar" class="fixed inset-0 z-50 hidden lg:hidden">
      <div
        class="absolute inset-0 bg-black/50"
        onclick="document.getElementById('mobile-sidebar').classList.add('hidden')"
      >
      </div>
      <aside class="relative w-64 h-full bg-base-100 flex flex-col shadow-xl overflow-y-auto">
        <div class="p-6 flex items-center justify-between">
          <a href="/" class="text-2xl font-display font-bold flex items-center gap-2 text-primary">
            <span class="material-icons">receipt_long</span>
            InvoiceFlow
          </a>
          <button
            onclick="document.getElementById('mobile-sidebar').classList.add('hidden')"
            class="btn btn-ghost btn-sm btn-square"
          >
            <span class="material-icons">close</span>
          </button>
        </div>
        <nav class="flex-1 mt-2 px-4 space-y-1">
          <.sidebar_nav_item href="/" icon="dashboard" label="Dashboard" />
          <.sidebar_nav_item href="/invoices" icon="description" label="Invoices" />
          <.sidebar_nav_item href="/clients" icon="people" label="Clients" />
          <.sidebar_nav_item href="/upload" icon="cloud_upload" label="Upload" />
        </nav>
        <div class="border-t border-base-300 p-4">
          <.sidebar_nav_item href="/settings" icon="settings" label="Settings" />
        </div>
      </aside>
    </div>

    <%!-- Main Content --%>
    <main class="min-h-screen bg-base-200 lg:pl-64">
      <div class="p-6 md:p-10 max-w-7xl mx-auto">
        {@inner_content}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true

  defp sidebar_nav_item(assigns) do
    ~H"""
    <a
      href={@href}
      class="flex items-center gap-3 px-4 py-3 rounded-lg font-medium text-base-content/70 hover:bg-primary/10 hover:text-primary transition-colors"
    >
      <span class="material-icons text-xl">{@icon}</span>
      {@label}
    </a>
    """
  end

  defp plan_text_class("free"), do: "text-base-content/40"
  defp plan_text_class("starter"), do: "text-primary"
  defp plan_text_class("pro"), do: "text-accent"
  defp plan_text_class(_), do: "text-base-content/40"

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
