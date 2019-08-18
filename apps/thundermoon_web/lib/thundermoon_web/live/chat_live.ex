defmodule ThundermoonWeb.ChatLive do
  use Phoenix.LiveView

  alias Thundermoon.Repo
  alias Thundermoon.Accounts.User

  alias ThundermoonWeb.Endpoint
  alias ThundermoonWeb.ChatView
  alias ThundermoonWeb.Presence
  alias ThundermoonWeb.ChatMessages

  def mount(session, socket) do
    user = Repo.get!(User, session[:current_user_id])
    if connected?(socket), do: subscribe(user)
    messages = ChatMessages.list()
    users = extract_users(Presence.list("chat"))
    {:ok, assign(socket, %{current_user: user, messages: messages, users: users})}
  end

  def render(assigns) do
    ChatView.render("index.html", assigns)
  end

  # this is triggered by the live_view event phx-submit
  def handle_event("send", %{"message" => %{"text" => text}}, socket) do
    username = socket.assigns.current_user.username
    message = %{user: username, text: text}
    ChatMessages.add(message)
    Endpoint.broadcast("chat", "send", message)
    {:noreply, socket}
  end

  # this is triggered by the pubsub broadcast event
  def handle_info(%{event: "send", payload: message}, socket) do
    messages = [message | socket.assigns.messages]
    {:noreply, assign(socket, %{messages: messages})}
  end

  def handle_info(
        %{
          event: "presence_diff",
          topic: "chat",
          payload: _payload
        },
        socket
      ) do
    users = extract_users(Presence.list("chat"))

    {:noreply, assign(socket, %{users: users})}
  end

  defp subscribe(user) do
    Endpoint.subscribe("chat")
    Presence.track(self(), "chat", user.id, %{user: user})
  end

  defp extract_users(list) do
    list
    |> Map.values()
    |> Enum.map(&Map.get(&1, :metas))
    |> Enum.map(&List.first(&1))
    |> Enum.map(&Map.get(&1, :user))
  end
end