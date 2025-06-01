# frozen_string_literal: true
# commands/music/play_command.rb

require 'httparty' # Gem para fazer requisições HTTP (para a API do YouTube)
require 'json'     # Gem para analisar respostas JSON da API
require 'open3'    # Módulo Ruby para executar comandos externos (como o yt-dlp)


YOUTUBE_API_KEY = ENV['YOUTUBE_API_KEY']


module MusicCommands
  module Play
    extend Discordrb::Commands::CommandContainer

    command(:play,
            description: 'Toca uma música do YouTube a partir de uma URL.',
            usage: 'play <URL do YouTube>') do |event, *args|

      # 1. Validações Iniciais
      unless YOUTUBE_API_KEY
        event.respond "❌ **Erro de Configuração:** A chave da API do YouTube (YOUTUBE_API_KEY) não foi definida nas variáveis de ambiente do bot. Não posso buscar informações dos vídeos."
        next
      end

      youtube_url = args.join(' ')
      if youtube_url.empty?
        event.respond "ℹ️ Por favor, me dê uma URL do YouTube para tocar. Ex: `!play https://www.youtube.com/watch?v=dQw4w9WgXcQ`"
        next
      end

      # Regex para validar URL do YouTube e extrair o ID do vídeo
      match_data = youtube_url.match(%r{(?:https?://)?(?:www\.)?(?:youtube\.com/(?:watch\?v=|embed/|v/)|youtu\.be/)([\w\-]{11})(?:\S+)?})
      unless match_data
        event.respond "⚠️ URL do YouTube inválida. Verifique o link e tente novamente."
        next
      end
      video_id = match_data[1]

      # 2. Gerenciamento do Canal de Voz
      user_voice_channel = event.user.voice_channel
      unless user_voice_channel
        event.respond "➡️ Você precisa estar em um canal de voz para eu tocar algo, #{event.user.mention}!"
        next
      end

      # Conecta ao canal de voz do usuário se não estiver conectado ou se estiver em outro canal no mesmo servidor
      current_bot_voice_client = event.voice # Pega o cliente de voz atual do bot NO SERVIDOR do evento
      if !current_bot_voice_client || current_bot_voice_client.channel != user_voice_channel
        begin
          event.bot.voice_connect(user_voice_channel) # Conecta ou move para o canal do usuário
          # Não precisa de mensagem aqui, a busca pela música já é um feedback
        rescue Discordrb::Errors::NoPermission
          event.respond "😥 Não tenho permissão para entrar no canal de voz `#{user_voice_channel.name}`."
          next
        rescue StandardError => e
          event.respond "😕 Erro ao tentar entrar no seu canal de voz: `#{e.message}`"
          puts "Erro ao conectar à voz no play: #{e.message}\n#{e.backtrace.join("\n")}"
          next
        end
      end

      # Garante que temos o objeto de voz após a tentativa de conexão
      voice_client = event.voice
      unless voice_client
        event.respond "❓ Não consegui uma conexão de voz válida. Tente usar o comando `!join` primeiro se o problema persistir."
        next
      end

      # 3. Busca Informações do Vídeo com a API do YouTube
      video_title = "Música do YouTube" # Título padrão
      msg = event.respond "⏳ Buscando informações do vídeo..." # Feedback inicial

      begin
        api_url = "https://www.googleapis.com/youtube/v3/videos?id=#{video_id}&key=#{YOUTUBE_API_KEY}&part=snippet&fields=items(id,snippet(title))"
        response = HTTParty.get(api_url, timeout: 5) # Timeout de 5 segundos

        if response.success?
          parsed_data = JSON.parse(response.body)
          if parsed_data['items'] && !parsed_data['items'].empty?
            video_title = parsed_data['items'][0]['snippet']['title']
            msg.edit "▶️ Preparando para tocar: **#{video_title}**"
          else
            msg.edit "ℹ️ Não encontrei o título pela API do YouTube (ID: `#{video_id}`), mas vou tentar tocar mesmo assim."
            puts "WARN: API do YouTube não retornou 'items' para video ID: #{video_id}. Resposta: #{response.body}"
          end
        else
          msg.edit "⚠️ Erro ao buscar dados da API do YouTube (#{response.code}). Tentando tocar mesmo assim..."
          puts "ERRO API YouTube: Código #{response.code} - #{response.message} - #{response.body}"
        end
      rescue HTTParty::Error, SocketError, JSON::ParserError, Net::ReadTimeout => e # Erros comuns de HTTP/JSON/Timeout
        msg.edit "⚠️ Problema ao contatar a API do YouTube (#{e.class}). Tentando tocar mesmo assim..."
        puts "ERRO GERAL API YouTube: #{e.class} - #{e.message}"
      end


      yt_dlp_command = "yt-dlp -f bestaudio --no-warnings -g \"https://www.youtube.com/watch?v=#{video_id}\""
      audio_stream_url = nil

      begin


        stdout_str, stderr_str, status = Open3.capture3(yt_dlp_command)

        if status.success? && !stdout_str.strip.empty?
          audio_stream_url = stdout_str.strip.split("\n").find { |url| url.start_with?('http') }
          unless audio_stream_url
            msg.edit "❌ Não consegui um link de áudio válido de `yt-dlp` para **#{video_title}**."
            puts "ERRO yt-dlp: stdout não continha uma URL HTTP válida. stdout: #{stdout_str}"
            next
          end
        else
          msg.edit "❌ Falha ao obter o link de áudio via `yt-dlp` para **#{video_title}**. Verifique se `yt-dlp` está instalado e funcionando corretamente."
          puts "ERRO yt-dlp: Comando falhou ou stdout vazio. Status: #{status.exitstatus}. Stderr: #{stderr_str}. Stdout: #{stdout_str}"
          next
        end
      rescue Errno::ENOENT # Erro se o comando yt-dlp não for encontrado
        msg.edit "❌ **Erro Crítico:** Comando `yt-dlp` não encontrado. Ele precisa estar instalado e acessível no PATH do sistema para o bot funcionar."
        puts "ERRO CRÍTICO: yt-dlp não encontrado. Verifique a instalação."
        next
      rescue StandardError => e
        msg.edit "❌ Erro inesperado ao tentar usar `yt-dlp` para **#{video_title}**."
        puts "ERRO GERAL yt-dlp: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
        next
      end

      # 5. Tocar a Música
      begin
        voice_client.play_file(audio_stream_url) # ou voice_client.play_stream(audio_stream_url)

      rescue StandardError => e
        msg.edit "☠️ Deu ruim na hora de tocar **#{video_title}**: `#{e.message}`"
        puts "ERRO ao tentar voice_client.play_file: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
      end

      nil # Boa prática para comandos do discordrb
    end
  end
end

# Adiciona este módulo à lista de módulos de música para serem carregados pelo bot principal
if defined?($item_musicais_carregados) && $item_musicais_carregados.is_a?(Array)
  $item_musicais_carregados << MusicCommands::Play
else
  puts "[AVISO do arquivo play_command.rb]: A variável global $music_modules_to_load não está definida como um Array."
  puts "O comando !play pode não ser carregado. Defina $music_modules_to_load = [] no seu script principal."
end