# frozen_string_literal: true

require "pry"
require "discordrb"
require "open-uri"
require_relative "lib/config"
require_relative "lib/sound"

bot = Discordrb::Bot.new(token: DndMusic::Config.discord.token)

sound_lists_per_server = {}
currently_playing = {}

Thread.new do
  while true
    sleep 10

    bot.voices.each do |server_id, voice|
      if voice.channel.users.none? {|user| user.id != bot.profile.id}
        currently_playing.delete(server_id)
        voice.destroy
      end
    end
  end
end

bot.register_application_command(:soundboard, "Open the soundboard panel", server_id: "906610348726038529") do |soundboard_cmd|
  soundboard_cmd.subcommand(:controls, "Print the controls")
  soundboard_cmd.subcommand(:list, "List all songs")
  soundboard_cmd.subcommand(:configure, "Configure the soundboard") do |configure_cmd|
    configure_cmd.attachment(:sound_list, "List of sounds to use", required: true)
  end
  soundboard_cmd.subcommand(:play, "Play a sound") do |play_cmd|
    play_cmd.string("sound", "Which sound to play", required: true)
  end
end

bot.application_command(:soundboard).subcommand(:controls) do |event|
  next event.respond(content: "No list prepared", ephemeral: true) if !sound_lists_per_server[event.server.id]

  event.respond(content: "Select a sound to start", ephemeral: true) do |_, view|
    view.row do |r|
      r.select_menu(custom_id: "sound_select", placeholder: "Select me!") do |s|
        sound_lists_per_server[event.server.id].map do |sound|
          s.option(label: sound.name, value: sound.file)
        end
      end
    end
  end
end

bot.application_command(:soundboard).subcommand(:list) do |event|
  sound_list = <<~STR
    ```
    #{Sound.all.map(&:name).join("\n")}
    ```
  STR

  event.respond(content: sound_list, ephemeral: true)
end
bot.application_command(:soundboard).subcommand(:play) do |event|
  channel = event.user.voice_channel
  next event.respond(content: "You're not in any voice channel!") unless channel
  bot.voice_connect(channel)

  sound = "sounds/#{event.options["sound"]}.mp3"
  event.respond(content: "You selected: #{sound}", ephemeral: true)

  voice_bot = bot.voices[event.server.id]
  voice_bot.play_file(sound)
end

bot.application_command(:soundboard).subcommand(:configure) do |event|
  sound_list_attachment = event.resolved.attachments[event.options["sound_list"].to_i]

  data = ""

  URI.open(sound_list_attachment.url) do |f|
    data = f.read
  end

  sounds = data.split("\n").map do |sound|
    [sound, Sound.find(name: sound)]
  end
 
  sounds_not_found = sounds.filter do |name, sound|
    sound.nil?
  end.map(&:first)

  if sounds_not_found.any?
    response = <<~STR
      Some sounds were not found:
      `#{sounds_not_found.join("`\n`")}`
    STR
    next event.respond(content: response, ephemeral: true)
  end

  next event.respond(content: "Maximum of 25 sounds allowed", ephemeral: true) if sounds.count > 25

  sound_lists_per_server[event.server.id] = sounds.map do |_name, sound|
    sound
  end

  response = <<~STR
    The soundboard has been configured with the following sounds:
    `#{sounds.map(&:first).join("`\n`")}`
  STR
  event.respond(content: response, ephemeral: true)
end

bot.select_menu(custom_id: "sound_select") do |event|
  channel = event.user.voice_channel
  next event.respond(content: "You're not in any voice channel!") unless channel
  bot.voice_connect(channel)

  event.respond(content: "You selected: #{event.values.first}", ephemeral: true)

  voice_bot = bot.voices[event.server.id]
  voice_bot.play_file(event.values.first)
end

bot.run