# -*- coding: utf-8 -*-

require 'net/http'
require 'uri'
require 'nokogiri'

require File.expand_path('./settings', File.dirname(__FILE__))

# # initialize
# scheduler = Cybozu6::Scheduler.new(config, users, now)
# scheduler.open
#
# # calendar
# scheduler.holiday?
# scheduler.last_of_year?
# scheduler.first_of_year?
#
# # schedule for users
# scheduler.get_schedule_today # => [ #<Schedule>, ... ]
# scheduler.get_schedule  # => [ #<Schedule>, ... ]
#
# # schedule for Sebastian
# scheduler.get_sebastian_schedule_today # => [ #<Schedule>, ... ]
# scheduler.get_sebastian_schedule  # => [ #<Schedule>, ... ]
#
# # Schedule instance
# schedule.eid
# schedule.start_time
# schedule.start_time_to_s
# schedule.title
# schedule.users
# schedule.user_ids
# schedule.user_names
#
# schedule.overday?
# schedule.banner?
#

module Cybozu6
  class Scheduler
    attr_reader :config, :users, :now

    def initialize(config, users, now)
      @sebastian_uid = config[:uid]
      @config = config
      @users = users
      @now = now ||= Time.now

      @client = Client.new(@config)

      @sebastian_page = nil
      @user_pages = {}

      @schedule = {}
    end

    def open
      return false unless @client.get_schedule(@sebastian_uid, @now)
      @sebastian_page = @client.body
      @sebastian_page.schedule(@now).each do |s|
        eid = s[:eid]
        unless @schedule[eid]
          @schedule[eid] = Schedule.new(
            eid,
            start_time: s[:start_time],
            title: s[:title],
            type: :timetable,
          )
        end
      end

      @sebastian_page.overday_schedule.each do |s|
        eid = s[:eid]
        unless @schedule[eid]
          @schedule[eid] = Schedule.new(
            eid,
            title: s[:title],
            type: :overday,
          )
        end
      end

      @sebastian_page.banner_schedule.each do |s|
        eid = s[:eid]
        unless @schedule[eid]
          @schedule[eid] = Schedule.new(
            eid,
            title: s[:title],
            type: :banner,
          )
        end
      end

      @users.each do |uid, user_name|
        uid = uid.to_s.gsub(/\D/, '').to_i
        return false unless @client.get_schedule(uid, @now)
        page = @client.body
        @user_pages[uid] = page

        page.schedule(@now).each do |s|
          eid = s[:eid]
          unless @schedule[eid]
            @schedule[eid] = Schedule.new(
              eid,
              start_time: s[:start_time],
              title: s[:title],
              type: :timetable,
            )
          end
          @schedule[eid].add_user(uid, user_name)
        end

        page.overday_schedule.each do |s|
          eid = s[:eid]
          unless @schedule[eid]
            @schedule[eid] = Schedule.new(
              eid,
              title: s[:title],
              type: :overday,
            )
          end
          @schedule[eid].add_user(uid, user_name)
        end

        page.banner_schedule.each do |s|
          eid = s[:eid]
          unless @schedule[eid]
            @schedule[eid] = Schedule.new(
              eid,
              title: s[:title],
              type: :banner,
            )
          end
          @schedule[eid].add_user(uid, user_name)
        end
      end

      true
    end

    # 休日かどうかを返す
    def holiday?
      # 年末は12/30以降休み
      return true if @now.month == 12 && @now.day >= 30
      # 年始は1/4以前休み
      return true if @now.month == 1 && @now.day <= 4

      # 土日なら休日
      return true if @now.sunday? || @now.saturday?

      # Cybozuで祝日登録されていれば休日とみなす
      # @sebastian_page.holiday.size >= 1
      # Cybozu 終了のため、一旦祝日判定はやめる
      false
    end

    # 年末の最終出社日かどうかを返す
    def last_of_year?
      # 12月でなければ関係ない
      return false if @now.month != 12

      # 29日で土日ではないなら最終出社日
      return true if @now.day == 29 and !@now.sunday? and !@now.saturday?

      # 27日か28日で金曜なら最終出社日
      return true if (@now.day == 27 or @now.day == 28) and @now.friday?

      false
    end

    # 年始の出社開始日かどうか返す
    def first_of_year?
      # 1月でなければ関係ない
      return false if @now.month != 1

      # 4日で土日ではないなら初出勤日
      return true if @now.day == 4 and !@now.sunday? and !@now.saturday?

      # 5日か6日で月曜なら初出勤日
      return true if (@now.day == 5 or @now.day == 6) and @now.monday?

      false
    end

    def schedule
      @schedule.sort_by{|k,v| v.start_time.to_i }.map{|k,v| v }
    end

    def get_schedule_today
      schedule.select{|v| !v.sebastian? }
    end

    def get_schedule
      schedule.select{|v| !v.sebastian? && !v.overday? && !v.banner? && v.immediately?(@now) }
    end

    def get_sebastian_schedule_today
      schedule.select{|v| v.sebastian? }
    end

    def get_sebastian_schedule
      schedule.select{|v| v.sebastian? && !v.overday? && !v.banner? && v.immediately?(@now) }
    end
  end

  class Schedule
    attr_reader :eid, :start_time, :title, :users, :type

    def initialize(eid, details = {})
      @eid = eid
      @start_time = details[:start_time]
      @title = details[:title]
      @type = details[:type]

      @users = {}
    end

    def add_user(id, name)
      @users[id] = name
    end

    def start_time_to_s
      start_time ? start_time.strftime('%H:%M') : nil
    end

    def immediately?(now = time.now, term = 30)
      return false unless start_time
      return false if start_time < now
      start_time < now + (term * 60)
    end

    def user_ids
      users.keys.sort
    end

    def user_names
      users.keys.sort.map{|i| users[i] }
    end

    def sebastian?
      users.size == 0
    end

    def timetable?
      @type.to_s == 'timetable'
    end

    def overday?
      @type.to_s == 'overday'
    end

    def banner?
      @type.to_s == 'banner'
    end
  end

  class Client
    attr_reader :login_url, :response, :body

    def initialize(config = {})
      @login_uid = config[:uid]
      @login_password = config[:password]

      @base_url = config[:base_url]
      @login_url = URI.parse(URI.join(@base_url, 'ag.cgi?').to_s)

      @header = { 'User-Agent' => config[:user_agent] }

      @response = nil
      @error = nil
      @body = nil
    end

    def get_schedule(uid, time = nil)
      request(schedule_query(uid, time))
    end

    def request(get_query = '')
      query = {
        _System: 'login',
        _Login:  '1',
        GuideNavi: '1',
        _ID: @login_uid,
        password: @login_password,
      }

      uri = login_url
      response = Net::HTTP.start(uri.host, uri.port) do |http|
        http.post(uri.path + '?' + get_query, query.map{|v| v.join('=') }.join('&'), header)
      end

      unless Net::HTTPOK === response
        @error = response
        return false
      end

      @response = response
      @body = Parser.new(response.body)

      true
    end

    def header
      # TODO: いずれクッキー対応を考えたいが、
      #       現状クッキーを受け入れてもログインが持ち回せないので後回し
      @header
    end

    def schedule_query(uid, time = nil)
      date = (time||Time.now).strftime('%Y.%m.%d')
      "page=ScheduleUserDay&UID=#{uid}&GID=&Date=da.#{date}"
    end
  end

  class Parser
    def initialize(html)
      @doc = Nokogiri::HTML.parse(html.encode('UTF-8', 'SJIS'))
    end

    def holiday
      elems = @doc.xpath('//div[@class="overday"]/font[@size="-1"]')
      elems.map {|elem| elem.text }
    end

    def schedule(now)
      elems = @doc.xpath('//div[@class="critical"]')
      elems.map do |elem|
        eid = parse_eid(elem)
        time, title = elem.text.strip.split(/[\r\n]+/, 2)
        h, m = time.split(':')
        start = Time.new(now.year, now.month, now.day, h.to_i, m.to_i)

        { eid: eid, start_time: start, title: title }
      end
    end

    def overday_schedule
      elems = @doc.xpath('//div[@class="overday"]/li')
      elems.map do |elem|
        eid = parse_eid(elem)
        title = elem.text.strip

        { eid: eid, title: title }
      end
    end

    def banner_schedule
      elems = @doc.xpath('//div[@class="banner"]')
      elems.map do |elem|
        eid = parse_eid(elem)
        title = elem.text.strip

        { eid: eid, title: title }
      end
    end

    def parse_eid(elem)
      atag = elem.xpath('.//a').first
      return nil unless atag

      eid = atag.attribute('href').to_s.match(/[&?]sEID=(\d+)\&?/i)[1]
      eid ? eid.to_i : nil
    end
  end
end
