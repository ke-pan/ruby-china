require 'rails_helper'
require 'delorean'
include Redis::Objects

describe HotTopic do

  describe "#daily_hot_topics" do
    let(:topic1) {FactoryGirl.create(:topic)}
    let(:topic2) {FactoryGirl.create(:topic)}

    before do
      redis.flushall
    end

    after do
      Delorean.back_to_the_present
    end

    it "should return right hot topics" do
      topic1.hit
      topic2.replied
      topic2.hit
      topic2.hit
      expect(HotTopic.new.daily_hot_topics).to eq [topic2, topic1]
      expect(HotTopic.new.weekly_hot_topics).to eq [topic2, topic1]
      redis.del('daily_hot_topics')
      redis.del('weekly_hot_topics')

      Delorean.jump 1.hour
      topic1.hit
      topic1.replied
      expect(HotTopic.new.daily_hot_topics).to eq [topic1, topic2]
      redis.del('daily_hot_topics')

      Delorean.jump (23.hour + 1.minute)
      expect(HotTopic.new.daily_hot_topics).to eq [topic1]
      expect(HotTopic.new.weekly_hot_topics).to eq [topic1, topic2]
      redis.del('daily_hot_topics')
      redis.del('weekly_hot_topics')

      topic1.hit
      topic1.hit
      topic2.replied
      topic2.hit
      expect(HotTopic.new.weekly_hot_topics).to eq [topic2, topic1]
      redis.del('weekly_hot_topics')

      Delorean.jump (24.hour)
      topic1.hit
      topic1.replied
      topic2.hit
      topic2.hit
      expect(HotTopic.new.weekly_hot_topics).to eq [topic1, topic2]
      redis.del('weekly_hot_topics')

      Delorean.jump (24.hour)
      topic2.hit
      expect(HotTopic.new.weekly_hot_topics).to eq [topic2, topic1]
      redis.del('weekly_hot_topics')

      Delorean.jump (24.hour)
      expect(HotTopic.new.weekly_hot_topics).to eq [topic2, topic1]
      redis.del('weekly_hot_topics')

      Delorean.jump (5.days)
      expect(HotTopic.new.weekly_hot_topics).to eq [topic2]
      redis.del('weekly_hot_topics')
    end
  end
end
