#! ruby -E utf-8

require 'dxruby'

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

#クリックイベントが発生するコントロールの基底クラス
module Clickable

  attr_reader  :colorkey_file_path
  def colorkey_file_path=(colorkey_file_path)
    @colorkey_file_path = colorkey_file_path
    @colorkey_entity = Image.load(colorkey_file_path)
  end

  attr_accessor  :collision_shape
  attr_accessor  :colorkey_border

  def initialize(options, inner_options, root_control)
    super
    @collision_shape = options[:collision_shape]

    self.colorkey_file_path = options[:colorkey_file_path] if options[:colorkey_file_path]
    @colorkey_border = options[:colorkey_border] || 255

    @collision_sprite = Sprite.new
    if @collision_shape
      @collision_sprite.collision = @collision_shape
    else
      @collision_sprite.collision = [0, 0, @width-1, @height-1]
    end

    @mouse_sprite = Sprite.new
    @mouse_sprite.collision = [0, 0]

    @over = false
    @out = true

  end

  def update()
    @on_mouse_over  = false
    @on_mouse_out   = false
    @on_key_down    = false
    @on_key_down_out= false
    @on_key_up      = false
    @on_key_up_out  = false

    #マウスカーソル座標を取得
    @x = Input.mouse_pos_x
    @y = Input.mouse_pos_y

    @collision_sprite.x = @x_pos 
    @collision_sprite.y = @y_pos
    @mouse_sprite.x = @x
    @mouse_sprite.y = @y

    #描画範囲内かどうか
    if (@mouse_sprite === @collision_sprite)
      if @colorkey_entity
        if @colorkey_entity[@x - @x_pos, @y - @y_pos][0] >= @colorkey_border
          inner_control = true
        else
          inner_control = false
        end
      else
        inner_control = true
      end
    else
      inner_control = false
    end
    
    if inner_control
      #イベント起動済みフラグクリア
      @out = false

      #イベント起動前であれば起動し、クリアフラグを立てる
      @on_mouse_over = true unless @over
      @over = true

      #キー押下チェック
      if Input.mouse_push?( M_LBUTTON )
        @on_key_down = true
      end

      #キー解除チェック
      if Input.mouse_release?( M_LBUTTON )
        @on_key_up = true
      end
    else
      #イベント起動済みフラグクリア
      @over = false

      #イベント起動前であれば起動し、クリアフラグを立てる
      @on_mouse_out = true unless @out
      @out = true

      #キー押下チェック
      if Input.mouse_push?( M_LBUTTON )
        @on_key_down_out = true
      end

      #キー解除チェック
      if Input.mouse_release?( M_LBUTTON )
        @on_key_up_out = true
      end
    end

    super
  end

  def command_on_mouse_over(options, inner_options)
    #カーソルが指定範囲に侵入した場合
    if @on_mouse_over
      eval_block(options, inner_options[:block_stack], &inner_options[:block])
    end
    push_command_to_next_frame(:on_mouse_over, options, inner_options)
  end
  
  def command_on_mouse_out(options, inner_options)
    #カーソルが指定範囲の外に移動した場合
    if @on_mouse_out
      eval_block(options, inner_options[:block_stack], &inner_options[:block])
    end
    push_command_to_next_frame(:on_mouse_out, options, inner_options)
  end

  def command_on_key_down(options, inner_options)
    #マウスボタンが押下された場合
    if @on_key_down
      eval_block(options, inner_options[:block_stack], &inner_options[:block])
    end
    push_command_to_next_frame(:on_key_down, options, inner_options)
  end

  def command_on_key_down_out(options, inner_options)
    #マウスボタンが範囲外で押下された場合
    if @on_key_down_out
      eval_block(options, inner_options[:block_stack], &inner_options[:block])
    end
    push_command_to_next_frame(:on_key_down_out, options, inner_options)
  end

  def command_on_key_up(options, inner_options)
    #マウスボタン押下が解除された場合
    if @on_key_up
      eval_block(options, inner_options[:block_stack], &inner_options[:block])
    end
    push_command_to_next_frame(:on_key_up, options, inner_options)
  end

  def command_on_key_up_out(options, inner_options)
    #マウスボタン押下が範囲外で解除された場合
    if @on_key_up_out
      eval_block(options, inner_options[:block_stack], &inner_options[:block])
    end
    push_command_to_next_frame(:on_key_up_out, options, inner_options)
  end
end
