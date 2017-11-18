# A test module
linael :test, constructor: "Skizzk", require_auth: true, required_mod: ["admin"] do
  match happy: /happy/
  value sad: /sad(.)/

  help ["Module de test"]

  on_init do
    p "YOUPI!"
  end

  on_load do
    p "Loaded <3"
  end

  on :cmd, :test, /^!test\s/ do |msg, options|
    before(msg) do
      2 == 2
    end

    answer(msg, "ça marche")
    answer(msg, options.happy?)
    answer(msg, options.sad)
    answer(msg, options.who)
  end

  db_list :list_1, :list_2

  on :cmd, :test_db, /^!test_db/ do |msg, _|
    answer(msg, list_1)
    list_1 << "Test"
    answer(msg, list_1)
    answer(msg, list_2)
  end

  on :cmd, :test2, /^!test2\s/ do |msg, options|
    at(4.seconds.from_now, options) do |options|
      talk(options.from_who, "A kikoo from 4 seconds in the past", msg.server_id)
    end
  end

  on :cmd, :test3, /^!test3\s/ do |msg, options|
    150.times do
      talk(options.from_who, "TESTTESTESTETETETETETETETTETETETETETTETETETETTETETETETETETETETTETETETESTESTETSTETS", msg.server_id)
    end
  end
end
