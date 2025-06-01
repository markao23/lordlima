# frozen_string_literal: true

require 'discordrb'
require 'chunky_png' # Para gerar a imagem do tabuleiro
require 'tempfile'   # Para lidar com arquivos temporários para a imagem

module TicTacToeCommands
  extend Discordrb::Commands::CommandContainer

  # Armazena os jogos ativos. Chave: ID do canal, Valor: objeto GameState
  # Este é um armazenamento simples em memória.
  @active_games = {}

  # Classe para guardar o estado de cada jogo
  class GameState
    attr_accessor :player1, :player2, :board, :current_turn_player,
                  :player1_symbol, :player2_symbol, :game_phase,
                  :po_choice, :po_player1_num

    def initialize(player1, player2)
      @player1 = player1 # Objeto Discordrb::User
      @player2 = player2 # Objeto Discordrb::User
      @board = Array.new(3) { Array.new(3, ' ') } # Tabuleiro 3x3 vazio
      @current_turn_player = nil
      @player1_symbol = nil
      @player2_symbol = nil
      # Fases: :par_ou_impar_choice, :par_ou_impar_number, :tic_tac_toe
      @game_phase = :par_ou_impar_choice
      @po_choice = nil # 'par' ou 'impar'
      @po_player1_num = nil
    end
  end

  # --- Funções Auxiliares ---

  def self.generate_board_image(board_array)
    img_size = 150 # Tamanho da imagem em pixels
    cell_size = img_size / 3
    line_color = ChunkyPNG::Color::BLACK
    bg_color = ChunkyPNG::Color::WHITE
    o_color = ChunkyPNG::Color.rgb(0, 0, 255) # Azul para 'O' (Bolinha)
    x_color = ChunkyPNG::Color.rgb(255, 0, 0) # Vermelho para 'X'
    line_thickness = 2 # Espessura das linhas do 'X' e do círculo
    png = ChunkyPNG::Image.new(img_size, img_size, bg_color)

    # Desenha as linhas do grid
    (1..2).each do |i|
      png.line(0, i * cell_size, img_size - 1, i * cell_size, line_color) # Horizontal
      png.line(i * cell_size, 0, i * cell_size, img_size - 1, line_color) # Vertical
    end

    board_array.each_with_index do |row, r_idx|
      row.each_with_index do |cell, c_idx|
        center_x = c_idx * cell_size + cell_size / 2
        center_y = r_idx * cell_size + cell_size / 2
        radius = cell_size / 3

        case cell
        when 'O' # Bolinha
          (0..line_thickness).each do |offset| # Desenha círculo com espessura
            png.circle(center_x, center_y, radius - offset, o_color)
          end
        when 'X'
          # Desenha X com alguma espessura (aproximada por múltiplas linhas)
          (-line_thickness/2..line_thickness/2).each do |offset_diag|
            png.line(center_x - radius + offset_diag, center_y - radius, center_x + radius + offset_diag, center_y + radius, x_color)
            png.line(center_x + radius + offset_diag, center_y - radius, center_x - radius + offset_diag, center_y + radius, x_color)
          end
        end
      end
    end
    png
  end

  def self.check_winner(board, symbol)
    # Checar linhas
    board.any? { |row| row.all?(symbol) } ||
      # Checar colunas
      (0..2).any? { |col_idx| board.all? { |row| row[col_idx] == symbol } } ||
      # Checar diagonais
      (board[0][0] == symbol && board[1][1] == symbol && board[2][2] == symbol) ||
      (board[0][2] == symbol && board[1][1] == symbol && board[2][0] == symbol)
  end

  def self.board_full?(board)
    board.all? { |row| row.all? { |cell| cell != ' ' } }
  end

  # --- Lógica Principal do Jogo (dentro de `play_tic_tac_toe`) ---
  def self.play_tic_tac_toe(event_or_channel, game)
    # event_or_channel pode ser o evento original ou o canal diretamente
    channel = event_or_channel.respond_to?(:channel) ? event_or_channel.channel : event_or_channel

    # 1. Gera e envia a imagem do tabuleiro
    board_image = generate_board_image(game.board)
    current_player_actual = game.current_turn_player
    current_symbol_actual = (current_player_actual == game.player1) ? game.player1_symbol : game.player2_symbol

    caption = "É a vez de #{current_player_actual.mention} (#{current_symbol_actual}).\n" \
      "Use `!marcar <posição>` (1-9, da esquerda para direita, de cima para baixo)."

    temp_file = Tempfile.new(['tic_tac_toe_board', '.png'])
    begin
      board_image.save(temp_file.path)
      channel.send_file(File.open(temp_file.path, 'r'), caption: caption)
    ensure
      temp_file.close
      temp_file.unlink # Garante que o arquivo temporário seja deletado
    end

    channel.await!(timeout: 120) do |move_event| # Timeout de 2 minutos
      active_game_check = @active_games[channel.id]
      next true unless active_game_check && active_game_check == game && move_event.author == current_player_actual

      msg_content = move_event.message.content.downcase
      if msg_content.start_with?("!marcar ")
        position_str = msg_content.split(" ", 2)[1]
        begin
          position = Integer(position_str)
          unless (1..9).cover?(position)
            move_event.respond "Posição inválida, #{current_player_actual.mention}. Escolha um número de 1 a 9."
            next false # Continua aguardando
          end

          row = (position - 1) / 3
          col = (position - 1) % 3

          if game.board[row][col] == ' '
            game.board[row][col] = current_symbol_actual

            # Checa vitória
            if check_winner(game.board, current_symbol_actual)
              final_board_image = generate_board_image(game.board)
              Tempfile.open(['ttt_final', '.png']) do |f|
                final_board_image.save(f.path)
                channel.send_file(File.open(f.path, 'r'), caption: "**#{current_player_actual.mention} (#{current_symbol_actual}) venceu o jogo!** 🎉")
              end
              @active_games.delete(channel.id)
              next true # Para de aguardar, jogo terminou
              # Checa empate
            elsif board_full?(game.board)
              final_board_image = generate_board_image(game.board)
              Tempfile.open(['ttt_final', '.png']) do |f|
                final_board_image.save(f.path)
                channel.send_file(File.open(f.path, 'r'), caption: "**Deu velha! O jogo empatou.** 😐")
              end
              @active_games.delete(channel.id)
              next true # Para de aguardar, jogo terminou
              # Continua o jogo
            else
              game.current_turn_player = (current_player_actual == game.player1) ? game.player2 : game.player1
              play_tic_tac_toe(channel, game) # Chama recursivamente para o próximo turno
              next true # Para este await, pois um novo será criado na chamada recursiva
            end
          else
            move_event.respond "Essa posição já está ocupada, #{current_player_actual.mention}! Escolha outra."
            next false # Continua aguardando
          end
        rescue ArgumentError
          move_event.respond "Entrada inválida para posição, #{current_player_actual.mention}. Use `!marcar <1-9>`."
          next false # Continua aguardando
        end
      else
        next false
      end
    end # Fim do await para jogada

    if @active_games[channel.id] == game # Verifica se o jogo ainda existe e é o mesmo
      channel.send_message("#{current_player_actual.mention} demorou demais para jogar. Jogo encerrado. ⏳")
      @active_games.delete(channel.id)
    end
  end

  command :jogar do |event, mention|
    channel_id = event.channel.id
    if @active_games[channel_id]
      event.respond "Já existe um jogo da velha em andamento neste canal. Use `!cancelarjogo` se quiser encerrá-lo."
      next
    end

    player1 = event.author
    if mention.nil?
      event.respond "Por favor, mencione um usuário para jogar contra. Ex: `!jogar @oponente`"
      next
    end

    player2_id_match = mention.match(/<@!?(\d+)>/)
    unless player2_id_match
      event.respond "Menção inválida. Por favor, mencione um usuário corretamente."
      next
    end
    player2_id = player2_id_match[1]

    player2 = event.server&.member(player2_id) # &.member para evitar erro se event.server for nil (DM)
    if player2.nil? || player2.bot_account?
      event.respond "Não é possível jogar com este usuário (não encontrado, é um bot, ou estamos em DM e não consigo vê-lo)."
      next
    end

    if player1.id == player2.id
      event.respond "Você não pode jogar contra si mesmo! Chame um amigo. 😉"
      next
    end

    # Cria um novo estado de jogo
    current_game = GameState.new(player1, player2)
    @active_games[channel_id] = current_game

    event.respond "**Jogo da Velha Iniciado: #{player1.mention} vs #{player2.mention}!**\n" \
                    "Primeiro, vamos decidir quem começa com 'O' (bolinha) no par ou ímpar.\n" \
                    "#{player1.mention}, você escolhe **par** ou **ímpar**? Responda com `!escolha par` ou `!escolha impar` em 60 segundos."

    par_impar_choice_made = false
    event.channel.await!(timeout: 60) do |choice_event|
      next true unless choice_event.author == player1 && @active_games[channel_id] == current_game

      input = choice_event.message.content.downcase
      if input == '!escolha par'
        current_game.po_choice = 'par'
        par_impar_choice_made = true
        true
      elsif input == '!escolha impar'
        current_game.po_choice = 'impar'
        par_impar_choice_made = true
        true
      else
        choice_event.respond "#{player1.mention}, resposta inválida. Use `!escolha par` ou `!escolha impar`."
        false # Continua aguardando
      end
    end

    unless par_impar_choice_made # Timeout ou jogo cancelado
      if @active_games[channel_id] == current_game # Se o jogo não foi cancelado por outro motivo
        event.respond "#{player1.mention} não escolheu par ou ímpar a tempo. Jogo cancelado. 😕"
        @active_games.delete(channel_id)
      end
      next
    end

    event.respond "#{player1.mention} escolheu **#{current_game.po_choice}**. Agora, por favor, #{player1.mention}, envie seu número (de 0 a 10) com `!numero <seu número>` em 60 segundos."

    player1_number_sent = false
    event.channel.await!(timeout: 60) do |number_event|
      next true unless number_event.author == player1 && @active_games[channel_id] == current_game

      if number_event.message.content.downcase.start_with?('!numero ')
        begin
          num_str = number_event.message.content.downcase.split(' ', 2)[1]
          chosen_num = Integer(num_str)
          if (0..10).cover?(chosen_num) # Validando o intervalo do número
            current_game.po_player1_num = chosen_num
            player1_number_sent = true
            true
          else
            number_event.respond "#{player1.mention}, número inválido. Escolha um número entre 0 e 10."
            false
          end
        rescue ArgumentError
          number_event.respond "#{player1.mention}, entrada inválida. Use `!numero <seu número>`."
          false
        end
      else
        false # Não é o comando esperado, continua aguardando
      end
    end

    unless player1_number_sent # Timeout ou jogo cancelado
      if @active_games[channel_id] == current_game
        event.respond "#{player1.mention} não enviou o número a tempo. Jogo cancelado. 😕"
        @active_games.delete(channel_id)
      end
      next
    end

    # Bot escolhe um número
    bot_number = rand(0..10)
    total_sum = current_game.po_player1_num + bot_number
    result_is_par = total_sum.even?

    event.respond "#{player1.mention} escolheu o número **#{current_game.po_player1_num}**.\n" \
                    "Eu (bot) escolhi o número **#{bot_number}** para o #{player2.mention} (simbolicamente).\n" \
                    "A soma é **#{total_sum}**, que é **#{result_is_par ? 'PAR' : 'ÍMPAR'}**."

    player1_won_po = (current_game.po_choice == 'par' && result_is_par) || (current_game.po_choice == 'impar' && !result_is_par)

    if player1_won_po
      current_game.current_turn_player = player1
      starter_player = player1
      current_game.player1_symbol = 'O' # Player1 começa com Bolinha
      current_game.player2_symbol = 'X'
    else
      current_game.current_turn_player = player2
      starter_player = player2
      current_game.player1_symbol = 'X'
      current_game.player2_symbol = 'O' # Player2 começa com Bolinha
    end
    event.respond "**#{starter_player.mention} ganhou no par ou ímpar e começa o Jogo da Velha com '#{starter_player == current_game.player1 ? current_game.player1_symbol : current_game.player2_symbol}' (Bolinha)!**"
    current_game.game_phase = :tic_tac_toe
    play_tic_tac_toe(event, current_game) # Inicia o loop do jogo da velha
    nil # O comando principal retorna, o jogo continua nos awaits
  end

  command :cancelarjogo do |event|
    channel_id = event.channel.id
    game_to_cancel = @active_games[channel_id]

    if game_to_cancel
      if event.author == game_to_cancel.player1 || event.author == game_to_cancel.player2 || event.user.permission?(:manage_messages)
        @active_games.delete(channel_id)
        event.respond "Jogo da velha cancelado neste canal."
      else
        event.respond "Apenas os jogadores envolvidos ou alguém com permissão para gerenciar mensagens podem cancelar este jogo."
      end
    else
      event.respond "Nenhum jogo da velha em andamento neste canal para cancelar."
    end
    end
  command :regras do |event|
    regras = <<~RULES
    **Como Jogar o Jogo da Velha do Bot** 🎲

      1️⃣ **Para Começar um Jogo:**
         Use `!jogar @oponente` mencionando o amigo com quem você quer jogar.

      2️⃣ **Decidindo Quem Começa (Par ou Ímpar):**
         * O jogador que iniciou o jogo (`!jogar`) será perguntado se escolhe "par" ou "ímpar".
           Responda com `!escolha par` ou `!escolha impar`.
         * Depois, esse mesmo jogador deve enviar um número (de 0 a 10) usando `!numero <seu número>`.
         * O bot também escolherá um número. A soma dos dois números decide o vencedor do par ou ímpar.
         * Quem ganhar no par ou ímpar começa o Jogo da Velha com 'O' (Bolinha). O outro jogador usará 'X'.

      3️⃣ **Objetivo do Jogo da Velha:**
         Conseguir 3 dos seus símbolos ('O' ou 'X') em uma linha reta:
         * Horizontalmente (---)
         * Verticalmente (|)
         * Diagonalmente (\\ ou /)

      4️⃣ **Fazendo sua Jogada:**
         * Quando for a sua vez, o bot mostrará o tabuleiro e dirá para você jogar.
         * Use o comando `!marcar <posição>` para colocar seu símbolo.
         * `<posição>` é um número de 1 a 9, correspondente às casas do tabuleiro:

           ```
           1 | 2 | 3
           --|---|--
           4 | 5 | 6
           --|---|--
           7 | 8 | 9
           ```
         * Por exemplo, `!marcar 5` coloca seu símbolo no centro do tabuleiro.

      5️⃣ **Fim de Jogo:**
         * O jogo termina quando um jogador consegue 3 símbolos em linha, ou quando todas as casas são preenchidas (empate/velha).

      6️⃣ **Cancelar um Jogo:**
         * Se precisar parar um jogo em andamento no canal, use `!cancelarjogo`. (Apenas jogadores ou admins podem cancelar).

      Divirta-se! 😄
    RULES
    event.respond regras
  end
end

$command_module_to_load << TicTacToeCommands