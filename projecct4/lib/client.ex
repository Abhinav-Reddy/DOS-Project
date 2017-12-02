defmodule TEST do


    def userFunctions(server, timeLine, allUsers, userName) do
        timeLine = receive do
            {:login} -> TWITTER.login(server, {userName, self(), self()})
                        TWITTER.subscribedTweets(server, {userName, self()})
                        timeLine
            {:logout} -> TWITTER.logout(server, {userName, self()})
                         timeLine
            {:follow, user} -> 
                #IO.inspect(user<>" following "<>userName)
                TWITTER.follow(server, {user, userName, self()})
                timeLine
            {:success, info} -> #IO.inspect(info)
                timeLine
            {:failed, info} -> #IO.inspect(info)
                timeLine
            {:tweet} -> TWITTER.tweet(server, {userName, 
                                                to_string(:os.system_time(:millisecond)), self()})
                timeLine
            {:tweet, :mention, user} -> TWITTER.tweet(server, {userName, 
                                            to_string(:os.system_time(:millisecond)) <> " @" <> user, self()})
                timeLine
            {:tweet, :tag, tag} -> TWITTER.tweet(server, {userName, 
                                            to_string(:os.system_time(:millisecond)) <> " #" <> tag, self()})
                timeLine        
            {:myMention} -> TWITTER.mentions(server, {userName, self()})
                timeLine
            {:myMention, tweets} -> 
                #IO.puts("My mentions "<> userName)
                #IO.inspect(tweets)
                timeLine
            {:gettweetsWithTag, tag} -> TWITTER.taggedTweets(server, {tag, self()})
                timeLine
            {:tweetsWithTag, tweets} ->
                #IO.puts("Tweets with tag " <> userName ) 
                #IO.inspect(tweets)
                timeLine
            {:getsubscribedTweets} -> TWITTER.subscribedTweets(server, {userName, self()})
                timeLine
            {:subscribedTweets, tweets} -> 
                #IO.puts("Subscribed Tweets " <> userName)
                #IO.inspect(tweets)
                if (tweets != nil) do
                    tweets
                else
                    timeLine
                end
            {:timeLine, tweet} ->
                #IO.puts("Timeline update " <> userName)
                #IO.inspect(tweet) 
                [tweet | timeLine]
            {:retweet} ->
                len = length(timeLine)
                if (len > 0) do
                    len = :rand.uniform(len) - 1
                    {_, tweet} = Enum.at(timeLine, len)
                    TWITTER.retweet(server, {userName, tweet, self()}) 
                end
                timeLine
        end
        userFunctions(server, timeLine, allUsers, userName)
    end

    def registerUsers(_, users, readerPids, _) when users == [] do
        readerPids
    end

    def registerUsers(server, users, readerPids, allUsers) do
        [userName | tl] = users
        TWITTER.register(server, {userName, self()})
        receive do
            {_, tweets} -> #IO.inspect(tweets)
        end
        timeLine = []
        readerPid = spawn(TEST, :userFunctions, [server, timeLine, allUsers, userName])
        registerUsers(server ,tl, [readerPid | readerPids], allUsers)
    end


    def loginUsers(_, _, readerPids) when readerPids == [] do

    end
    
    def loginUsers(server ,allUsers, readerPids) do
        [hdPid | tlPids] = readerPids
        send(hdPid, {:login})
        loginUsers(server, allUsers, tlPids)
    end


    def getRandomName(len, res, _) when len == 0 do
        res
    end

    def getRandomName(len, res, chars) do
        getRandomName(len-1, res<>String.at(chars, :rand.uniform(52)-1), chars)
    end

    def getRandomNames(numUsers, res, _) when numUsers == 0 do
        res
    end

    def getRandomNames(numUsers, res, chars) do
        len = 4+:rand.uniform(5)
        getRandomNames(numUsers-1, [getRandomName(len, "", chars) | res], chars)
    end


    def sendFollowRequests(_, follwers, _) when follwers == [] do
        
    end

    def sendFollowRequests(user, follwers, userFuncPid) do
        [hd | tl] = follwers
        send(userFuncPid, {:follow, hd})
        sendFollowRequests(user, tl, userFuncPid)
    end

    def getRandomUsers(_, _, cnt, res, _) when cnt <= 0 do
        res
    end

    def getRandomUsers(user, allUsers, cnt, res, len) do
        nextUser = Enum.at(allUsers, :rand.uniform(len)-1)
        if (nextUser == user) do
            getRandomUsers(user, allUsers, cnt, res, len)
        else
            getRandomUsers(user, allUsers, cnt-1, [nextUser | res], len)
        end
    end

    def addFollowers(remUsers, _, _, _, _) when remUsers == [] do
        
    end

    def addFollowers(remUsers, allUsers, count, factor, readerPids) do
        [hd | tl] = remUsers
        [hdPid | tlPids] = readerPids
        tmpCnt = if (count/factor > 5) do
                    count/factor
                 else
                    min(count, 5)
                 end
        randUsers = getRandomUsers(hd, allUsers, tmpCnt, [], length(allUsers))
        sendFollowRequests(hd, randUsers, hdPid)
        addFollowers(tl, allUsers, count, factor+1, tlPids)
    end

    def startWorker(pid, userNames, randTags, waitTime) do
        #IO.inspect(waitTime)
        :timer.sleep(waitTime)
        action = :rand.uniform(90)
        if (action <= 15) do
            tweetAction = :rand.uniform(3)
            if (tweetAction == 1) do
                send(pid, {:tweet})
            else if (tweetAction == 2) do
                send(pid, {:tweet, :mention, Enum.at(userNames, :rand.uniform(length(userNames)-1))})
            else
                send(pid, {:tweet, :tag, Enum.at(randTags, :rand.uniform(length(randTags)-1))})
            end
            end
        else if (action <= 30) do
                send(pid, {:retweet})
        else if (action <= 45) do
                send(pid, {:getsubscribedTweets})
        else if (action <= 60) do
                send(pid, {:myMention})
        else if (action <= 75) do
                send(pid, {:gettweetsWithTag, Enum.at(randTags, :rand.uniform(length(randTags)-1))})
        else if (action <= 83) do
                send(pid, {:logout})
        else
            send(pid, {:login})
        end
        end
        end
        end
        end
        end
        startWorker(pid, userNames, randTags, waitTime)
    end

    def createWorkGenerators(readerPids, _, _, _) when readerPids == [] do
        
    end

    def createWorkGenerators(readerPids, userNames, randTags, count) do
        [hd | tl] = readerPids
        #waitTime = round(Float.ceil(count/50)*200)
        waitTime = 500
        # waitTime = if (waitTime > 250) do
        #                 250
        #             else
        #                 waitTime
        #             end
        spawn(TEST, :startWorker, [hd, userNames, randTags, waitTime])
        createWorkGenerators(tl, userNames, randTags, count+1)
    end

    def startClients(numUsers) do
        {:ok, server} = TWITTER.start_link([])
        userNames = getRandomNames(numUsers, [], "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
        randTags = getRandomNames(numUsers, [], "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
        readerPids = registerUsers(server, userNames, [], userNames)
        readerPids = Enum.reverse(readerPids)
        :timer.sleep(2000)
        loginUsers(server, userNames, readerPids)
        :timer.sleep(2000)
        addFollowers(userNames, userNames, 7*length(userNames)/100+1, 1, readerPids)
        :timer.sleep(2000)
        createWorkGenerators(readerPids, userNames, randTags, 1)
    end

    def test(numUsers) do
      {:ok, server} = TWITTER.start_link([])
      userNames = getRandomNames(numUsers, [], "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
      randTags = getRandomNames(numUsers, [], "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
      readerPids = registerUsers(server, userNames, [], userNames)
      readerPids = Enum.reverse(readerPids)
      :timer.sleep(100)
      loginUsers(server, userNames, readerPids)
      :timer.sleep(100)
      addFollowers(userNames, userNames, length(userNames)/2+1, 1, readerPids)
      :timer.sleep(100)
      
      IO.puts(TWITTER.getLoad(server))
      :timer.sleep(100)
      
      send(Enum.at(readerPids, 0), {:tweet})
      :timer.sleep(100)
      send(Enum.at(readerPids, 0), {:tweet, :mention, Enum.at(userNames, 1)})
      :timer.sleep(100)
      send(Enum.at(readerPids, 0), {:tweet, :tag, Enum.at(randTags, 0)})
      :timer.sleep(100)
      send(Enum.at(readerPids, 0), {:tweet, :mention, Enum.at(userNames, 1)})
      :timer.sleep(100)
      send(Enum.at(readerPids, 0), {:gettweetsWithTag, Enum.at(randTags, 0)})
      :timer.sleep(100)
      send(Enum.at(readerPids, 1), {:myMention})
      :timer.sleep(100)
      send(Enum.at(readerPids, 1), {:tweet})
      :timer.sleep(100)
      send(Enum.at(readerPids, 1), {:logout})
      :timer.sleep(100)
      send(Enum.at(readerPids, 0), {:tweet})
      :timer.sleep(100)
      IO.puts(TWITTER.getLoad(server))
      :timer.sleep(100)
      send(Enum.at(readerPids, 1), {:login})
      :timer.sleep(100)
      send(Enum.at(readerPids, 1), {:getsubscribedTweets})
      :timer.sleep(100)
      send(Enum.at(readerPids, 0), {:tweet})
      :timer.sleep(100)
      send(Enum.at(readerPids, 1), {:retweet})
      :timer.sleep(100)
      send(Enum.at(readerPids, 2), {:tweet})
      :timer.sleep(100)
      send(Enum.at(readerPids, 0), {:getsubscribedTweets})
      :timer.sleep(100)
      IO.puts(TWITTER.getLoad(server))
    end
    
  end