linael :system, require_auth: true do
  help [
    t.system.help.description,
    t.help.helper.line.white,
    t.help.helper.line.admin,
    t.system.function.bash
  ]

  on :cmd_auth, :bash, /^!bash\s+\S/ do |msg, options|
    result = `#{options.all}`
    answer(msg, t.system.act.bash(options.from_who))
    result.delete("\r").split("\n").each do |line|
      talk(options.from_who, line, msg.server_id)
    end
  end
end
