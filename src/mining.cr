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

  alias Descriptor = Tuple(Int32, String)
  alias Table = Array(Array(String))
  
  def loadTable(filename : String)
    content = File.read(filename)
    table = [] of Array(String)
    csv = CSV.new(content, headers: false, strip: true) 
    while csv.next
      arr = csv.row.to_a 
      table << arr.rotate!(arr.size - 1)
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
        return "?"
      end
    end
    node.decision
  end
end
