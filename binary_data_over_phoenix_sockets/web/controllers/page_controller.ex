defmodule BinaryDataOverPhoenixSockets.PageController do
  use BinaryDataOverPhoenixSockets.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
