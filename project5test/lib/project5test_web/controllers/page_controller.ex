defmodule Project5testWeb.PageController do
  use Project5testWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
