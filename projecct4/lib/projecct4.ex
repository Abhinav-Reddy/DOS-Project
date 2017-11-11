defmodule USERINFO do
  use GenServer
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    {:ok, %{}}
  end

  def register(server, {userName, pid}) do
    GenServer.cast(server, {:register, userName, pid})
  end

  def login(server, {userName, pid, tweetsPid}) do
    GenServer.cast(server, {:login, userName, pid, tweetsPid})
  end

  def logout(server, {userName, pid}) do
    GenServer.cast(server, {:logout, userName, pid})
  end


  def getActiveUsers(server, pid) do
    GenServer.cast(server, {:activeUsers, pid})
  end

  def readTimeLine(userName, tweetsPid, userPid) do
    TWEETS.readTimeLine(tweetsPid, {userName, self()})
    receive do
      {:timeLine, timeLine} ->
        send(userPid, timeLine)
    end
    :timer.sleep(5000)
    readTimeLine(userName, tweetsPid, userPid)
  end

  def handle_cast({:register, userName, pid}, registeredUsers) do
    if Map.has_key?(registeredUsers, userName) do
      send(pid, {:failed, "User name already exists"})
      {:noreply, registeredUsers}
    else
      send(pid, {:success, "Registered successfully"})
      {:noreply, Map.put(registeredUsers, userName, {0, NULL, NULL})}
    end
  end

  def handle_cast({:login, userName, pid, tweetsPid}, registeredUsers) do
    if Map.has_key?(registeredUsers, userName) do
      send(pid, {:failed, "User name doesnt exist"})
      {:noreply, registeredUsers}
    else
      send(pid, {:success, "Login successfull"})
      {:noreply, Map.put(registeredUsers, userName, 
        {1, spawn(USERINFO, :readTimeLine, [userName, tweetsPid, pid]) } ) 
      }
    end
  end

  def handle_cast({:logout, userName, pid}, registeredUsers) do
    if Map.has_key?(registeredUsers, userName) do
      send(pid, {:failed, "User name doesnt exist"})
      {:noreply, registeredUsers}
    else
      send(pid, {:success, "Logout successfull"})
      {_, timeLinePid, _} = Map.get(registeredUsers, userName)
      Process.exit(timeLinePid, :kill)
      {:noreply, Map.put(registeredUsers, userName, {0, NULL, NULL})}
    end
  end

  def handle_cast({:activeUsers, pid}, registeredUsers) do
    send(pid, Enum.map(registeredUsers, fn({x,y}) -> if (y == true) do x end end))
  end

end


defmodule SUBSCRIBE do
  use GenServer
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    {:ok, %{}}
  end
  
end

defmodule TWITTER do
  use GenServer
  
    def start_link(opts) do
      GenServer.start_link(__MODULE__, :ok, opts)
    end

    def init(:ok) do
      services = %{}
      {:ok, pid} = USERINFO.start_link([])
      Map.put(services, :userinfo, pid)
      {:ok, pid} = TWEETS.start_link([])
      Map.put(services, :tweets, pid)
      {:ok, services}
    end

    def register(server, {userName, pid}) do
      GenServer.cast(server, {:register, userName, pid})
    end

    def login(server, {userName, pid}) do
      GenServer.cast(server, {:login, userName, pid})
    end
    
    def logout(server, {userName, pid}) do
      GenServer.cast(server, {:logout, userName, pid})
    end

    def tweet(server, {userName, tweet, pid}) do
      GenServer.cast(server, {:tweet, userName, tweet, pid})
    end

    def retweet(server, {userName, tweet, pid}) do
      GenServer.cast(server, {:retweet, userName, tweet, pid})
    end

    def follow(server, {userName, following, pid}) do
      GenServer.cast(server, {:follow, userName, following, pid})
    end

    def mymention(server, {userName, pid}) do
      GenServer.cast(server, {:follow, userName, pid})
    end

    


    def handle_cast({:register, userName, pid}, services) do
      service = Map.fetch(services, :userinfo)
      USERINFO.register(service, {userName, pid})
      {:noreply, services}
    end

    def handle_cast({:login, userName, pid}, services) do
      service = Map.fetch(services, :userinfo)
      USERINFO.login(service, {userName, pid, Map.get(service, :tweets)})
      {:noreply, services}
    end

    def handle_cast({:logout, userName, pid}, services) do
      service = Map.fetch(services, :userinfo)
      USERINFO.logout(service, {userName, pid})
      {:noreply, services}
    end

    def handle_cast({:tweet, userName, tweet, pid}, services) do
      service = Map.fetch(services, :tweets)
      TWEETS.tweet(service, {userName, tweet, pid})
      {:noreply, services}
    end

    def handle_cast({:retweet, userName, tweet, pid}, services) do
      service = Map.fetch(services, :tweets)
      TWEETS.retweet(service, {userName, tweet, pid})
      {:noreply, services}
    end

    def handle_cast({:follow, userName, following, pid}, services) do
      service = Map.fetch(services, :tweets)
      TWEETS.follow(service, {userName, following, pid})
      {:noreply, services}
    end
  
end


defmodule TEST do
  1
end