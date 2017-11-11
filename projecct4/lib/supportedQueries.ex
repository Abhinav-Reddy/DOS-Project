
defmodule MYMENTION do
    use GenServer
    def start_link(opts) do
        GenServer.start_link(__MODULE__, :ok, opts)
    end

    def init(:ok) do
        {:ok, %{}}
    end
end


defmodule SUBSCRIBEDTWEETS do
    use GenServer
    def start_link(opts) do
        GenServer.start_link(__MODULE__, :ok, opts)
    end

    def init(:ok) do
        {:ok, %{}}
    end
end


defmodule TWEETSWITHTAG do
    use GenServer
    def start_link(opts) do
        GenServer.start_link(__MODULE__, :ok, opts)
    end

    def init(:ok) do
        {:ok, %{}}
    end
end