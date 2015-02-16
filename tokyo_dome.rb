# -*- coding: utf-8 -*-

require 'net/http'
require 'uri'
require 'nokogiri'

module CityHallSchedule
  def self.today(now = nil)
    now ||= Time.now
    uri = URI.parse("http://www.tokyo-dome.co.jp/tdc-hall/event/")
    response = Net::HTTP.start(uri.host, uri.port) do |http|
      http.get(uri.path)
    end

    doc = Nokogiri::HTML.parse(response.body.force_encoding('UTF-8'))

    # <div class="calendar">
    #   <table>
    #     <tr>
    #       <td>
    #         <span>day</span>
    #         <a href="#MonthDay">Title</a>
    #       </td>
    #     </tr>
    #   </table>
    # </div>
    calendar = doc.xpath('//div[contains(@class, "calendar")]').first
    return nil if calendar.nil?

    target_day = calendar.xpath(".//span[text()=#{now.day}]/parent::*").first
    if target_day.nil?
      day = '%02d' % now.day
      target_day = calendar.xpath(".//span[text()=#{day}]/parent::*").first
    end
    return nil if target_day.nil?

    elem = target_day.xpath(".//a").first
    return nil if elem.nil?

    fragment = elem.attribute('href').text.strip
    fragment = fragment.sub(/\A#/, '')

    uri.fragment = fragment
    [ elem.text.strip, uri.to_s ]
  end
end

module TokyoDomeSchedule
  def self.today(now = nil)
    now ||= Time.now
    uri = URI.parse("http://www.tokyo-dome.co.jp/dome/schedule/?y=#{now.year}&m=#{now.month}")
    response = Net::HTTP.start(uri.host, uri.port) do |http|
      http.get("#{uri.path}?#{uri.query}")
    end

    doc = Nokogiri::HTML.parse(response.body.force_encoding('UTF-8'))
    elems = doc.xpath('//table[@class="info_table"]/tr[@class="th_left"]')
    elems.each do |elem|
      next unless /\A#{now.day}日/ === elem.xpath('.//th').text.strip

      time = elem.xpath('.//td')[1].text.strip rescue nil
      if time.to_s == ''
        time = elem.xpath('.//td')[0].text.strip rescue nil
      end
      time = time.to_s == '' ? '' : "#{time}より"

      title = elem.xpath('.//div').first
      break if title.nil?

      result = ''
      img = title.xpath('.//*/img').first
      if img
        alt = img.attribute('alt').text.strip
        result += "【#{alt}】" if alt && alt != ''
      end
      name = title.xpath('.//*/a').first
      name ||= title
      if name
        result += name.text.strip
      end

      break result == '' ? nil : [ time, result ]
    end
  end
end
