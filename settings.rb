# -*- coding: utf-8 -*-

require 'settingslogic'

def settings_namespace
  now = Time.now
  if now.year == 2014 && now.month == 1 && now.day == 16
    return 'abyss'
  end

  'defaults'
end

class Settings < Settingslogic
  source File.expand_path('./settings.yml', File.dirname(__FILE__))
  namespace settings_namespace
end
