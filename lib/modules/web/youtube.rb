require('open-uri')
require('htmlentities')

# Fetches a YouTube title and says it
linael :youtube, author: "Vinz_" do
  help [
    t.youtube.help.description
  ]

  value id: /http[s]?:\/\/(?:www\.)?youtu.*v=([^&\s]*)/

  on_init do
    @users = ["internets"]
  end

  on :msg, :youtube, /http[s]?:\/\/(?:www\.)?youtu.*\?/ do |msg, options|
    before(msg) do |msg|
      !(@users.detect { |user| msg.who.downcase.match(user) })
    end

    open("http://www.youtube.com/watch?v=#{options.id}").read =~ /<title>(.*?)<\/title>/
    answer(msg, HTMLEntities.new.decode("#{msg.who}: #{$1}"))
  end
end
