require 'curses'
require 'logger'
require 'set'
include Curses

log_file = File.open('snake.log', 'w')
LOGGER = Logger.new(log_file)

FRAME_LATENCY_SEC = 0.12

DIRECTIONS = [
  Key::UP,
  Key::DOWN,
  Key::LEFT,
  Key::RIGHT,
]

BLOCK = "██"

class Point
  attr_accessor :x, :y
  def initialize(x, y)
    @x = x
    @y = y
  end

  def ==(o)
    @x == o.x && @y == o.y
  end

  def hash
    31 * @x ^ @y
  end
end

class Grid
  def initialize
    init_screen
    curs_set(0)  # Invisible cursor
    noecho       # don't echo input


    box_height, box_width = 12, 20
    top, left = (lines - box_height) / 2, (cols - box_width) / 2

    # create a Window for the box/walls around the game grid
    @grid_box = Window.new(box_height, box_width, top, left)
    @grid_box.box("|", "-")
    @grid_box.refresh

    # create an inner Window where the player moves the snake
    @grid_height = box_height - 2
    @grid_width = box_width - 2
    @grid = Window.new(@grid_height, @grid_width, top + 1, left + 1)
    @grid.keypad(true)   # accept Window::getch input of the Key format
    @grid.nodelay = true # don't block on Window::getch

    if has_colors?
      start_color
      init_pair(COLOR_GREEN, COLOR_GREEN, COLOR_BLACK)
      init_pair(COLOR_RED, COLOR_RED, COLOR_BLACK)
      init_pair(COLOR_BLACK, COLOR_WHITE, COLOR_BLACK)
      # TODO: why are fg/bg colors not getting set?
      attrset(Curses.color_pair(COLOR_BLACK))
    end

    @grid.refresh
  end

  def draw(pellet_pos, snake)
    @grid.clear
    @grid.setpos(pellet_pos.x, pellet_pos.y)
    @grid.attron(color_pair(COLOR_RED)) { @grid << BLOCK }

    snake.each do |pos|
      @grid.setpos(pos.x, pos.y)
      @grid.attron(color_pair(COLOR_GREEN)) { @grid << BLOCK }
    end
    @grid.refresh
  end

  def getch
    @grid.getch
  end

  def rand_pos(taken_points = [])
    unless @possible_points
      possible_heights = (0...@grid_height).step(2).to_a
      possible_widths = (0...@grid_width).step(2).to_a

      @possible_points = possible_heights.product(possible_widths).map { |x, y| Point.new(x, y) }
    end
    available_points = @possible_points.reject { |pos| taken_points.include?(pos) }

    available_points.sample
  end

  def in_bounds(pos)
    pos.x >= 0 && pos.x < @grid_height && pos.y >= 0 && pos.y < @grid_width
  end

  def close
    @grid.close
    @grid_box.close
    close_screen
  end
end

def snake_collision(snake)
  snake[1..-1].include?(snake.first)
end

begin
  grid = Grid.new
  pellet_pos = grid.rand_pos
  snake = [grid.rand_pos([pellet_pos])]
  direction = nil
  grid.draw(pellet_pos, snake)

  input = nil
  while input != "q" && grid.in_bounds(snake.first) && !snake_collision(snake)
    input = grid.getch

    if input && DIRECTIONS.include?(input)
      direction = input
    end

    snake_head_pos = snake.first
    new_pos = snake_head_pos

    case direction
    when Key::UP
      new_pos = Point.new(snake_head_pos.x - 1, snake_head_pos.y)
    when Key::DOWN
      new_pos = Point.new(snake_head_pos.x + 1, snake_head_pos.y)
    when Key::LEFT
      new_pos = Point.new(snake_head_pos.x, snake_head_pos.y - 2)
    when Key::RIGHT
      new_pos = Point.new(snake_head_pos.x, snake_head_pos.y + 2)
    end

    if new_pos == pellet_pos
      pellet_pos = grid.rand_pos(snake + [new_pos])
    else
      snake.pop # remove snake butt
    end

    snake.unshift(new_pos)

    grid.draw(pellet_pos, snake)

    sleep FRAME_LATENCY_SEC
  end
rescue => ex
  LOGGER.error(ex)
ensure
  LOGGER.close
  grid.close
end