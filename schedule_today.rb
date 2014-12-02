# -*- coding: utf-8 -*-

require File.expand_path('./settings', File.dirname(__FILE__))
require File.expand_path('./slack_bot', File.dirname(__FILE__))
require File.expand_path('./cybozu6', File.dirname(__FILE__))
require File.expand_path('./tokyo_dome', File.dirname(__FILE__))

target = ARGV.shift
return unless target

target_settings = Settings.targets.symbolize_keys[target.to_sym]

bot_class = eval(target_settings[:bot_name])
users = target_settings[:users]

wdays = %w( 日 月 火 水 木 金 )

now = Time.now
#now = Time.new(2014, 3, 28, 10, 00)
#now = Time.new(2013, 12, 27, 10, 00)
#now = Time.new(2013, 10, 4, 10, 00)
#now = Time.new(2013, 11, 8, 10, 00)

scheduler = Cybozu6::Scheduler.new(Settings.cybozu.symbolize_keys, users, now)
# Cybozu 終了だが、休日判定のためにSchedulerだけイニシャライズ
# scheduler.open

# 祝日と思われるなら実行しない
exit if scheduler.holiday?

seeds = Settings.messages.scheduler_today
messages = []

if scheduler.first_of_year?
  first_message ||= seeds.first_of_year.header % now.year
end

first_message ||= seeds.header % [ now.month, now.day, wdays[now.wday] ]
messages << first_message

# Cybozu 終了
# if schedule_list.size + sebastian_list.size > 0 && !scheduler.last_of_year?
#   messages << seeds.schedule.header
# 
#   sebastian_list.each do |s|
#     if s.overday?
#       messages << seeds.schedule.overday % [ s.title, '' ]
#     elsif s.banner?
#       messages << seeds.schedule.banner % [ s.title, '' ]
#     else
#       messages << seeds.schedule.timetable % [ s.start_time_to_s, s.title, '' ]
#     end
#   end
# 
#   schedule_list.each do |s|
#     if s.overday?
#       messages << seeds.schedule.overday % [ s.title, s.user_names.map{|n| "#{target_settings[:user_prefix]}#{n}#{target_settings[:user_suffix]}" }.join("、") ]
#     elsif s.banner?
#       messages << seeds.schedule.banner % [ s.title, s.user_names.map{|n| "#{target_settings[:user_prefix]}#{n}#{target_settings[:user_suffix]}" }.join("、") ]
#     else
#       messages << seeds.schedule.timetable % [ s.start_time_to_s, s.title, s.user_names.map{|n| "#{target_settings[:user_prefix]}#{n}#{target_settings[:user_suffix]}" }.join("、") ]
#     end
#   end
# 
#   messages << seeds.schedule.footer
# end

tokyodome = TokyoDomeSchedule.today(now)
if tokyodome
  if /休演/ === tokyodome[1]
    messages << seeds.tokyodome.close_message % tokyodome[1]
  else
    messages << seeds.tokyodome.message % tokyodome
  end
end

cityhall = CityHallSchedule.today(now)
if cityhall
  messages << seeds.cityhall.message % cityhall
end

if scheduler.last_of_year?
  messages.push(*[ seeds.last_of_year.footer ].flatten)
elsif scheduler.first_of_year?
  messages << seeds.first_of_year.footer
else
  messages << seeds.footer
end

#puts messages
#exit 1

client = bot_class::Client.new(target_settings)
client.message(messages, notify: 1)

exit
