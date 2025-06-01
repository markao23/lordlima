# frozen_string_literal: true

require 'discordrb'
require 'dotenv/load'

$command_module_to_load = []
$item_musicais_carregados = []
$playlist = {}
$active_playlist_name = nil

token = ENV['TOKEN']
prefix = '!'

bot = Discordrb::Commands::CommandBot.new(
  token: token,
  prefix: prefix,
)

puts "Bot convidado para o servidor! URL de convite: #{bot.invite_url}"
puts "Bot está rodando. Pressione Ctrl+C para parar."

puts "LOG: Procurando arquivos em 'music/*.rb'..."
if Dir.exist?("commands/music")
  puts "LOG: Pasta 'music' encontrada."
  arquivos_musica_encontrados = Dir.glob("commands/music/*.rb")

  if arquivos_musica_encontrados.empty?
    puts "LOG: Nenhum arquivo .rb encontrado dentro da pasta 'music/'."
  else
    puts "LOG: Arquivos .rb encontrados em 'music/': #{arquivos_musica_encontrados.join(', ')}"
    arquivos_musica_encontrados.each do |arquivo_musica|
      puts "LOG: Processando arquivo: #{arquivo_musica}"
      begin
        load arquivo_musica # Este arquivo DEVE adicionar seu módulo a $music_modules_to_load
        # A linha abaixo é crucial para depuração:
        puts "LOG:   ✅ Arquivo '#{arquivo_musica}' carregado. $music_modules_to_load agora: #{$music_modules_to_load.inspect}"
      rescue StandardError => e
        puts "LOG:   ❌ ERRO ao carregar o arquivo '#{arquivo_musica}': #{e.message}"
        puts "LOG:      Detalhes do erro: #{e.backtrace.first(3).join("\n                        ")}"
      end
    end
  end
else
  puts "LOG: ERRO CRÍTICO - Pasta 'music' NÃO encontrada no diretório atual!"
  puts "LOG: Verifique se a pasta 'music' existe onde o bot está sendo executado (onde está seu script principal)."
end

# 3. SÓ AGORA, VERIFICA e INCLUI os módulos de música no bot
puts "LOG: Verificando $music_modules_to_load ANTES de tentar incluir no bot: #{$item_musicais_carregados.inspect}"
if $item_musicais_carregados.empty?
  # Esta é a mensagem que você está vendo
  puts "   🤔 Nenhum módulo de música foi encontrado na lista '$music_modules_to_load'."
  puts "      Verifique se os arquivos em 'music/*.rb' estão corretamente adicionando os módulos à lista."
  puts "      Por exemplo, usando: $music_modules_to_load << SeuModuloDeComandoDeMusica"
else
  puts "\n   ➕ Incluindo módulos de música no bot:"
  $item_musicais_carregados.each do |modulo_musica|
    begin
      # ... (código para bot.include!(modulo_musica) com verificações, como no exemplo anterior) ...
      if defined?(bot) && bot && modulo_musica.is_a?(Module)
        bot.include!(modulo_musica)
        puts "LOG: ✅ Módulo '#{modulo_musica}' incluído com sucesso no bot!"
      else
        puts "LOG: ⚠️ AVISO: Não foi possível incluir '#{modulo_musica}'. Bot definido? É um módulo?"
      end
    rescue StandardError => e
      puts "LOG:   ❌ ERRO ao incluir o módulo '#{modulo_musica}': #{e.message}"
    end
  end
end
puts "LOG: Carregamento de comandos de música finalizado."

Dir.glob("commands/*.rb").each do |file|
  begin
    load file
    puts " -> Comando do arquivo '#{file}' carregado"
  rescue StandardError => e
    puts " -> ERRO ao carregar o arquivo de comando '#{file}': #{e}"
    puts e.backtrace.join("\n")
  end
end
if $command_module_to_load.empty?
  puts "Nenhum módulo de comando encontrado em $command_modules_to_load."
else
  $command_module_to_load.each do |mod|
    begin
      bot.include!(mod)
      puts "Módulo de comando '#{mod}' incluído com sucesso!"
    rescue StandardError => e
      puts "ERRO ao incluir o módulo '#{mod}': #{e}"
      puts e.backtrace.join("\n")
    end
  end
end
puts "Todos os comandos foram processados."

bot.ready do
  puts "Bot conectado e pronto!"
  puts "URL de convite: #{bot.invite_url}"
end

bot.run