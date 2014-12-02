# -*- coding: utf-8 -*-

require "carrier-pigeon"

module IrcBot
  class Client
    def initialize(config = {})
      @config = config
      @channel = @config[:channel]
    end

    def message(messages)
      client = CarrierPigeon.new(@config)
      [ messages ].flatten.each do |message|
        sleep(1)
        client.message(@channel, message)
      end
      client.die
    end
  end
end
