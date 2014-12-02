Sebastian
=========

Setup
-----

    $ bundle install --path vendor/bundle --binstubs vendor/bundle/bin --jobs=4
    $ cp settings.yml.sample settings.yml
    (edit password, webhook_url and api_token)

Run
---

    $ ruby schedule_today.rb slack
    $ ruby time_signal.rb slack before_period
    $ ruby time_signal.rb slack period

See also
--------

[執事のセバスチャンが東京ドームのイベントをHipChatで教えてくれる | feedforce Engineers' blog](http://tech.feedforce.jp/sebastian.html)
