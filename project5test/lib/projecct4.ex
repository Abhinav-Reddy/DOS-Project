
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
  
    def startLoadManager(server, prevTime) do
      :timer.sleep(950)
      count = TWITTER.getLoad(server)
      curTime = :os.system_time(:millisecond)
      prevTime = (curTime - prevTime)/1000
      IO.puts(round(Float.ceil(count/prevTime)))
      startLoadManager(server, curTime)
    end

    def start_link(_) do
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
      spawn(TWITTER ,:startLoadManager, [self(), :os.system_time(:millisecond)])
      servers = createServers(68, %{})
      {:ok, pid} = SERVER.start_link([])
      {:ok, {%{}, %{}, Map.put(servers, :tags, pid), 0, 0}}
    end

    def register(server, {userName}) do
      GenServer.cast(server, {"register", userName})
    end
  
    def login(server, {userName}) do
      GenServer.cast(server, {"login", userName})
    end
  
    def logout(server, {userName}) do
      GenServer.cast(server, {"logout", userName})
    end

    def follow(server, {userName, follow}) do
      GenServer.cast(server, {"follow", userName, follow})
    end

    def tweet(server, {userName, tweet}) do
      GenServer.cast(server, {"tweet", userName, tweet})
    end

    def retweet(server, {userName, tweet}) do
      GenServer.cast(server, {"retweet", userName, tweet})
    end

    def mentions(server, {userName}) do
      GenServer.cast(server, {"myMention", userName})
    end

    def taggedTweets(server, {tag, userName}) do
      GenServer.cast(server, {"tweetsWithTag", tag, userName})
    end

    def subscribedTweets(server, {userName}) do
      GenServer.cast(server, {"subscribedTweets", userName})
    end

    def getLoad(server) do
      GenServer.call(server, {:load})
    end


    def handle_cast({"register", userName}, 
                    {connections, tweetids, servers, tweetcnt, loadcnt}) do
      key = HELPER.getKey(userName)
      SERVER.register(Map.get(servers, key), {userName})
      {:noreply, {connections, tweetids, servers, tweetcnt, loadcnt+1}}
    end
  
    def handle_cast({"login", userName}, 
                    {connections, tweetids, servers, tweetcnt, loadcnt}) do
      key = HELPER.getKey(userName)
      SERVER.login(Map.get(servers, key), {userName})
      {:noreply, {connections, tweetids, servers, tweetcnt, loadcnt+1}}
    end
  
    def handle_cast({"logout", userName}, 
                    {connections, tweetids, servers, tweetcnt, loadcnt}) do
      key = HELPER.getKey(userName)
      SERVER.logout(Map.get(servers, key), {userName})
      {:noreply, {connections, tweetids, servers, tweetcnt, loadcnt+1}}
    end

    def handle_cast({"follow", userName, follow}, 
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

    def handle_cast({"tweet", userName, tweet}, 
                    {connections, tweetids, servers, tweetcnt, loadcnt}) do
      tweetids = Map.put(tweetids, tweet, tweetcnt)
      # spawn(HELPER, :sendToServers, [Map.get(connections, userName), 
      #                 tweetcnt, servers, userName <> " tweeted", tweet, userName])
      HELPER.sendToServers(Map.get(connections, userName), 
                          tweetcnt, servers, userName <> " tweeted", tweet, userName)
      {:noreply, {connections, tweetids, servers, tweetcnt+1, loadcnt+1}}
    end

    def handle_cast({"retweet", userName, tweet}, 
                    {connections, tweetids, servers, tweetcnt, loadcnt}) do
      tweetid = Map.get(tweetids, tweet)
      # spawn(HELPER, :sendToServers, [Map.get(connections, userName),
      #                 tweetid, servers, userName <> " retweeted", tweet, userName])
      HELPER.sendToServers(Map.get(connections, userName), 
                          tweetid, servers, userName <> " retweeted", tweet, userName)
      {:noreply, {connections, tweetids, servers, tweetcnt, loadcnt+1}}
    end

    def handle_cast({"myMention", userName}, 
                    {connections, tweetids, servers, tweetcnt, loadcnt}) do
      key = HELPER.getKey(userName)
      SERVER.myMention(Map.get(servers, key), {userName})
      {:noreply, {connections, tweetids, servers, tweetcnt, loadcnt+1}}
    end

    def handle_cast({"tweetsWithTag", tag, userName}, 
                    {connections, tweetids, servers, tweetcnt, loadcnt}) do
      SERVER.getTweetsWithTag(Map.get(servers, :tags), {tag, userName})
      {:noreply, {connections, tweetids, servers, tweetcnt, loadcnt+1}}
    end

    def handle_cast({"subscribedTweets", userName}, 
                    {connections, tweetids, servers, tweetcnt, loadcnt}) do
      key = HELPER.getKey(userName)
      SERVER.getSubscribedTweets(Map.get(servers, key), {userName})
      {:noreply, {connections, tweetids, servers, tweetcnt, loadcnt+1}}
    end

    def handle_cast(junk, {connections, tweetids, servers, tweetcnt, loadcnt}) do
      {:noreply, {connections, tweetids, servers, tweetcnt, loadcnt+1}}
    end

    def handle_call({:load}, __from, {connections, tweetids, servers, tweetcnt, loadcnt}) do
      HELPER.pingAllSevers(servers)
      {:reply, loadcnt+1, {connections, tweetids, servers, tweetcnt, 0}}
    end
    

    def startServer() do
      {:ok, _} = TWITTER.start_link([])
    end
end
