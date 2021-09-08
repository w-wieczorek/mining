@[Link(ldflags: "/usr/lib/liblpsolve55.so")]

lib LibLpSolve
  fun make_lp(rows : Int32, columns : Int32) : UInt64
  fun delete_lp(lprec : UInt64) : Void
  fun get_status(lprec : UInt64) : Int32
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
end
