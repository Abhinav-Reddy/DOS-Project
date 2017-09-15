
defmodule Actor do
  use GenServer
    
  def hash_code_match(check_str, zero_count, client) do
    zero_String = String.duplicate("0", zero_count)
    hash =  Base.encode16(:crypto.hash(:sha256, check_str))
    val = String.starts_with? hash, zero_String
    
    if (val == :true) do
      #IO.puts val
      #IO.puts check_str
      #IO.puts hash
      send(client, {val, check_str, hash, self()})
    end
  end

  def gen_strings(str, k, cur, zero_count, client) when k == 0 do
    hash_code_match(str, zero_count, client)
  end

  def gen_strings(str, k, cur, zero_count, client) when (cur > 125) do
      
  end

  def gen_strings(str, k, cur, zero_count, client) do
      gen_strings(str <> <<cur::utf8>>, k-1, 33, zero_count, client)
      gen_strings(str, k, cur+1, zero_count, client)
  end
  
  def handle_cast({:process, client, str, k, zero_count}, state) do
    IO.puts k
    gen_strings(str, k, 33, zero_count, client)
    send(client, {:done, self()})
    {:noreply, []}
  end

  def findKeys(pid, {:process, client, str, k, zero_count}) do
    GenServer.cast(pid, {:process, client, str, k, zero_count})
  end
  
  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

end


defmodule LoadDistributor do
  
  def listen(k) do
    receive do
      {:true, res, hash, pid} -> 
        IO.puts "yes"
        IO.puts res
        IO.puts hash
        listen(k)
      {:done, pid} ->
        Actor.findKeys(pid, {:process, self(), "abhinavpodduturi:", k, 4});
        listen(k+1)
    end
  end

  def start() do
    {:ok, pidOne} = Actor.start_link()
    {:ok, pidTwo} = Actor.start_link()
    {:ok, pidThree} = Actor.start_link()
    {:ok, pidFour} = Actor.start_link()
    Actor.findKeys(pidOne, {:process, self(), "abhinavpodduturi:", 1, 4})
    Actor.findKeys(pidTwo, {:process, self(), "abhinavpodduturi:", 2, 4})
    Actor.findKeys(pidThree, {:process, self(), "abhinavpodduturi:", 3, 4})
    Actor.findKeys(pidFour, {:process, self(), "abhinavpodduturi:", 4, 4})
    {:ok, pidFive} = Actor.start_link()
    {:ok, pidSix} = Actor.start_link()
    {:ok, pidSeven} = Actor.start_link()
    {:ok, pidEight} = Actor.start_link()
    Actor.findKeys(pidFive, {:process, self(), "abhinavpodduturi:", 5, 4})
    Actor.findKeys(pidSix, {:process, self(), "abhinavpodduturi:", 6, 4})
    Actor.findKeys(pidSeven, {:process, self(), "abhinavpodduturi:", 7, 4})
    Actor.findKeys(pidEight, {:process, self(), "abhinavpodduturi:", 8, 4})
    listen(9)
  end

  
end