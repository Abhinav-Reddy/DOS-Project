defmodule TWITTERTest do
  use ExUnit.Case
  doctest TWITTER

  test "greets the world" do
    assert TWITTER.hello() == :world
  end
end
