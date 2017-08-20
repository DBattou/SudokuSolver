#
# require 'sudoku'
# puts Sudoku.solve(Sudoku::Puzzle.new(File.readlines('test.txt'))) 
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
	
	# For each cell whose value is unknown, this method
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

#
# This method scans a Puzzle, looking for unknown cells that have only
# a single possible value. If it finds any, it sets their value. Since
# setting a cell alters the possible values for other cells, it
# continues scanning until it has scanned the entire puzzle without
# finding any cells whose value it can set. 
#
# This method returns three values. If it solves the puzzle, all three
# values are nil. Otherwise, the first two values returned are the row and
# column of a cell whose value is still unknown. The third value is the
# set of values possible at that row and column. This is a minimal set of
# possible values: there is no unknown cell in the puzzle that has fewer
# possible values. This complex return value enables a useful heuristic
# in the solve() method: that method can guess at values for cells where
# the guess is most likely to be correct. 
#
# This method raises Impossible if it finds a cell for which there are
# no possible values. This can happen if the puzzle is over-constrained,
# or if the solve() method below has made an incorrect guess. 
#
# This method mutates the specified Puzzle object in place.
# If has_duplicates? is false on entry, then it will be false on exit. 
#
def Sudoku.scan(puzzle)
	unchanged = false # This is our loop variable.

	# Loop until we've scanned the whole board without making a change.
	until unchanged
		unchanged = true		# Assume no cells will be changed this time
		rmin,cmin,pmin = nil 	# Track cell with minimal possible set
		min = 10				# More than the maximal number of possibilities

		# Loop through cells whose value is unknown.
		puzzle.each_unknown do |row, col, box|
			# Find the set of values that could go in this cell
			p = puzzle.possible(row, col, box)

			# Branch based on the size of the set p.
			# We care about 3 cases: p.size==0, p.size==1, and p.size > 1.
			case p.size
			when 0		# No possible values means the puzzle is over-constrained
				raise Impossible
			when 1 		# We've found a unique value, so set it in the grid
				puzzle[row,col] = p[0] 	# Set that position on the grid to the value 
				unchanged = false 		# Note that we've made a change
			else # For any other number of possibilities
				# Keep track of the smallest set of possibilities.
				# But don't bother if we're going to repeat this loop. 
				if unchanged && p.size < min
					min = p.size 						# Current smallest size
					rmin, cmin, pmin = row, col, p 		# Note parallel assignment
				end
			end
		end
	end
	# Return the cell with the minimal set of possibilities. # Note multiple return values.
	return rmin, cmin, pmin
end



# Solve a Sudoku puzzle using simple logic, if possible, but fall back 
# on brute-force when necessary. This is a recursive method. It either 
# returns a solution or raises an exception. The solution is returned 
# as a new Puzzle object with no unknown cells. This method does not 
# modify the Puzzle it is passed. Note that this method cannot detect 
# an under-constrained puzzle.
def Sudoku.solve(puzzle)
	# Make a private copy of the puzzle that we can modify. 
	puzzle = puzzle.dup

	# Use logic to fill in as much of the puzzle as we can.
	# This method mutates the puzzle we give it, but always leaves it valid. 
	# It returns a row, a column, and set of possible values at that cell. 
	# Note parallel assignment of these return values to three variables.
	r,c,p = scan(puzzle)

	# If we solved it with logic, return the solved puzzle. 
	return puzzle if r == nil

	# Otherwise, try each of the values in p for cell [r,c].
	# Since we're picking from a set of possible values, the guess leaves
	# the puzzle in a valid state. The guess will either lead to a solution 
	# or to an impossible puzzle. We'll know we have an impossible
	# puzzle if a recursive call to scan throws an exception. If this happens 
	# we need to try another guess, or re-raise an exception if we've tried 
	# all the options we've got.
	p.each do |guess| 			# For each value in the set of possible values
		puzzle[r,c] = guess 	# Guess the value

		begin
			# Now try (recursively) to solve the modified puzzle.
			# This recursive invocation will call scan() again to apply logic
			# to the modified board, and will then guess another cell if needed. 
			# Remember that solve() will either return a valid solution or
			# raise an exception.
			return solve(puzzle) 	# If it returns, we just return the solution
		rescue Impossible
			next					# If it raises an exception, try the next guess
		end
	end
	
	# If we get here, then none of our guesses worked out 
	# so we must have guessed wrong sometime earlier. 
	raise Impossible
	end 
end




