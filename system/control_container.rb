#! ruby -E utf-8

require 'dxruby'
require_relative './module_movable.rb'
require_relative './module_drawable.rb'

###############################################################################
#TSUKASA for DXRuby  α１
#汎用ゲームエンジン「司（TSUKASA）」 for DXRuby
#
#Copyright (c) <2013-2015> <tsukasa TSUCHIYA>
#
#This software is provided 'as-is', without any express or implied
#warranty. In no event will the authors be held liable for any damages
#arising from the use of this software.
#
#Permission is granted to anyone to use this software for any purpose,
#including commercial applications, and to alter it and redistribute it
#freely, subject to the following restrictions:
#
#   1. The origin of this software must not be misrepresented; you must not
#   claim that you wrote the original software. If you use this software
#   in a product, an acknowledgment in the product documentation would be
#   appreciated but is not required.
#
#   2. Altered source versions must be plainly marked as such, and must not be
#   misrepresented as being the original software.
#
#   3. This notice may not be removed or altered from any source
#   distribution.
#
#[The zlib/libpng License http://opensource.org/licenses/Zlib]
###############################################################################

class Control
  @@root = nil        #コントロールツリーのルート
  @@glabal_flag = {}  #グローバルフラグ
  @@procedure_list = Hash.new #プロシージャーのリスト
  @@ailias_list =  Hash.new #エイリアスのリスト

  def initialize(options)
    @x_pos = 0
    @y_pos = 0
    #コントロールのID(省略時は自身のクラス名とする)
    @id = options[:id] || ("Anonymous_" + self.class.name).to_sym

    @command_list = Array.new #コマンドリスト
    @control_list = Array.new #コントロールリスト
    @call_stack = Array.new #コールスタック

    @next_frame_commands =  Array.new  #一時コマンドリスト

    @skip_mode = false #スキップモードの初期化
    @idol_mode = true #待機モードの初期化

    @sleep_mode = :wake #スリープの初期状態を設定する

    @delete_flag = false #削除フラグの初期化
    @visible = options[:visible] || true #Controlの可視フラグ

    #子コントロールをentityに描画するかどうか
    @draw_to_entity = options[:draw_to_entity]
    
    @draw_option = {} #描画オプション

    #コマンドセットがあるなら登録する
    options[:commands].each do |command|
      command_options = command[1] ? command[1].dup : nil
      send_command(command[0], command_options)
    end if options[:commands]

    #スクリプトパスが設定されているなら読み込んで登録する
    if options[:script_path]
      #シナリオファイルの読み込み
#      @script_storage = eval(File.open(options[:script_path], "r:UTF-8").read)
      @script_storage = Tsukasa::ScriptCompiler.new("scenario03.rb")
      @script_storage_call_stack = Array.new #コールスタック
      #初期コマンドの設定
      send_command_interrupt(:take_token, nil)
    end

    #ルートクラスの設定
    @@root = self if !@@root
  end

  #コマンドをスタックに格納する
  def send_command(command, options, id = @id)
    #自身が送信対象として指定されている場合
    if @id == id
      #コマンドをスタックの末端に挿入する
      @command_list.push([command, options])
      return true #コマンドをスタックした
    end

    #子要素に処理を伝搬する
    @control_list.each do |control|
      #子要素がコマンドをスタックした時点でループを抜ける
      return true if control.send_command(command, options, id)
    end

    return false #コマンドをスタックしなかった
  end

  #コマンドをスタックに格納する
  def send_command_interrupt(command, options, id = @id)
    #自身が送信対象として指定されている場合
    if @id == id
      #コマンドをスタックの先頭に挿入する
      @command_list.unshift([command, options])
      return true #コマンドをスタックした
    end

    #子要素に処理を伝搬する
    @control_list.each do |control|
      #子要素がコマンドをスタックした時点でループを抜ける
      return true if control.send_command_interrupt(command, options, id)
    end

    return false #コマンドをスタックしなかった
  end

  #強制的に全てのコントロールにコマンドを設定する
  def send_command_to_all(command, options)
    #自身のidを設定してコマンドを送信する
    send_command(command, options)

    #子要素に処理を伝搬する
    @control_list.each do |control|
      control.send_command_to_all(command, options)
    end
  end

  #強制的に全てのコントロールにコマンドを設定する
  def send_command_interrupt_to_all(command, options)
    #自身のidを設定してコマンドを送信する
    send_command_interrupt(command, options)

    #子要素に処理を伝搬する
    @control_list.each do |control|
      control.send_command_interrupt_to_all(command, options)
    end
  end

  #毎フレームコントロール更新処理
  def update
    #コマンドリストが空で、かつ、コールスタックが空でない場合
    if @command_list.empty? and !@call_stack.empty?
      #コールスタックからネスト元のコマンドセットを取得する
      @command_list = @call_stack.pop
    end

    #待機モードを初期化
    @idol_mode = true

    @next_frame_commands = []

    #コマンドリストが空になるまで走査し、コマンドを実行する
    #TODO:将来的にコマンドは空にはならくなる。
    while !@command_list.empty?
      #コマンドリストの先頭要素を取得
      command, options = @command_list.shift

      #コマンドを実行
      idol, end_parse, command = send("command_" + command.to_s, options)

      #アイドルモードフラグを更新
      @idol_mode &= idol
      #次フレームに実行するコマンドがある場合、一時的にスタックする
      @next_frame_commands.push(command) if command
      #コマンド探査を終了する場合はループを抜ける
      break if end_parse
    end

    #一時的にスタックしていたコマンドをコマンドリストに移す
    @command_list = @next_frame_commands + @command_list

    @control_list.each do |control|
      #各コントロールを更新し、待機モードかどうかの真偽値をANDで集計する
      @idol_mode &= control.update
    end

    #削除フラグが立っているコントロールをリストから削除する
    @control_list.delete_if do |control|
      control.delete?
    end

    #待機モードの状態をツリー最上位まで伝搬させる
    return @idol_mode 
  end

  #描画
  def render(offset_x, offset_y, target, parent_x_end, parent_y_end)

    return target if !@visible

    #子要素のコントロールの描画
    @control_list.each do |entity|
      #所持コントロール自身に描画する場合
      if @draw_to_entity
        #
        entity.render(offset_x, offset_y, @entity, @width, @height)
      else
        entity.render(offset_x + @x_pos, offset_y + @y_pos, target, @width, @height)
      end
    end

    #連結フラグが設定されているなら親コントロールの座標を追加する
    offset_x += parent_x_end if @join_right
    offset_y += parent_y_end if @join_bottom

    #自身が描画要素を持っていれば描画
    target.draw_ex( offset_x + @x_pos, 
                    offset_y + @y_pos, 
                    @entity, 
                    @draw_option) if @entity

    return target #引数を返値に伝搬する
  end

  def get_child(id)
    #自身が送信対象として指定されている場合
    return self if @id == id

    #子要素に処理を伝搬する
    @control_list.each do |control|
      result = control.get_child(id)
      return result if result
    end

    return nil
  end

  #全てのコントロールが待機モードになっているかを返す。
  def all_controls_idol?
    return @idol_mode
  end

  #コントロールを削除して良いかどうか
  def delete?
    return @delete_flag
  end

  #リソースを解放する
  #継承先で必要に応じてオーバーライドする
  def dispose
    @delete_flag = true

    #子要素に処理を伝搬する
    @control_list.each do |control|
      control.dispose
    end
  end

  #############################################################################
  #非公開インターフェイス
  #############################################################################

  private

  #############################################################################
  #スクリプト処理コマンド
  #############################################################################

  #コントロールをリストに登録する
  def command_create(options)
    #指定されたコントロールを生成してリストに連結する
    @control_list.push(Module.const_get(options[:create]).new(options))
    return false  #フレーム続行
  end

  #スクリプトストレージから取得したコマンドをコントロールツリーに送信する
  def command_take_token(options)

    #コマンドストレージが空の場合
    if @script_storage.empty?
      #コマンドストレージのコールスタックも空であればループを抜ける
      return false if @script_storage_call_stack.empty?
      #コールスタックからコマンドストレージをポップする
      @script_storage = @script_storage_call_stack.pop
    end

    #コマンドを取り出す
    command,options  = @script_storage.shift

    #コマンドがプロシージャーリストに登録されている場合
    if @@procedure_list.key?(command)
      #プロシージャー名をオプションに格納する
      options[:procedure] = command
      options[:target_control] = @id
      #発行するコマンドをプロシージャー呼び出しに差し替える
      command = :call_procedure
    end

    #コマンドがエイリアスリストに登録されている場合
    if @@ailias_list.key?(command)
      @script_storage_call_stack.push(@script_storage)
      #コマンドリストをクリアする
      @script_storage = @@ailias_list[command].dup
      #コマンドを取り出す
      command,options  = @script_storage.shift
    end

    #コマンドをコントロールに登録する
    if !send_command(command,options,options[:target_control]) then
      pp "error"
      pp command
      pp options
#      pp @control_list
      pp options[:target_control]
      pp "commandは、伝搬先が見つかりませんでした"
      raise
    end

    return false, false,[:take_token, nil]  #コマンド探査終了
  end

  #文字列を評価する（デバッグ用）
  def command_eval(options)
    eval(options[:eval])
    return false #フレーム続行
  end

  #############################################################################
  #タイミング制御コマンド
  #############################################################################

  #強制的に１フレーム進めるコマンド
  def command_next_frame(options)
    return true, true #コマンド探査の終了
  end

  def command_pause(options)
    #※ページスキップ的な機能が実装されたら、このへんでその処理を行う筈
  
    #rootクラスをスリープさせる
    @@root.send_command_interrupt(:sleep, nil)
    #アイドル待機、キー入力待機のコマンドを逆順にスタックする
    send_command_interrupt(:wait_input_key, nil)
    send_command_interrupt(:wait_child_controls_idol, nil)
    return true, true #コマンド探査の終了
  end

  #wait_commandコマンド
  #特定のコマンドが自身より前に存在し続ける限り待機を続ける
  def command_wait_command(options)
    if @next_frame_commands.index{|command| 
          command[0] == options[:wait_command]
       }
      #自分自身をスタックし、コマンド探査を終了する
      return true, true, [:wait_command, options]
    else
      return false #コマンド探査の続行
    end
  end

  #キー入力を待つ
  def command_wait(options)
    #スキップモードであれば直ちに終了し、フレームを続行する
    return true if @skip_mode

    #キー押下があればスキップモードに移行する
    if Input.key_push?(K_SPACE)
      @skip_mode = true
      return true
    end

    #待ちフレーム数を取得。設定されていない場合はコンフィグから初期値を取得する
    wait_frame =  options[:wait_frame] == :unset_wait_frame ?
                  @style_config[:wait_frame] :
                  options[:wait_frame]

    #残りwaitフレーム数が０より大きい場合
    if 0 < wait_frame
      #残りwaitフレーム数をデクリメントし、:waitコマンドを再度スタックする
      return true, true, [:wait, {:wait_frame => wait_frame - 1}] #リスト探査終了
    end

    return true #リスト探査続行
  end

  #sleepコマンド
  #スリープ状態を開始する
  def command_sleep(options)
    #覚醒待機状態へ移行
    send_command_interrupt(:wait_wake, nil)
    @sleep_mode = :sleep #スリープ状態
    return true #コマンド探査の続行
  end

  #wait_wake
  #覚醒待機状態
  def command_wait_wake(options)
    if @sleep_mode == :sleep
      return true, true, [:wait_wake, nil] #リスト探査終了
    end
    return true, true #リスト探査続行
  end

  #wait_child_controls_idolコマンド
  #子要素のコントロールが全てアイドルになるまで待機
  def command_wait_child_controls_idol(options)
    if !all_controls_idol?
      return true, true, [:wait_child_controls_idol, nil] #リスト探査終了
    end
    return true #リスト探査続行
  end

  def command_wait_input_key(options)
    #子要素のコントロールが全てアイドル状態の時にキーが押された場合
    if Input.key_push?(K_SPACE)
      #スリープモードを解除する
      @@root.send_command_interrupt_to_all(:wake, nil)
      #キー入力が伝搬すると不味いので次フレームに進める
      return true, true #フレーム終了
    else
      #ポーズ状態を続行する
      return true, true, [:wait_input_key, options] #リスト探査終了
    end
  end

  def command_wake(options)
    #スリープ状態を解除
    @sleep_mode = :wake
    @skip_mode = false
    return true #リスト探査続行
  end

  #############################################################################
  #制御構文コマンド
  #############################################################################

  #条件分岐
  def command_if(options)
    #evalで評価した条件式が真の場合
    if eval(options[:if])
      #現在のコマンドセットをコールスタックにプッシュ
      @call_stack.push(@command_list)
      #現在のスクリプトストレージをコールスタックにプッシュ
      @script_storage_call_stack.push(@script_storage) if !@script_storage.empty?
      #コマンドリストをクリアする
      @script_storage = options[:then].dup
    #else節がある場合
    elsif options[:else]
      #現在のコマンドセットをコールスタックにプッシュ
      @call_stack.push(@command_list)
      #現在のスクリプトストレージをコールスタックにプッシュ
      @script_storage_call_stack.push(@script_storage) if !@script_storage.empty?
      #コマンドリストをクリアする
      @script_storage = options[:else].dup
    end
    return false #フレーム続行
  end

  #繰り返し
  def command_while(options)
    #evalで評価した条件式が真の場合
    if eval(options[:while])
      #whileコマンドをスタックする
      send_command_interrupt(:while, options)
      #現在のコマンドセットをコールスタックにプッシュ
      @call_stack.push(@command_list)
      #then節を新たなコマンドセットとする
      @command_list = options[:commands].dup
    end
    return false #フレーム続行
  end

  #繰り返し
  def command_while2(options)
    #条件式が非成立であればループを終了する
    return false if !eval(options[:while2])

    #一時変数の初期化
    if !options[:rag_command] or options[:rag_command].empty?
      options[:rag_command] = options[:commands].shift
      options[:commands].push(options[:rag_command].dup)
    end
    
    inner_command = options[:rag_command][0]
    inner_options = options[:rag_command][1].dup
    options[:rag_command] = nil

    #キープの中のコマンドを実行する
    idol, end_parse, inner_command = send("command_" + inner_command.to_s, inner_options)

    #コマンドが返ってきたらそれをキープに保存する
    options[:rag_command] = inner_command if inner_command

    #ループ自体を返す
    return idol, end_parse, [:while2, options] #コマンド探査続行
  end

  #############################################################################
  #スタック操作関連
  #############################################################################

  #プロシージャーを登録する
  def command_procedure(options)
    @@procedure_list[options[:procedure]] = options[:impl]
    return false #リスト探査続行
  end

  #プロシージャーコールを実行する
  def command_call_procedure(options)
    #現在のコマンドリストをスタック
    @call_stack.push(@command_list)
    #プロシージャの中身をevalでコマンドセット化してコマンドリストに登録する
    @command_list = eval(@@procedure_list[options[:procedure]])
    return false #リスト探査続行
  end

  #プロシージャーを登録する
  def command_ailias(options)
    @@ailias_list[options[:ailias]] = options[:commands]

    return false #リスト探査続行
  end

  #############################################################################
  #ヘルパーメソッド
  #############################################################################

  #文字列をbool型に変換
  def object_to_boolean(value)
    return [true, "true", 1, "1", "T", "t"].include?(value.class == String ? value.downcase : value)
  end

  #"RRGGBB"の１６進数６桁カラー指定を、[R,G,B]の配列に変換
  def hex_to_rgb(target)
    return target if target.class == Array
    [target[0, 2].hex, target[2, 2].hex, target[4, 2].hex]
  end

  #タグの必須属性の有無をチェックし、無ければtrueを返す
  def check_exist(target, *attributes)
    if !target
      puts "オプションが空です"
      return true
    end
    attributes.each do |attribute|
      if !target.key?(attribute)
        puts "属性値\"#{attribute.to_s}\"は必須です"
        return true
      end
    end
    return false
  end
end