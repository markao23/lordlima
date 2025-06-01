# frozen_string_literal: true

module ComandosDeMusica
  module Entrar
    extend Discordrb::Commands::CommandContainer
    command(:join, description: 'Faz o bot entrar em uma canal de vos') do |event|
      usuario = event.user
      canal_de_voz_do_usuario = usuario.voice_channel

      puts "--- Comando !join acionado ---"
      puts "Usuário que chamou: #{usuario.name} (ID: #{usuario.id})"


      if canal_de_voz_do_usuario.nil?
        puts "DEBUG: Usuário NÃO está em um canal de voz."
        event.respond "Ei, #{usuario.mention}, você precisa estar em um canal de voz para eu poder entrar! 😉"
        next # Interrompe o comando aqui
      end

      puts "DEBUG: Canal de voz do usuário detectado:"
      puts "  Nome do Canal: #{canal_de_voz_do_usuario.name}"
      puts "  ID do Canal: #{canal_de_voz_do_usuario.id}"
      puts "  Tipo do Canal: #{canal_de_voz_do_usuario.type} (Esperado: 2 para voz)" # Canais de voz normais são tipo 2
      puts "  Servidor do Canal: #{canal_de_voz_do_usuario.server.name} (ID: #{canal_de_voz_do_usuario.server.id})"

      conexao_canal = event.voice

      if conexao_canal && conexao_canal == canal_de_voz
        puts "DEBUG: Bot já está no canal de voz do usuário."
        event.respond "Eu já estou aqui com você no canal `#{canal_de_voz_do_usuario.name}`, #{usuario.mention}! 🎉"
        next
      end
      begin
        event.bot.voice_connect(canal_de_voz_do_usuario)
        event.respond "Cheguei no canal `#{canal_de_voz_do_usuario.name}`! E aí, #{usuario.mention}? 🎙️"
      rescue Discordrb::Errors::NoPermission
        event.respond "Poxa, #{usuario.mention}, parece que não tenho permissão para entrar no canal `#{canal_de_voz.name}`. 😥 Poderia verificar minhas permissões?"
      rescue StandardError => e
        puts "!! ERRO ao tentar entrar no canal de voz: #{e.message}"
        puts e.backtrace.join("\n") # Isso mostra detalhes do erro no console do bot
        event.respond "Ih, #{usuario.mention}, deu algum ruim aqui e não consegui entrar no canal. 😕 Tenta de novo ou avisa o meu dono!"
      end
      nil
    end
  end
end
if defined?($item_musicais_carregados) && $item_musicais_carregados.is_a?(Array)
  $item_musicais_carregados << ComandosDeMusica::Entrar
else
  # Aviso se a variável global não estiver configurada como esperado
  puts "[AVISO do arquivo 'entrar_canal.rb']: A variável global $music_modules_to_load não foi encontrada ou não é uma Array."
  puts "O comando !join pode não ser carregado corretamente. Verifique seu script principal do bot."
  puts "Você precisa ter algo como '$music_modules_to_load = []' antes de carregar os módulos."
end