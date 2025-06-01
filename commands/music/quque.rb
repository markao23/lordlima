module MusicCommands
  class ViewQueue
    extend Discordrb::Commands::CommandContainer

    command(:queue,
            aliases: [:fila, :verfila, :playlist, :listpl],
            description: 'Mostra as músicas em uma playlist. Se nenhum nome for dado, mostra a playlist ativa.',
            usage: 'queqe [nome da playlist]') do |event, *playlist_name_parts|
      unless defined? ($playlist) && $playlist.is_a?(Hash) && defined? ($active_playlist_name)
        event.respond "❌ Erro interno: O sistema de playlists não foi inicializado corretamente pelo bot."
        puts "ERRO CRÍTICO: $playlists ou $active_playlist_name não estão definidos/inicializados!"
        next
      end
      target_playlist_name = playlist_name_parts.join(' ').strip
      if target_playlist_name.empty?
        if $active_playlist_name && $playlist.key?($active_playlist_name)
          target_playlist_name = $active_playlist_name
          event.send_message "Mostrando a playlist ativa: `#{target_playlist_name}`"
        else
          event.respond "ℹ️ Nenhuma playlist ativa definida. Use `!queue <nome da playlist>` para ver uma específica ou `!create <nome>` para criar e ativar uma nova."
          next
        end
      end
      playlist_songs = $playlist[target_playlist_name]
      if playlist_songs
        event.respond "Aplaylist #{target_playlist_name} está vazia! Use `!play <url>` enquanto ela estiver ativa para adicionar músicas."
      else
        response_message = []
        current_message = "🎶 **Músicas na playlist `#{target_playlist_name}`:**\n"
        playlist_songs.each do |song, index|
          title = song[:title] || "Titulo desconhecido"
          url = song[:url] ? "<#{song[:url]}>" : "URL Desconhecida"
          added_by = song[:added_by] ? "por #{song[:added_by]}" : ""
          song_line = "**#{index + 1}.** #{title} #{url}#{added_by}\n"
          if(current_message + song_line).length > 1900
            response_message << current_message
            current_message = ""
          end
          current_message += song_line
        end
        response_message << current_message unless current_message.empty?
        response_message.each do |msg_part|
          event.respond msg_part
        end
      end
      nil
    end
  end
end
if defined?($item_musicais_carregados) && $item_musicais_carregados.is_a?(Array)
  $item_musicais_carregados << MusicCommands::ViewQueue
else
  puts "[AVISO do view_queue_command.rb]: $music_modules_to_load não está definida como Array no escopo global ou este arquivo foi carregado antes de sua inicialização."
end