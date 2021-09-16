@[Link(ldflags: "/home/wojtekw/gurobi912/linux64/lib/libgurobi91.so")]

lib LibGrb
  fun GRBemptyenv(envP : UInt64*) : Int32
  fun GRBsetstrparam(env : UInt64, paramname : UInt8*, value : UInt8*) : Int32
  fun GRBstartenv(env : UInt64) : Int32
  fun GRBnewmodel(env : UInt64, modelP : UInt64*, name : UInt8*, 
                  numvars : Int32, obj : Float64*, lb : Float64*, 
                  ub : Float64*, vtype : UInt8*, varnames : UInt64) : Int32
  fun GRBaddvars(model : UInt64, numvars : Int32, numnz : UInt64,
                 vbeg : UInt64*, vind : Int32*, vval : Float64*,
                 obj : Float64*, lb : Float64*, ub : Float64*, vtype : UInt8*,
                 varnames : UInt64) : Int32
  fun GRBsetintattr(model : UInt64, attrname : UInt8*, newvalue : Int32) : Int32
  fun GRBaddconstr(model : UInt64, numnz : Int32, cind : Int32*, cval : Float64*,
                   sense : UInt8, rhs : Float64, constrname : UInt8*) : Int32
  fun GRBoptimize(model : UInt64) : Int32
  fun GRBgetintattr(model : UInt64, attrname : UInt8*, valueP : Int32*) : Int32
  fun GRBgetdblattr(model : UInt64, attrname : UInt8*, valueP : Float64*) : Int32
  fun GRBgetdblattrarray(model : UInt64, attrname : UInt8*, first : Int32,
                         len : Int32, values : Float64*) : Int32
  fun GRBgeterrormsg(env : UInt64) : UInt8*
  fun GRBfreemodel(model : UInt64) : Int32
  fun GRBfreeenv(env : UInt64) : Void
end

require "csv"

module Mining
  extend self
  GRB_MINIMIZE = 1
  GRB_MAXIMIZE = -1
  BINARY     = 'B'.ord.to_u8
  CONTINUOUS = 'C'.ord.to_u8
  INTEGER    = 'I'.ord.to_u8
  SEMICONT   = 'S'.ord.to_u8
  SEMIINT    = 'N'.ord.to_u8
  GE = '>'.ord.to_u8
  LE = '<'.ord.to_u8
  EQ = '='.ord.to_u8
  
  # Model status codes
  GRB_LOADED          =  1
  GRB_OPTIMAL         =  2
  GRB_INFEASIBLE      =  3
  GRB_INF_OR_UNBD     =  4
  GRB_UNBOUNDED       =  5
  GRB_CUTOFF          =  6
  GRB_ITERATION_LIMIT =  7
  GRB_NODE_LIMIT      =  8
  GRB_TIME_LIMIT      =  9
  GRB_SOLUTION_LIMIT  = 10
  GRB_INTERRUPTED     = 11
  GRB_NUMERIC         = 12
  GRB_SUBOPTIMAL      = 13
  GRB_INPROGRESS      = 14
  GRB_USER_OBJ_LIMIT  = 15

  alias Descriptor = Tuple(Int32, String)
  alias Table = Array(Array(String))

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

  def loadTable(filename : String)
    content = File.read(filename)
    table = [] of Array(String)
    row_set_without_decision = Set(Array(String)).new
    csv = CSV.new(content, headers: false, strip: true) 
    while csv.next
      arr = csv.row.to_a 
      arr.rotate!(arr.size - 1)
      if !row_set_without_decision.add(arr[1..])
        puts "Already in table."
      else
        table << arr
      end
    end
    table
  end

  def findAllDescriptors(tab : Table) : Hash(Descriptor, Int32)
    idx = 0
    dict = {} of Descriptor => Int32
    tab.each do |row|
      row.each_with_index do |s, i|
        if i > 0 && !dict.has_key?({i, s})
          dict[{i, s}] = idx
          idx += 1
        end
      end
    end
    dict
  end

  def encodeProblem(tab : Table, dict : Hash(Descriptor, Int32))
    ncols = dict.size
    env = 0_u64
    model = 0_u64
    error = 0
    ind = Array(Int32).new(ncols, 0)
    val = Array(Float64).new(ncols, 0.0)
    obj = Array(Float64).new(ncols, 1.0)
    vtype = Array(UInt8).new(ncols, BINARY)
    # Create environment
    error = LibGrb.GRBemptyenv(pointerof(env))
    if error != 0
      message = LibGrb.GRBgeterrormsg(env)
      raise "ERROR: #{String.new(message)}\n"
    end
    error = LibGrb.GRBsetstrparam(env, "LogFile", "/run/shm/grb.log")
    if error != 0
      message = LibGrb.GRBgeterrormsg(env)
      raise "ERROR: #{String.new(message)}\n"
    end
    error = LibGrb.GRBstartenv(env)
    if error != 0
      message = LibGrb.GRBgeterrormsg(env)
      raise "ERROR: #{String.new(message)}\n"
    end
    # Create an empty model
    error = LibGrb.GRBnewmodel(env, pointerof(model), "mip1", 0, nil, nil, nil, nil, 0)
    if error != 0
      message = LibGrb.GRBgeterrormsg(env)
      raise "ERROR: #{String.new(message)}\n"
    end
    # Add variables
    error = LibGrb.GRBaddvars(model, ncols, 0, nil, nil, nil, obj.to_unsafe, 
                              nil, nil, vtype.to_unsafe, 0)
    if error != 0
      message = LibGrb.GRBgeterrormsg(env)
      raise "ERROR: #{String.new(message)}\n"
    end
    # Change objective sense to minimization
    error = LibGrb.GRBsetintattr(model, "ModelSense", GRB_MINIMIZE)
    if error != 0
      message = LibGrb.GRBgeterrormsg(env)
      raise "ERROR: #{String.new(message)}\n"
    end
    nrows = tab.size
    nattr = tab[0].size
    cnum = 0
    (0..nrows-2).each do |i|
      (i+1..nrows-1).each do |j|
        if tab[i][0] != tab[j][0]  # different decision classes
          numnz = 0
          (1...nattr).each do |k|
            if tab[i][k] != tab[j][k]
              ind[numnz] = dict[{k, tab[i][k]}]
              val[numnz] = 1.0
              numnz += 1
              ind[numnz] = dict[{k, tab[j][k]}]
              val[numnz] = 1.0
              numnz += 1
            end
          end
          error = LibGrb.GRBaddconstr(model, numnz, ind.to_unsafe, val.to_unsafe, GE, 1.0, "c#{cnum}")
          cnum += 1
          if error != 0
            message = LibGrb.GRBgeterrormsg(env)
            raise "ERROR: #{String.new(message)}\n"
          end
        end
      end
    end
    {env, model}
  end

  def findMinTestSet(tab : Table, dict : Hash(Descriptor, Int32)) : Set(Descriptor)
    env, model = encodeProblem(tab, dict)
    optimstatus = 0
    objval = 0.0
    # Optimize model
    error = LibGrb.GRBoptimize(model)
    if error != 0
      message = LibGrb.GRBgeterrormsg(env)
      raise "ERROR: #{String.new(message)}\n"
    end
    # Capture solution information
    error = LibGrb.GRBgetintattr(model, "Status", pointerof(optimstatus))
    if error != 0
      message = LibGrb.GRBgeterrormsg(env)
      raise "ERROR: #{String.new(message)}\n"
    end
    if optimstatus != GRB_OPTIMAL
      if optimstatus == GRB_INF_OR_UNBD
        raise "Model is infeasible or unbounded"
      else
        raise "Optimization was stopped early"
      end
    end
    ncols = dict.size
    sol = Array(Float64).new(ncols, 0.0)
    error = LibGrb.GRBgetdblattrarray(model, "X", 0, ncols, sol.to_unsafe)
    if error != 0
      message = LibGrb.GRBgeterrormsg(env)
      raise "ERROR: #{String.new(message)}\n"
    end
    # Free model
    LibGrb.GRBfreemodel(model)
    # Free environment
    LibGrb.GRBfreeenv(env)
    result = Set(Descriptor).new
    dict.each do |d, i|
      result.add(d) if sol[i] == 1
    end
    result
  end

  class Node
    property question : Descriptor?
    property decision : String
    property yes : Node?
    property no : Node?
    
    def initialize
      @question = nil
      @decision = "?"
      @yes = nil
      @no = nil
    end
    
    def display(level = 0)
      print " "*level
      unless @question.nil? 
        puts "#{@question.as(Descriptor)[0]}=#{@question.as(Descriptor)[1]}?"
        yes.as(Node).display(level + 1)
        no.as(Node).display(level + 1)
      else
        puts @decision
      end
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
    best_descriptor = mts.first
    best_split = split(obs, tab, best_descriptor)
    best_difference = (best_split[0].size - best_split[1].size).abs
    mts.each do |d|
      current_split = split(obs, tab, d)
      current_difference = (current_split[0].size - current_split[1].size).abs
      if current_difference < best_difference
        best_difference = current_difference
        best_split = current_split
        best_descriptor = d
      end
    end
    {best_descriptor, best_split[0], best_split[1]} 
  end

  def buildTree(obs : Set(Int32), mts : Set(Descriptor), tab : Table)
    raise "The empty set of obs" if obs.empty?
    node = Node.new
    if theSameClass?(obs, tab)
      node.decision = tab[obs.first][0]
    else
      node.question, yes_set, no_set = findBestJudgment(obs, mts, tab)
      node.yes = buildTree(yes_set, mts, tab)
      node.no = buildTree(no_set, mts, tab)
    end
    node
  end

  def classify(object : Hash(Int32, String), with tree) : String
    node = tree
    while node.question
      attr, value = node.question.as(Descriptor)
      if object.has_key?(attr)
        node = object[attr] == value ? node.yes.as(Node) : node.no.as(Node)
      else
        node = node.no.as(Node)
      end
    end
    node.decision
  end
end
