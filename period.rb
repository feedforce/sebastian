# -*- coding: utf-8 -*-

require File.expand_path('./settings', File.dirname(__FILE__))
#require File.expand_path('./irc_bot', File.dirname(__FILE__))
require File.expand_path('./cybozu', File.dirname(__FILE__))

now = Time.now
cybozu = Cybozu::Client.new(Settings.cybozu.symbolize_keys, now)

# 祝日と思われるなら実行しない
unless cybozu.holiday?
  messages = []

  messages << Settings.messages.period.header.shuffle.first

  Settings.messages.period.middle.each do |m|
    messages << m.messages.shuffle.first if rand(100) < m.probability
  end

  if now.friday?
    messages << Settings.messages.period.friday.shuffle.first
  end

  messages << Settings.messages.period.footer.shuffle.first

  messages = messages.compact

  #puts messages

  client = IrcBot::Client.new(Settings.irc.symbolize_keys)
  client.message(messages)
end
