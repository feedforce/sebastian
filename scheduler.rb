# -*- coding: utf-8 -*-

require File.expand_path('./settings', File.dirname(__FILE__))
require File.expand_path('./slack_bot', File.dirname(__FILE__))
require File.expand_path('./cybozu6', File.dirname(__FILE__))

target = ARGV.shift
return unless target

target_settings = Settings.targets.symbolize_keys[target.to_sym]

bot_class = eval(target_settings[:bot_name])
users = target_settings[:users]

now = Time.now
#now = Time.new(2014, 1, 31, 11, 28)
#now = Time.new(2013, 8, 13, 13, 58)
#now = Time.new(2013, 10, 4, 18, 58)
#now = Time.new(2014, 10, 27, 15, 58)

scheduler = Cybozu6::Scheduler.new(Settings.cybozu.symbolize_keys, users, now)
scheduler.open

# 祝日と思われるなら実行しない
exit if scheduler.holiday?

# 最終出社日は多分通常業務ないと思うので何も言わない
exit if scheduler.last_of_year?

# 伝えるべきスケジュールが見つからなければ何も言わずに終了
schedule_list = scheduler.get_schedule
sebastian_list = scheduler.get_sebastian_schedule

exit if schedule_list.size == 0 && sebastian_list.size == 0

messages = []

if schedule_list.size > 0
  messages << Settings.messages.scheduler.header.shuffle.first

  messages += schedule_list.map do |s|
    user_names = s.user_names.map{|n| "#{target_settings[:user_prefix]}#{n}#{target_settings[:user_suffix]}" }.join("、")
    Settings.messages.scheduler.message % [ user_names, s.start_time_to_s, s.title ]
  end
end

if sebastian_list.size > 0
  messages << Settings.messages.scheduler.sebastian_header.shuffle.first

  messages += sebastian_list.map do |s|
    Settings.messages.scheduler.sebastian_message % [ s.start_time_to_s, s.title ]
  end
end

messages << Settings.messages.scheduler.footer.shuffle.first

#puts messages
#exit 1

client = bot_class::Client.new(target_settings)
client.message(messages, notify: 1)

exit
