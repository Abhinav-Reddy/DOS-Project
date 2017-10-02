defmodule GOSSIPTest do
  use ExUnit.Case
  doctest GOSSIP

  test "greets the world" do
    assert GOSSIP.hello() == :world
  end
end
