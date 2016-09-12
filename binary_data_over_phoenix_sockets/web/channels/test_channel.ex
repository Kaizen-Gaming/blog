defmodule BinaryDataOverPhoenixSockets.TestChannel do
  use BinaryDataOverPhoenixSockets.Web, :channel

  def join("test:lobby", payload, socket) do
    if authorized?(payload) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def handle_in("small", _payload, socket) do
    push socket, "small_reply", %{"small response that will only be msgpacked" => true}
    {:noreply, socket}
  end

  def handle_in("large", _payload, socket) do
    push socket, "large_reply", %{"large response that will be msgpacked+gzipped" =>  1..1000 |> Enum.map(fn _ -> 1000 end) |> Enum.into([])}
    {:noreply, socket}
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (test:lobby).
  def handle_in("shout", payload, socket) do
    broadcast socket, "shout", payload
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
end
