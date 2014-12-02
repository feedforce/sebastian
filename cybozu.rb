# -*- coding: utf-8 -*-

require 'net/http'
require 'uri'
require 'nokogiri'

require File.expand_path('./settings', File.dirname(__FILE__))

module Cybozu
  class Client
    def initialize(config, now)
      @uid = config[:uid]
      @client = Request.new(config)
      @scheduler = Scheduler.new(now)
      @now = now
    end

    def first_of_year?
      # 1月でなければ関係ない
      return false if @now.month != 1

      # 4日で土日ではないなら初出勤日
      return true if @now.day == 4 and !@now.sunday? and !@now.saturday?

      # 5日か6日で月曜なら初出勤日
      return true if (@now.day == 5 or @now.day == 6) and @now.monday?

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

    def holiday?
      # 年末は12/30以降休み
      return true if @now.month == 12 && @now.day >= 30
      # 年始は1/4以前休み
      return true if @now.month == 1 && @now.day <= 4

      response = @client.get_schedule(@uid, @now)
      parser = Parser.new(response.body)
      parser.holiday.size >= 1
    end

    def get_schedule(users, overday = false)
      users.each do |uid|
        response = @client.get_schedule(uid, @now)
        parser = Parser.new(response.body)
        parser.schedule(@now).each do |time, title|
          @scheduler.add(uid: uid, start_time: time, title: title)
        end

        if overday
          parser.overday_schedule.each do |title|
            @scheduler.add(uid: uid, title: title)
          end

          parser.banner_schedule.each do |title|
            @scheduler.add(uid: uid, title: title)
          end
        end
      end
      @scheduler
    end

    def get_overday_schedule(users)
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
        time, title = elem.text.strip.split(/[\r\n]+/, 2)
        h, m = time.split(':')
        start = Time.new(now.year, now.month, now.day, h.to_i, m.to_i)
        [ start, title ]
      end
    end

    def overday_schedule
      elems = @doc.xpath('//div[@class="overday"]/li')
      elems.map do |elem|
        elem.text.strip
      end
    end

    def banner_schedule
      elems = @doc.xpath('//div[@class="banner"]')
      elems.map do |elem|
        elem.text.strip
      end
    end
  end

  class Request
    def initialize(config = {})
      @login_uid = config[:uid]
      @login_password = config[:password]
      @base_url = config[:base_url]
      @header = { 'User-Agent' => config[:user_agent] }
      @cookie = {}
    end

    def get_schedule(uid, time = nil)
      login(schedule_query(uid, time))
    end

    def login(get_query = '')
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

      return false unless Net::HTTPOK === response

      response.get_fields('Set-Cookie').each do |cookie|
        key, val = cookie.split(';').first.split('=')
        @cookie[key] = val
      end

      response
    end

    def header
      return @header if @cookie.size < 1
      @header.merge('Cookie' => cookie)
    end

    def cookie
      @cookie.map{|vals| vals.join('=') }.join('; ')
    end

    def schedule_query(uid, time = nil)
      "page=ScheduleUserDay&UID=#{uid}&GID=&Date=da.#{(time||Time.now).strftime('%Y.%m.%d')}"
    end

    def login_url
      @login_url ||= URI.parse(File.join(@base_url, '/ag.cgi?'))
    end
  end

  class Scheduler
    attr_reader :schedule

    def initialize(now)
      @now = now
      @schedule = {}
      @_relation = nil
    end

    def add(values)
      @schedule[values[:title]] ||= Schedule.new(values)
      @schedule[values[:title]].add_user(values[:uid])
      @schedule[values[:title]]
    end

    def all
      result = @_relation || @schedule
      reset
      result
    end

    def relation
      @_relation || @schedule
    end

    def reset
      @_relation = nil
      self
    end

    # now から interval 分以内
    def by_time(now = nil, interval = 30)
      now ||= @now
      @_relation = relation.select do |title, schedule|
        !schedule.overday? && now < schedule.start_time && schedule.start_time < now + 30 * 60
      end
      self
    end

    # 全日の予定のみ
    def by_overday
      @_relation = relation.select do |title, schedule|
        schedule.overday?
      end
      self
    end

    # 全日でない予定のみ
    def by_not_overday
      @_relation = relation.select do |title, schedule|
        !schedule.overday?
      end
      self
    end

    # user をキーにする
    def group_by_user
      @_relation = relation.each_with_object({}) do |vals, h|
        t, s = vals
        s.users.each do |u|
          h[u] ||= []
          h[u] << s
        end
      end
      self
    end

    # time をキーにする
    def group_by_time
      @_relation = relation.each_with_object({}) do |vals, h|
        next if vals.last.start_time.nil?
        h[vals.last.start_time] ||= []
        h[vals.last.start_time] << vals.last
      end
      self
    end
  end

  class Schedule
    attr_reader :start_time, :title, :users

    def initialize(attrs = {})
      @start_time = attrs[:start_time]
      @title = attrs[:title]
      @users = []
    end

    def add_user(uid)
      @users << uid.to_i
      @users = @users.uniq.sort
    end

    def start_time_to_s
      @start_time ? @start_time.strftime('%H:%M') : nil
    end

    def users_to_s(settings, suffix = '様')
      @users.map{|u| settings.key(u.to_i) + suffix }.join('、')
    end

    def overday?
      @start_time.nil?
    end
  end
end
