# frozen_string_literal: true
module MusicCommands
  module CreatePlaylist
    extend Discordrb::Commands::CommandContainer
    command(:create,
            description: 'Create a new playlist',
            aliases: [:criarplaylist, :newpl, :criarfila, :novafila],
            usage: 'create <nome da playlist>') do |event, *playlist_name_parts|
      if playlist_name_parts.empty?
        event.respond "❓ Por favor, forneça um nome para a nova playlist. Ex: `!create Minhas Favoritas Rock`"
        next
      end
      playlist_name = playlist_name_parts.join(' ').strip
      if playlist_name.empty? || playlist_name.length < 2
        event.respond "⚠️ O nome da playlist precisa ter pelo menos 2 caracteres e não pode ser vazio."
        next
      end
      unless  defined? ($playlist) && $playlist.is_a?(Hash)
        event.respond "❌ Erro interno: O sistema de playlists não foi inicializado corretamente pelo bot."
        puts "ERRO CRÍTICO: $playlists não é um Hash ou não está definido!"
        next
      end
      if $playlist.key?(playlist_name)
        event.respond "⚠️ Já existe uma playlist chamada `#{playlist_name}`. Use `!queue #{playlist_name}` para vê-la ou escolha outro nome."
      else
        $playlist[playlist_name] = []
        $active_playlist_name = playlist_name
        event.respond "✅ Playlist `#{playlist_name}`"
      end
      nil
    end
  end
end
if defined?($item_musicais_carregados) && $item_musicais_carregados.is_a?(Array)
  $item_musicais_carregados << MusicCommands::CreatePlaylist
else
  # Este aviso é mais para o desenvolvedor do bot
  puts "[AVISO do create_playlist_command.rb]: $item_musicais_carregados não está definida como Array no escopo global ou este arquivo foi carregado antes de sua inicialização."
end