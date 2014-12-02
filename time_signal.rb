# -*- coding: utf-8 -*-

require File.expand_path('./settings', File.dirname(__FILE__))
require File.expand_path('./slack_bot', File.dirname(__FILE__))
require File.expand_path('./cybozu6', File.dirname(__FILE__))
require File.expand_path('./tokyo_dome', File.dirname(__FILE__))

target = ARGV.shift
return unless target

target_settings = Settings.targets.symbolize_keys[target.to_sym]

bot_class = eval(target_settings[:bot_name])

name = ARGV.shift
exit unless name

now = Time.now
#now = Time.new(2014, 1, 31, 11, 30)

scheduler = Cybozu6::Scheduler.new(Settings.cybozu.symbolize_keys, [], now)
# scheduler.open

# 祝日と思われるなら実行しない
exit if scheduler.holiday?

# 最終出社日は多分通常業務ないと思うので何も言わない
exit if scheduler.last_of_year?

message_settings = Settings.messages.symbolize_keys[name.to_sym]
messages = []

messages << message_settings[:header].shuffle.first rescue nil

message_settings[:middle].each do |m|
  begin
    messages << m[:messages].shuffle.first if rand(100) < m[:probability]
  rescue
  end
end

if name == 'before_period'
  tokyodome = TokyoDomeSchedule.today(now)
  if tokyodome
    if /休演/ === tokyodome[1]
      messages << message_settings[:tokyodome][:close_message] % tokyodome[1]
    else
      messages << message_settings[:tokyodome][:message] % tokyodome
    end
  end

  cityhall = CityHallSchedule.today(now)
  if cityhall
    messages << message_settings[:cityhall][:message] % cityhall
  end
end

if now.friday?
  last_message ||= message_settings[:friday].shuffle.first rescue nil
end

last_message ||= message_settings[:footer].shuffle.first rescue nil
messages << last_message

messages = messages.compact

exit if messages.size == 0

#puts messages
#exit 1

client = bot_class::Client.new(target_settings)
client.message(messages, notify: 1)

exit
