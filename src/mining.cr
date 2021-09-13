@[Link(ldflags: "/usr/lib/liblpsolve55.so")]

lib LibLpSolve
  fun make_lp(rows : Int32, columns : Int32) : UInt64
  fun delete_lp(lprec : UInt64) : Void
  fun get_status(lprec : UInt64) : Int32
  fun get_statustext(lprec : UInt64, statuscode : Int32) : UInt8*
  fun add_constraint(lprec : UInt64, row : Float64*, constr_type : Int32, rh : Float64) : UInt8
  fun set_obj_fn(lprec : UInt64, row : Float64*) : UInt8
  fun set_maxim(lprec : UInt64) : Void
  fun set_minim(lprec : UInt64) : Void
  fun set_bounds(lprec : UInt64, colnr : Int32, lower : Float64, upper : Float64) : UInt8
  fun set_unbounded(lprec : UInt64, colnr : Int32) : UInt8
  fun set_upbo(lprec : UInt64, colnr : Int32, value : Float64) : UInt8
  fun set_lowbo(lprec : UInt64, colnr : Int32, value : Float64) : UInt8
  fun set_int(lprec : UInt64, colnr : Int32, must_be_int : UInt8) : UInt8
  fun set_binary(lprec : UInt64, colnr : Int32, must_be_bin : UInt8) : UInt8
  fun solve(lprec : UInt64) : Int32
  fun get_variables(lprec : UInt64, var : Float64*) : UInt8
  fun get_objective(lprec : UInt64) : Float64
  fun set_verbose(lprec : UInt64, verbose : Int32) : Void
end

require "csv"

module Mining
  extend self
  FALSE = 0_u8
  TRUE = 1_u8
  LE = 1
  EQ = 3
  GE = 2

  # Solver status values
  UNKNOWNERROR  = -5
  DATAIGNORED   = -4
  NOBFP         = -3
  NOMEMORY      = -2
  NOTRUN        = -1
  OPTIMAL       =  0
  SUBOPTIMAL    =  1
  INFEASIBLE    =  2
  UNBOUNDED     =  3
  DEGENERATE    =  4
  NUMFAILURE    =  5
  USERABORT     =  6
  TIMEOUT       =  7
  RUNNING       =  8
  PRESOLVED     =  9
  ACCURACYERROR = 25

  alias Attribute = Int32
  alias Value = String
  alias Descriptor = Tuple(Attribute, Value)
  alias Table = Array(Array(String))
  
  def loadTable(filename : String)
    content = File.read(filename)
    table = [] of Array(String)
    csv = CSV.new(content, headers: false, strip: true) 
    while csv.next 
      table << csv.row.to_a
    end
    table
  end

  def findAllDescriptors(tab : Table) : Hash(Descriptor, Int32)
    idx = 0
    dict = {} of Descriptor => Int32
    tab.each do |row|
      row.each_with_index do |s, i|
        if i > 0 && !dict.has_key?({i, s})
          idx += 1
          dict[{i, s}] = idx
        end
      end
    end
    dict
  end

  def encodeProblem(tab : Table, dict : Hash(Descriptor, Int32)) : UInt64
    ncols = dict.size
    lp = LibLpSolve.make_lp(0, ncols)
    LibLpSolve.set_verbose(lp, 0)
    (1..ncols).each { |j| LibLpSolve.set_binary(lp, j, TRUE) }
    nrows = tab.size
    nattr = tab[0].size
    (0..nrows-2).each do |i|
      (i+1..nrows-1).each do |j|
        if tab[i][0] != tab[j][0]  # different decision classes
          ineq = Array(Float64).new(ncols + 1, 0.0)
          (1...nattr).each do |k|
            if tab[i][k] != tab[j][k]
              ineq[dict[{k, tab[i][k]}]] = 1.0
              ineq[dict[{k, tab[j][k]}]] = 1.0
            end
          end
          LibLpSolve.add_constraint(lp, ineq.to_unsafe, GE, 1.0)
        end
      end
    end
    c = Array(Float64).new(ncols + 1, 1.0)
    c[0] = 0.0
    LibLpSolve.set_obj_fn(lp, c.to_unsafe)
    LibLpSolve.set_minim(lp)
    lp
  end

  def findMinTestSet(tab : Table, dict : Hash(Descriptor, Int32)) : Set(Descriptor)
    lp = encodeProblem(tab, dict)
    LibLpSolve.solve(lp)
    status = LibLpSolve.get_status(lp)
    if status != OPTIMAL
      message = LibLpSolve.get_statustext(lp, status)
      raise "Lp-solve status: " + String.new(message)
    end
    ncols = dict.size
    vars = Array(Float64).new(ncols + 1, 0.0)
    LibLpSolve.get_variables(lp, vars.to_unsafe + 1)
    LibLpSolve.delete_lp(lp)
    result = Set(Descriptor).new
    dict.each do |d, i|
      result.add(d) if vars[i] == 1
    end
    result
  end

  class Node
    property descriptor : Descriptor?
    property decision : String
    property yes : Node?
    property no : Node?
    
    def initialize
      @descriptor = nil
      @decision = "?"
      @yes = nil
      @no = nil
    end
  end

  private def theSameClass?(obs : Set(Int32), tab : Table)
    return true if obs.empty?
    d = tab[obs.first][0]
    obs.each do |i|
      return false if tab[i][0] != d
    end
    true
  end

  private def split(obs, tab, with descriptor)
    yes_set = Set(Int32).new
    no_set = Set(Int32).new
    attr, val = descriptor
    obs.each do |i|
      if tab[i][attr] == val
        yes_set.add i
      else
        no_set.add i
      end
    end
    {yes_set, no_set}
  end

  private def findBestJudgment(obs, mts, tab)
    
  end

  def buildTree(obs : Set(Int32), mts : Set(Descriptor), tab : Table)
    raise "The empty set of obs" if obs.empty?
    node = Node.new
    if theSameClass?(obs, tab)
      node.decision = tab[obs.first][0]
    else
      node.descriptor, yes_set, no_set = findBestJudgment(obs, mts, tab)
      node.yes = buildTree(yes_set, mts, tab)
      node.no = buildTree(no_set, mts, tab)
    end
    node
  end

  class Ga
    getter population : Array(Array(Int32))
    getter pop_size : Int32
    getter genotype_len : Int32
    getter best_individual : Array(Int32)
    getter best_error : Float64
    setter fitness_fun : Array(Int32) -> Float64
    setter tournament_size : Int32
    setter n_iterations : Int32
    
    # An individual is the permutation of [0, 1, ..., genotype_len - 1]
    def initialize(@pop_size, @genotype_len)
      raise "Population size have to be >= 3" if pop_size < 3
      @population = Array(Array(Int32)).new(pop_size) do |i|
        (0...genotype_len).to_a.shuffle!
      end
      @best_individual = (0...genotype_len).to_a
      @best_error = Float64::INFINITY
      @fitness_fun = ->(arr : Array(Int32)) { 0.0 }
      @tournament_size = 3
      @n_iterations = 200
    end

    private def reservoirSample(s, r, k)
      # fill the reservoir array
      (0...k).each { |i| r[i] = i }
      # replace elements with gradually decreasing probability
      (k..s).each do |i|
        j = rand(i + 1)
        if j < k
          r[j] = i
        end
      end
    end

    private def not_in(x, arr, first, last)
      (first..last).each do |i|
        return false if arr[i] == x
      end
      return true
    end

    private def idx_for(x, arr)
      arr.each_with_index do |y, i|
        return i if x == y
      end
      raise "#{x} not found in #{arr}"
      0
    end

    def pmx(arr1 : Array(Int32), arr2 : Array(Int32), arr3 : Array(Int32), test = false)
      n = arr1.size
      point = StaticArray[0, 0]
      reservoirSample(n, point.to_unsafe, 2)
      point[0], point[1] = point[1], point[0] if point[0] > point[1]
      point[0], point[1] = 3, 8 if test
      (0...point[0]).each { |i| arr3[i] = -1 }
      (point[0]...point[1]).each { |i| arr3[i] = arr1[i] }
      (point[1]...n).each { |i| arr3[i] = -1 }
      (point[0]...point[1]).each do |k|
        if not_in(arr2[k], arr1, point[0], point[1] - 1)
          target_idx = idx_for(arr1[k], arr2) 
          while target_idx >= point[0] && target_idx < point[1]
            target_idx = idx_for(arr1[target_idx], arr2) 
          end 
          arr3[target_idx] = arr2[k]
        end
      end
      (0...point[0]).each do |i|
        arr3[i] = arr2[i] if arr3[i] == -1
      end
      (point[1]...n).each do |i|
        arr3[i] = arr2[i] if arr3[i] == -1
      end
    end

    def run
      error = @population.map { |arr| @fitness_fun.call(arr) }
      best_idx = (0...@pop_size).min_by { |i| error[i] }
      @best_error = error[best_idx]
      @best_individual[0, @genotype_len] = @population[best_idx]
      iteration = 0
      tournament = Array(Int32).new(@tournament_size, 0)
      while iteration < @n_iterations && @best_error > 0
        reservoirSample(@pop_size - 1, tournament, @tournament_size)
        tournament.sort_by! { |idx| error[idx] }
        parent1 = population[tournament[0]]
        parent2 = population[tournament[1]]
        child = population[tournament[-1]]
        pmx(parent1, parent2, child)
        if rand < 0.01
          point = StaticArray[0, 0]
          reservoirSample(@genotype_len - 1, point.to_unsafe, 2)
          child.swap(point[0], point[1])
        end
        error[tournament[-1]] = @fitness_fun.call(child)
        if error[tournament[-1]] < @best_error
          @best_error = error[tournament[-1]]
          @best_individual[0, @genotype_len] = @population[tournament[-1]]
        end
        iteration += 1
      end
    end
  end
end
