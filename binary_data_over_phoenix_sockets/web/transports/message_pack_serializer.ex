defmodule BinaryDataOverPhoenixSockets.Transports.MessagePackSerializer do
  @moduledoc false

  @behaviour Phoenix.Transports.Serializer

  alias Phoenix.Socket.Reply
  alias Phoenix.Socket.Message
  alias Phoenix.Socket.Broadcast

  # only gzip data above 1K
  @gzip_threshold 1024

  def fastlane!(%Broadcast{} = msg) do
    {:socket_push, :binary, pack_data(%{
      topic: msg.topic,
      event: msg.event,
      payload: msg.payload
    })}
  end

  def encode!(%Reply{} = reply) do
    packed = pack_data(%{
      topic: reply.topic,
      event: "phx_reply",
      ref: reply.ref,
      payload: %{status: reply.status, response: reply.payload}
    })
    {:socket_push, :binary, packed}
  end

  def encode!(%Message{} = msg) do
    # We need to convert the Message struct into a plain map for MessagePack to work properly.
    # Alternatively we could have implemented the Enumerable behaviour. Pick your poison :)
    {:socket_push, :binary, pack_data(Map.from_struct msg)}
  end

  # messages received from the clients are still in json format;
  # for our use case clients are mostly passive listeners and made no sense
  # to optimize incoming traffic
  def decode!(message, _opts) do
    message
    |> Poison.decode!()
    |> Phoenix.Socket.Message.from_map!()
  end

  defp pack_data(data) do
    msgpacked = MessagePack.pack!(data, enable_string: true)
    gzip_data(msgpacked, byte_size(msgpacked))
  end

  defp gzip_data(data, size) when size < @gzip_threshold, do: data
  defp gzip_data(data, _size), do: :zlib.gzip(data)
end
