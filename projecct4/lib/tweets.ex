defmodule TIMELINE do
  use GenServer
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    {:ok, {%{}, %{}}}
  end

  def update(server {users, tweetid, action, tweet}) do
    GenServer.cast(server, {:updateUsers, users, tweetid, action, tweet})
  end

  def getTimeLine(server {user, pid}) do
    GenServer.cast(server, {:getTimeLine, user, pid})
  end

  def ping(sever) do
    GenServer.call(server, {:ping})
  end

  def updateTimeLines(users, tweetid, action, timeLines) when users == [] do
    timeLines
  end

  def updateTimeLines(users, tweetid, action, timeLines) do
    [hd | tl] = users
    tmpList = if (Map.has_key?(timeLines, hd)) do
                Map.get(timeLines, hd)
              else
                []
    updateTimeLines(tl, tweetid, action, Map.put(timeLines, hd, [{tweetid, action} | tmpList]))
  end

  def getTweets(tweetids, tweets, res) when tweetids == [] do
    res
  end
  
  def getTweets(tweetids, tweets, res) do
    [{tweetid, action} | tl] = tweetids
    getTweets(tl, tweets, [{Map.get(tweets, tweetid), action} | res])
  end

  def handle_cast({:updateUsers, users, tweetid, action, tweet}, {timeLines, tweets}) do
    tweets = Map.put(tweets, tweetid, tweet)
    {:noreply, {updateTimeLines(users, tweetid, action, timeLines), tweets}}
  end

  def handle_cast({:getTimeLine, user, pid}, {timeLines, tweets}) do
    send(pid, getTweets(Map.get(timeLines, user), tweets, []))
    {:noreply, timeLines}
  end

  def handle_call({:ping}, __from, {timeLines,tweets}) do
    {:reply, :ok, {timeLines, tweets}}
  end

end

defmodule TWEETS do
    use GenServer
    def start_link(opts) do
      GenServer.start_link(__MODULE__, :ok, opts)
    end
    
    def createTimeLineServers(cnt, servers) when cnt == 0 do
      
    end

    def createTimeLineServers(cnt, servers) do
      createTimeLineServers(cnt-1, Map.put(servers, cnt-1, TIMELINE.start_link([])))
    end

    def init(:ok) do
      servers = createTimeLineServers(68, %{})
      {:ok, {%{}, %{}, Map.put(servers, :tags, TIMELINE.start_link([])), 0, 0}}
    end

    def createUserMap(users, map) when users == [] do
      map
    end

    def createUserMap(users, map) do
      [hd | tl] = users
      key = Enum.at(to_charlist(String.at(hd, 0)), 0)-48
      list = if Map.has_key?(map, key) do
                Map.get(map, key)
             else
                []
             end
      list = [hd | list]
      createUserMap(tl, Map.put(map, key, list))
    end

    def getTags(words, tags, cmp) when words==[] do
      tags
    end

    def getTags(words, tags, cmp) do
      [hd | tail] = words
      if (String.at(hd, 0) == cmp) do
        getTags(tl, [hd | tags], cmp)
      else
        getTags(tl, tags, cmp)
      end
    end

    def sendToTimeLine(users, tweetid, servers, action, tweet) do
      map = createUserMap(users, %{})
      Enum.each map, fn{k,v} ->
        TIMELINE.update(Map.get(servers, k), {v, tweetid, action, tweet})
      end
      if (String.contains?(action, "retweeted") == false) do
        splitList = String.split(tweet, " ")
        tmpList = getTags(splitList, [], "#")
        TIMELINE.update(Map.get(servers, :tags), {tmpList, tweetid, NULL, tweet})
        tmpList = getTags(splitList, [], "@")
        tmpMap = createUserMap(tmpList, %{})
        Enum.each tmpMap, fn{k,v} ->
          TIMELINE.update(Map.get(servers, k), {v, tweetid, action, tweet})
        end
      end
    end

    def pingAllSevers(servers) do
      Enum.each map, fn{k,v} ->
        TIMELINE.ping(v)
      end
    end

    def tweet(server, {userName, tweet, pid}) do
      GenServer.cast(server, {:tweet, userName, tweet, pid})
    end

    def retweet(server, {userName, tweet, pid}) do
      GenServer.cast(server, {:retweet, userName, tweetid, pid})
    end

    def follow(server, {userName, follow, pid}) do
      GenServer.cast(server, {:follow, userName, follow, pid})
    end

    def readTimeLine(server, {userName, pid}) do
      GenServer.cast(server, {:readTimeLine, userName, pid})
    end

    def getLoad(server) do
      GenServer.call(server, {:load})
    end



    # append @ for followers
    def handle_cast({:follow, userName, follow, pid}, {connections, tweetids, servers, tweetcnt, loadcnt}) do
      tmpList = if (Map.has_key?(connections, "@"<>follow)) do
                  Map.get(connections, "@"<>follow)
                else
                  []
                end
      {:noreply, {Map.put(connections, "@"<>follow, [userName | tmpList]), tweetids, servers, tweetcnt, loadcnt+1}}
    end

    def handle_cast({:tweet, userName, tweet, pid}, {connections, tweetids, servers, tweetcnt, loadcnt}) do
      connections = Map.put(connections, tweet, tweetcnt)
      spawn(TWEETS, :sendToTimeLine, [Map.get(connections, "@"<>userName), 
            tweetcnt, servers, userName <> "tweeted", tweet)]
      {:noreply, {connections, tweetids, servers, tweetcnt+1, loadcnt+1}}
    end

    def handle_cast({:retweet, userName, tweet, pid}, {connections, tweetids, servers, tweetcnt, loadcnt}) do
      tweetid = Map.get(tweetids, tweet)
      spawn(TWEETS, :sendToTimeLine, [Map.
      get(connections, "@"<>userName), 
            tweetid, servers, userName <> "retweeted", tweet)]
      {:noreply, {connections, tweetids, servers, tweetcnt, loadcnt+1}}
    end

    def handle_cast({:readTimeLine, userName, pid}, {connections, tweetids, servers, tweetcnt, loadcnt}) do
      key = Enum.at(to_charlist(String.at(userName, 0)), 0)-48
      timeLinePid = Map.get(servers, key)
      TIMELINE.getTimeLine(timeLinePid, {userName, pid})
      {:noreply, {connections, tweetids, servers, tweetcnt, loadcnt+1}}
    end

    def handle_call({:load}, __from, {connections, tweetids, servers, tweetcnt, loadcnt}) do
      pingAllSevers(servers)
      {:reply, loadcnt, {connections, tweetids, servers, tweetcnt, 0}}
    end

end
