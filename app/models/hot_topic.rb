class HotTopic
  include Redis::Objects

  def daily_hot_topics
    # 利用 expiration 实现定时刷新
    update_daily_hot_topics unless redis.exists("daily_hot_topics")
    sorted_topics(redis.zrevrange("daily_hot_topics", 0, 99))
  end

  def weekly_hot_topics
    update_weekly_hot_topics unless redis.exists("weekly_hot_topics")
    sorted_topics(redis.zrevrange("weekly_hot_topics", 0, 99))
  end

  private

  def sorted_topics(array)
    # mongo 不能按给定 id 顺序返回 document，需要在这里排序
    topics = Topic.find array
    lookup = {}
    array.each_with_index {|v, i| lookup[v.to_i] = i}
    topics.sort_by {|topic| lookup[topic._id]}
  end

  def update_daily_hot_topics
    #找出 24 小时内活跃帖子
    recent_hit_topics = redis.zrangebyscore('recent_hits', ago(24, 'hours'), now)
    #每个帖子按照回贴，点击算分
    recent_hit_topics.each do |topic|
      score = 0
      redis.hgetall(topic + ':hhits').each do |timestamp, count|
        score += cal_daily_score(timestamp.to_i, count.to_i)
      end
      redis.hgetall(topic + ':hreplies').each do |timestamp, count|
        score += 3*cal_daily_score(timestamp.to_i, count.to_i)
      end
      #按照分数排序
      redis.zadd("daily_hot_topics", score, topic.split(':')[1])
    end
    #设置 expiration，每 10 分钟刷新
    redis.expire('daily_hot_topics', 600)
  end

  def update_weekly_hot_topics
    #删除 7 天内不活跃的帖子
    redis.zremrangebyscore('recent_hits', '-inf', ago(7, 'days'))
    #找出 7 天内活跃的帖子
    recent_hit_topics = redis.zrange('recent_hits', 0, -1)

    #删除 7 天外的回复、点击
    recent_hit_topics.each do |topic|
      [':hhits', ':hreplies'].each do |e|
        key = topic + e
        del_keys = redis.hkeys(key).select {|el| el.to_i < ago(7, 'days')}
        if del_keys.length > 0
          redis.hdel(key, del_keys)
        end
      end

      #每个帖子按照回贴，点击算分
      score = 0
      redis.hgetall(topic + ':hhits').each do |timestamp, count|
        score += cal_weekly_score(timestamp.to_i, count.to_i)
      end
      redis.hgetall(topic + ':hreplies').each do |timestamp, count|
        score += 3*cal_weekly_score(timestamp.to_i, count.to_i)
      end
      #按照分数排序
      redis.zadd("weekly_hot_topics", score, topic.split(':')[1])
    end

    #设置 expiration，每小时刷新
    redis.expire('weekly_hot_topics', 3600)
  end

  def ago(num, time)
    now - num.send(time)
  end

  def now
    #设置 cache，确保每次时间一致
    @now ||= Time.now.beginning_of_minute.to_i
  end

  def cal_daily_score(timestamp, count)
    timegap = (now - timestamp) / 3600
    if timegap < 24
      (24 - timegap) * count
    else
      0
    end
  end

  def cal_weekly_score(timestamp, count)
    (7 - (now - timestamp) / 86400) * count
  end

end
