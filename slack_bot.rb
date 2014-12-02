# -*- coding: utf-8 -*-

require 'slack-notifier'
module SlackBot
  class Client
    def initialize(config = {})
      @config = config
    end

    def message(messages, options = {})
      client = Slack::Notifier.new @config[:webhook_url]
      [ messages ].flatten.each do |message|
        sleep(1)
        client.ping message, link_names: true
      end
    end
  end
end
