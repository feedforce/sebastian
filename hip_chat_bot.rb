# -*- coding: utf-8 -*-

require 'hipchat'
require 'settingslogic'

module HipChatBot
  class Client
    def initialize(config = {})
      @config = config
    end

    def message(messages, options = {})
      client = HipChat::Client.new(@config[:api_token], @config[:options])
      [ messages ].flatten.each_with_index do |message, i|
        sleep(0.5)
        prefix = (i == 0 or i == messages.size - 1) ? @config[:message_prefix] : nil
        client[@config[:room_id]].send(@config[:username], "#{prefix}#{replace_emoticon(message)}", @config[:message_options].merge(options))
        #puts replace_emoticon(message)
      end
    end

    EMOTICON_TABLE = {
      'ソーシャルPLUS' => 'sp',
      'social' => 'sp',
      'socialplus' => 'sp',
      'dfチーム' => 'df',
      'dfストーリー' => 'df',
      'df/クローラー' => 'df',
      'dfリリース' => 'df',
      'df見積もり' => 'df',
      'CFポータル' => 'cf',
      'feedforce' => 'ff',
      'フィードフォース' => 'ff',
      'fftt' => 'ff',
      '制作MTG' => 'ff',
      'セールスMTG' => 'ff',
      '社内環境改善' => 'ff',
      'イベントＭＴＧ' => 'ff',
      'ruby' => 'ruby',
      'redmine' => 'redmine',
      'jenkins' => 'jk',
      '東京ドーム' => 'tdc',
    }
    def replace_emoticon(message)
      emos = []
      EMOTICON_TABLE.each do |txt, e|
        if message.to_s.match(Regexp.new(txt, Regexp::EXTENDED | Regexp::IGNORECASE))
          emos << e
        end
      end
      emos.uniq.map{|e| "(#{e}) " }.join + message.to_s
    end
  end
end
