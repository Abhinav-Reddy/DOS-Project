
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

  def start(zeroes) do
      {:ok, ipAddList} = :inet.getif()
      ipAddr = "server@" <> getIPAdress(ipAddList)
      Node.start(ipAddr)
      Node.set_cookie("project1")
      spawn(LoadDistributor, :startDistributor, [1, 20, zeroes])
      #Node.connect("server@" <> serverAddr)
  end

  def startDistributor(start, limit, zeroes) do
    
    {:ok, pidOne} = Actor.start_link()
    {:ok, pidTwo} = Actor.start_link()
    {:ok, pidThree} = Actor.start_link()
    {:ok, pidFour} = Actor.start_link()
    
    Actor.findKeys(pidOne, {:process, self(), "abhinavpodduturi:", 1, 4})
    Actor.findKeys(pidTwo, {:process, self(), "abhinavpodduturi:", 2, 4})
    Actor.findKeys(pidThree, {:process, self(), "abhinavpodduturi:", 3, 4})
    Actor.findKeys(pidFour, {:process, self(), "abhinavpodduturi:", 4, 4})
    listen(5)
  end

  def getIPAdress(ipAddList) when ipAddList == [] do
    ""
  end

  def getIPAdress(ipAddList) do
    [head | tail] = ipAddList
    {ip,_,_} = head
    {one, two, three, four} = ip
    if (one == 10 || (one == 192 && two == 168)) do
      Integer.to_string(one) <> "." <> Integer.to_string(two) <> "." 
      <> Integer.to_string(three) <> "." <> Integer.to_string(four)
    else
      getIPAdress(tail)
    end
  end
  
end