
defmodule HELPER do
  
  def getKey(userName) do
    Enum.at(to_charlist(String.at(userName, 0)), 0)-65
  end

  def createUserMap(users, map) when users == [] do
    map
  end

  def createUserMap(users, map) do
    [hd | tl] = users
    key = getKey(hd)
    list = if Map.has_key?(map, key) do
              Map.get(map, key)
           else
              []
           end
    list = [hd | list]
    createUserMap(tl, Map.put(map, key, list))
  end

  def getTags(words, tags, _) when words==[] do
    tags
  end

  def getTags(words, tags, cmp) do
    [hd | tl] = words
    if (String.at(hd, 0) == cmp) do
      getTags(tl, [String.slice(hd, 1..-1) | tags], cmp)
    else
      getTags(tl, tags, cmp)
    end
  end

  def sendToServers(users, tweetid, servers, action, tweet, userName) do
    map = createUserMap(users, %{})
    Enum.each map, fn{k,v} ->
      SERVER.update(Map.get(servers, k), {v, tweetid, action, tweet})
    end
    if (String.contains?(action, "retweeted") == false) do
      splitList = String.split(tweet, " ")
      tmpList = getTags(splitList, [], "#")
      SERVER.update(Map.get(servers, :tags), {tmpList, tweetid, action, tweet})
      tmpList = getTags(splitList, [], "@")
      tmpMap = createUserMap(tmpList, %{})
      Enum.each tmpMap, fn{k,v} ->
        SERVER.update(Map.get(servers, k), {v, tweetid, userName <> " mentioned you in tweet", tweet})
      end
    end
    
  end

  def pingAllSevers(servers) do
    Enum.each servers, fn{_,v} ->
      SERVER.ping(v)
    end
  end

end

defmodule TWITTER do
  use GenServer
  
    def startLoadManager(server) do
      :timer.sleep(1000)
      IO.puts(TWITTER.getLoad(server))
      startLoadManager(server)
    end

    def start_link(opts) do
      GenServer.start_link(__MODULE__, :ok, name: MyServer)
    end

    def createServers(cnt, servers) when cnt == 0 do
      servers
    end

    def createServers(cnt, servers) do
      {:ok, pid} = SERVER.start_link([])
      createServers(cnt-1, Map.put(servers, cnt-1, pid))
    end

    def init(:ok) do
      spawn(TWITTER ,:startLoadManager, [self()])
      servers = createServers(68, %{})
      {:ok, pid} = SERVER.start_link([])
      {:ok, {%{}, %{}, Map.put(servers, :tags, pid), 0, 0}}
    end

    def register(server, {userName, pid}) do
      GenServer.cast(server, {:register, userName, pid})
    end
  
    def login(server, {userName, pid, updatesPid}) do
      GenServer.cast(server, {:login, userName, pid, updatesPid})
    end
  
    def logout(server, {userName, pid}) do
      GenServer.cast(server, {:logout, userName, pid})
    end

    def follow(server, {userName, follow, pid}) do
      GenServer.cast(server, {:follow, userName, follow, pid})
    end

    def tweet(server, {userName, tweet, pid}) do
      GenServer.cast(server, {:tweet, userName, tweet, pid})
    end

    def retweet(server, {userName, tweet, pid}) do
      GenServer.cast(server, {:retweet, userName, tweet, pid})
    end

    def mentions(server, {userName, pid}) do
      GenServer.cast(server, {:myMention, userName, pid})
    end

    def taggedTweets(server, {tag, pid}) do
      GenServer.cast(server, {:tweetsWithTag, tag, pid})
    end

    def subscribedTweets(server, {userName, pid}) do
      GenServer.cast(server, {:subscribedTweets, userName ,pid})
    end

    def getLoad(server) do
      GenServer.call(server, {:load})
    end


    def handle_cast({:register, userName, pid}, 
                    {connections, tweetids, servers, tweetcnt, loadcnt}) do
      key = HELPER.getKey(userName)
      SERVER.register(Map.get(servers, key), {userName, pid})
      {:noreply, {connections, tweetids, servers, tweetcnt, loadcnt+1}}
    end
  
    def handle_cast({:login, userName, pid, updatesPid}, 
                    {connections, tweetids, servers, tweetcnt, loadcnt}) do
      key = HELPER.getKey(userName)
      SERVER.login(Map.get(servers, key), {userName, pid, updatesPid})
      {:noreply, {connections, tweetids, servers, tweetcnt, loadcnt+1}}
    end
  
    def handle_cast({:logout, userName, pid}, 
                    {connections, tweetids, servers, tweetcnt, loadcnt}) do
      key = HELPER.getKey(userName)
      SERVER.logout(Map.get(servers, key), {userName, pid})
      {:noreply, {connections, tweetids, servers, tweetcnt, loadcnt+1}}
    end

    def handle_cast({:follow, userName, follow, _}, 
                  {connections, tweetids, servers, tweetcnt, loadcnt}) do
      tmpList = if (Map.has_key?(connections, follow)) do
                  Map.get(connections, follow)
                else
                  []
                end
      connections = if (Enum.member?(tmpList, userName)) do
                      connections
                    else
                      Map.put(connections, follow, [userName | tmpList])
                    end
      {:noreply, {connections, tweetids, servers, tweetcnt, loadcnt+1}}
    end

    def handle_cast({:tweet, userName, tweet, _}, 
                    {connections, tweetids, servers, tweetcnt, loadcnt}) do
      tweetids = Map.put(tweetids, tweet, tweetcnt)
      # spawn(HELPER, :sendToServers, [Map.get(connections, userName), 
      #                 tweetcnt, servers, userName <> " tweeted", tweet, userName])
      HELPER.sendToServers(Map.get(connections, userName), 
                          tweetcnt, servers, userName <> " tweeted", tweet, userName)
      {:noreply, {connections, tweetids, servers, tweetcnt+1, loadcnt+1}}
    end

    def handle_cast({:retweet, userName, tweet, _}, 
                    {connections, tweetids, servers, tweetcnt, loadcnt}) do
      tweetid = Map.get(tweetids, tweet)
      # spawn(HELPER, :sendToServers, [Map.get(connections, userName),
      #                 tweetid, servers, userName <> " retweeted", tweet, userName])
      HELPER.sendToServers(Map.get(connections, userName), 
                          tweetid, servers, userName <> " retweeted", tweet, userName)
      {:noreply, {connections, tweetids, servers, tweetcnt, loadcnt+1}}
    end

    def handle_cast({:myMention, userName, pid}, 
                    {connections, tweetids, servers, tweetcnt, loadcnt}) do
      key = HELPER.getKey(userName)
      SERVER.myMention(Map.get(servers, key), {userName, pid})
      {:noreply, {connections, tweetids, servers, tweetcnt, loadcnt+1}}
    end

    def handle_cast({:tweetsWithTag, tag, pid}, 
                    {connections, tweetids, servers, tweetcnt, loadcnt}) do
      SERVER.getTweetsWithTag(Map.get(servers, :tags), {tag, pid})
      {:noreply, {connections, tweetids, servers, tweetcnt, loadcnt+1}}
    end

    def handle_cast({:subscribedTweets, userName, pid}, 
                    {connections, tweetids, servers, tweetcnt, loadcnt}) do
      key = HELPER.getKey(userName)
      SERVER.getSubscribedTweets(Map.get(servers, key), {userName, pid})
      {:noreply, {connections, tweetids, servers, tweetcnt, loadcnt+1}}
    end

    def handle_call({:load}, __from, {connections, tweetids, servers, tweetcnt, loadcnt}) do
      HELPER.pingAllSevers(servers)
      {:reply, loadcnt+1, {connections, tweetids, servers, tweetcnt, 0}}
    end
    
    def loop() do
      :timer.sleep(10)
      loop()
    end
    
    def startServer() do
      {:ok, server} = TWITTER.start_link([])
      serverIpaddr = "server@127.0.0.1"
      Node.start(String.to_atom(serverIpaddr))
      Node.set_cookie(:"project1")
      loop()
    end
end

defmodule Project4 do

  def main([]) do

    HELPER.startServer()
    
  end

end
