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
  fun GRBwrite(model : UInt64, filename : UInt8*) : Int32
  fun GRBfreemodel(model : UInt64) : Int32
  fun GRBfreeenv(env : UInt64) : Void
end

require "csv"
require "json"
require "yaml"

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
        (0...genotype_len).to_a
      end
      @best_individual = (0...genotype_len).to_a
      @best_error = Float64::INFINITY
      @fitness_fun = ->(arr : Array(Int32)) { 0.0 }
      @tournament_size = 3
      @n_iterations = 200
    end

    private def shuffle_population
      (0...@pop_size).each do |i|
        @population[i].shuffle!
      end
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
      shuffle_population
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
    row_set_without_decision = Set(String).new
    csv = CSV.new(content, headers: false, strip: true)
    counter = 0
    row_size = 0
    while csv.next
      arr = csv.row.to_a
      if counter == 0
        row_size = arr.size
      else
        raise "Row #{counter + 1}: different size." unless arr.size == row_size
      end
      counter += 1
      arr.rotate!(arr.size - 1)
      if !row_set_without_decision.add?("#{arr[1..]}")
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

  # Assuming a decision as 0, 1, 2, ...
  def findNumOfClases(tab : Table) : Int32
    res = 0
    tab.each do |row|
      c_num = row[0].to_i
      res = c_num if c_num > res
    end
    res + 1
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
          if numnz == 0
            raise "Bad pair of rows: (#{i + 1}, #{j + 1})."
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
    # puts
    # LibGrb.GRBwrite(model, "/run/shm/#{model}.lp")
    # puts
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
    include JSON::Serializable
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

    def size
      unless @question.nil? 
        1 + yes.as(Node).size + no.as(Node).size
      else
        1
      end
    end

    def height
      unless @question.nil? 
        1 + Math.max(yes.as(Node).height, no.as(Node).height)
      else
        0
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

  private def findFirstJudgment(obs, perm, pi, tab, idx)
    descriptor = perm[pi[idx]]
    curr_split = split(obs, tab, descriptor)
    idx += 1
    while curr_split[0].size == 0 || curr_split[1].size == 0
      descriptor = perm[pi[idx]]
      curr_split = split(obs, tab, descriptor)
      idx += 1
    end
    {descriptor, curr_split[0], curr_split[1], idx}
  end

  def buildTree(obs : Set(Int32), perm : Array(Descriptor), pi : Array(Int32), tab : Table, idx = 0)
    raise "The empty set of obs" if obs.empty?
    node = Node.new
    if theSameClass?(obs, tab)
      node.decision = tab[obs.first][0]
    else
      node.question, yes_set, no_set, idx = findFirstJudgment(obs, perm, pi, tab, idx)
      node.yes = buildTree(yes_set, perm, pi, tab, idx)
      node.no = buildTree(no_set, perm, pi, tab, idx)
    end
    node
  end

  def classify(object : Array(String), with tree) : String
    node = tree
    while node.question
      attr, value = node.question.as(Descriptor)
      node = object[attr] == value ? node.yes.as(Node) : node.no.as(Node)
    end
    node.decision
  end

  def dTreeFromMTS(training : Table, validation : Table, mts : Set(Descriptor))
    perm = mts.to_a
    n = perm.size
    all_obs = (0...training.size).to_set
    ga = Ga.new(2*n*Math.log(n).round.to_i, n)
    eval = ->(pi : Array(Int32)) {
      tree = buildTree(all_obs, perm, pi, training)
      error = 0.0
      validation.each do |row|
        answer = classify row, with: tree
        error += 1.0 if answer != row[0]
      end
      error
    }
    ga.fitness_fun = eval
    ga.n_iterations = 500*n
    min_error = Float64::INFINITY
    best_perm = Array(Int32).new(n, 0)
    30.times do
      ga.run
      if ga.best_error < min_error
        min_error = ga.best_error
        best_perm[0, n] = ga.best_individual
      end
    end
    buildTree(all_obs, perm, best_perm, training)
  end
end

files = Dir.new("./data").children
databases = files.map{ |fname| /^((\w|-)+)_(tr|te|clean)\.data$/.match(fname).try &.[1] }.to_set
databases.each do |name|
  if name
    puts "Database #{name}:"
    training = Mining.loadTable("./data/#{name}_tr.data")
    validation = Mining.loadTable("./data/#{name}_te.data")
    testing = Mining.loadTable("./data/#{name}_clean.data")
    dict = Mining.findAllDescriptors(training)
    num_of_clases = Mining.findNumOfClases(training)
    num_of_clases_in_testing = Mining.findNumOfClases(testing)
    if num_of_clases != num_of_clases_in_testing
      raise "Database #{name}: different num of classes in tr and clean"
    end
    mts = Set(Mining::Descriptor).new
    elapsed_time_mts = Time.measure do
      mts = Mining.findMinTestSet(training, dict)
    end
    (1..30).each do |iter_run|
      puts "Iter run #{iter_run}"
      tree = Mining::Node.new
      elapsed_time_tree = Time.measure do
        tree = Mining.dTreeFromMTS(training, validation, mts)
      end
      confusion_matrix = Array(Array(Int32)).new(num_of_clases) do |i| 
        Array(Int32).new(num_of_clases, 0)
      end
      testing.each do |row|
        predicted = Mining.classify row, with: tree
        actual = row[0]
        confusion_matrix[actual.to_i][predicted.to_i] += 1
      end
      fname = "mqs_" + name + "_run_" + iter_run.to_s
      results = {
        "method" => "MQS",
        "database" => name,
        "confusion matrix" => confusion_matrix,
        "tree" => {
          "size" => tree.size,
          "height" => tree.height,
          "serialization" => fname + "_tree.json" },
        "time of experiment" => Time.utc.to_s,
        "cpu time" => elapsed_time_mts.total_seconds + elapsed_time_tree.total_seconds
      }
      File.write(fname + "_results.yaml", results.to_yaml)
      File.write(fname + "_tree.json", tree.to_json)
    end
  end
end
