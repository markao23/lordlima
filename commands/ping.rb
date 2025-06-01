# frozen_string_literal: true

module PingCommands
  extend Discordrb::Commands::CommandContainer

  command(:ping, description: "Verifica a latencia do bot e responde com pong", usage: 'ping') do |event|
    latencia = Time.now - event.timestamp
    latencia_em_segundos = latencia * 1000
    event.respond "Pong! 🏓 latencia: #{format('%.2f', latencia_em_segundos)} ms"
  end
end

if defined?($command_module_to_load) && !$command_module_to_load.nil? # Forma correta
  $command_module_to_load << PingCommands
else
  puts "ERRO em commands/ping.rb: $command_module_to_load não está acessível ou é nil!"
end
