defmodule Twitter2Web.PageController do
  use Twitter2Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
