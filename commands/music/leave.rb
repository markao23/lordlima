# frozen_string_literal: true

module MusicCommands
  module Leave
    extend Discordrb::Commands::CommandContainer
    command(:leave, aliases: [:sair, :disconnect, :quit],
            description: 'Faz o bot sair do canal de voz em que está conectado no servidor.',
            usage: '!leave') do |event|
      voice_client_on_server = event.voice
      if voice_client_on_server
        nome_canal = voice_client_on_server.channel.name
        voice_client_on_server.destroy
        event.respond "Prontinho! Saí do canal de voz `#{nome_canal}`. Até a próxima! 👋"
      else
        event.respond "Ué, mas eu nem estou em um canal de voz neste servidor. 🤔"
      end
      nil
    end
  end
end
if defined? ($item_musicais_carregados) && $command_module_to_load.is_a?(Array)
  $item_musicais_carregados << MusicCommands::Leave
else
  puts "[AVISO do arquivo 'leave_command.rb']: A variável global $music_modules_to_load não foi encontrada ou não é uma Array."
  puts "O comando !leave pode não ser carregado corretamente. Verifique seu script principal do bot."
  puts "Você precisa ter algo como '$music_modules_to_load = []' antes de carregar os módulos."
end