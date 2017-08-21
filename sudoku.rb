require 'io/console'

#
# require 'sudoku'
# puts Sudoku.solve(Sudoku::Puzzle.new(File.readlines('sudokuGrid.txt')))
#
module Sudoku

class Puzzle
	# These constants are used for translating between the external
	# string representation of a puzzle and the internal representation.
	ASCII = ".123456789"
	BIN = "\000\001\002\003\004\005\006\007\010\011"
	
	def initialize(lines)
		if (lines.respond_to? :join)
			s = lines.join
		else
			s = lines.dup
		end

		# Remove white spaces
		s.gsub!(/\s/, "") # /\s/ is a Regexp that matches any whitespace

		# Check input size
		raise Invalid, "Grid is the wrong size" unless s.size == 81

		# Check for invalid characters
		if i = s.index(/[^123456789\.]/)
			raise Invalid, "Illegal character #{s[i,1]} in puzzle" # '#{}' convert to string
		end

		# Conver string to integer array
		s.tr!(ASCII, BIN) # Translate ASCII/BIN
		@grid = s.unpack('c*')
		# Check duplicates
		raise Invalid, "Initial puzzle has duplicates" if has_duplicates? 
	end

	def to_s
		# Build output string in one line
		(0..8).collect{|r| @grid[r*9,9].pack('c9')}.join("\n").tr(BIN,ASCII)
	end

	# Duplicate
	def dup
		copy = super
		@grid = @grid.dup	# Make a new copy
		copy
	end

	# Allow access to the individual cells of a puzzle 
	def [](row, col)
		@grid[row*9 + col]
	end

	# Array access operator
	def []=(row, col, newvalue)
		unless (0..9).include? newvalue
			raise Invalid, "illegal cell value" 
		end
		@grid[row*9 + col] = newvalue 
	end

	# A sudoku "box" correspond to each value of the @grid
	BoxOfIndex = [0,0,0,1,1,1,2,2,2,0,0,0,1,1,1,2,2,2,0,0,0,1,1,1,2,2,2,
		3,3,3,4,4,4,5,5,5,3,3,3,4,4,4,5,5,5,3,3,3,4,4,4,5,5,5,
		6,6,6,7,7,7,8,8,8,6,6,6,7,7,7,8,8,8,6,6,6,7,7,7,8,8,8
	].freeze
	
	# For each cell whose value is unknown
	# Yield gives row, col & box to an associated block 
	def each_unknown
		0.upto 8 do |row|
			0.upto 8 do |col|
				index = row*9+col
				next if @grid[index] != 0
				box = BoxOfIndex[index]
				yield row, col, box
			end
		end
	end

	# Returns true if any row, column, or box has duplicates
	def has_duplicates?
		0.upto(8) {|row| return true if rowdigits(row).uniq! }
		0.upto(8) {|col| return true if coldigits(col).uniq! }
		0.upto(8) {|box| return true if boxdigits(box).uniq! }
		false
	end

	# Sudoku digits
	AllDigits = [1, 2, 3, 4, 5, 6, 7, 8, 9].freeze
	def possible(row, col, box)
		AllDigits - (rowdigits(row) + coldigits(col) + boxdigits(box))
	end

	private
	# Return an array of all known values in the row
	def rowdigits(row) 
		@grid[row*9,9] - [0]
	end

	# Return an array of all known values in the specified column.
	def coldigits(col)
		result = []
		col.step(80, 9) { |i|
			v = @grid[i]
			result << v if (v != 0)
		}
		result
	end

	# Map box number to the index of the upper-left corner of the box
	BoxToIndex = [0, 3, 6, 27, 30, 33, 54, 57, 60].freeze
	def boxdigits(b)
		i = BoxToIndex[b]
		[
			@grid[i], @grid[i+1], @grid[i+2], 
			@grid[i+9], @grid[i+10], @grid[i+11], 
			@grid[i+18], @grid[i+19], @grid[i+20]
		] - [0]
	end
end


class Invalid < StandardError
end

class Impossible < StandardError
end

# For each empty cell we look if there is only one possibility. Repeat until
# we cant find any empty cell with only one possibilty. The sudoku will
# be solved if it's not a "Diabolic" sudoku.
def Sudoku.scan(puzzle)
	unchanged = false
	
	until unchanged
		unchanged = true

		# Loop through cells whose value is unknown.
		puzzle.each_unknown do |row, col, box|
			p = puzzle.possible(row, col, box)
			case p.size
			when 0		# No possible values means the puzzle is over-constrained
				raise Impossible
			when 1 		# We've found a unique value
				puzzle[row,col] = p[0]
				unchanged = false
			end
		end
	end
end


def Sudoku.solve(puzzle)
	# Make a private copy of the puzzle that we can modify. 
	puzzle = puzzle.dup
	scan(puzzle)
	return puzzle
end
end
