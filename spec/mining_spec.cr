require "spec"
require "../src/mining.cr"

describe "Mining" do
  it "implements GA with pmx operator" do
    ga = Mining::Ga.new(3, 10)
    ga.population[0][0, 10] = [8, 4, 7, 3, 6, 2, 5, 1, 9, 0]
    ga.population[1][0, 10] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    ga.pmx(ga.population[0], ga.population[1], ga.population[2], true)
    ga.population[2].should eq([0, 7, 4, 3, 6, 2, 5, 1, 8, 9])
    ga.pmx(ga.population[0], ga.population[1], ga.population[2])
    ga.population[2].sort.should eq([0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
  end

  it "can use GA for solving TSP" do
    dist = [[  0.0, 132.0, 217.0, 164.0,  58.0],
            [132.0,   0.0, 290.0, 201.0,  79.0],
            [217.0, 290.0,   0.0, 113.0, 303.0],
            [164.0, 201.0, 113.0,   0.0, 196.0],
            [ 58.0,  79.0, 303.0, 196.0,   0.0]]
    ga = Mining::Ga.new(5, 5)
    eval = ->(path : Array(Int32)) {
      cost = 0.0
      (0..4).each do |i|
        cost += dist[path[i]][path[(i+1) % 5]]
      end
      cost
    }
    ga.fitness_fun = eval
    ga.run
    ga.best_error.should eq(668)
  end

  it "uses Gurobi MIP solver" do
    env = 0_u64
    model = 0_u64
    error = 0
    sol = Array(Float64).new(2, 0.0)
    ind = Array(Int32).new(2, 0)
    val = Array(Float64).new(2, 0.0)
    obj = Array(Float64).new(2, 0.0)
    vtype = Array(UInt8).new(2, 0_u8)
    optimstatus = 0
    objval = 0.0
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
    error = LibGrb.GRBnewmodel(env, pointerof(model), "mip1", 0, nil, nil, nil, nil, 0)
    if error != 0
      message = LibGrb.GRBgeterrormsg(env)
      raise "ERROR: #{String.new(message)}\n"
    end
    obj[0] = 1.0
    obj[1] = 1.0
    vtype[0] = Mining::INTEGER
    vtype[1] = Mining::INTEGER
    error = LibGrb.GRBaddvars(model, 2, 0, nil, nil, nil, obj.to_unsafe,
                      [0.0, 0.0].to_unsafe, [20.0, 20.0].to_unsafe,
                      vtype.to_unsafe, 0)
    if error != 0
      message = LibGrb.GRBgeterrormsg(env)
      raise "ERROR: #{String.new(message)}\n"
    end
    error = LibGrb.GRBsetintattr(model, "ModelSense", Mining::GRB_MAXIMIZE)
    if error != 0
      message = LibGrb.GRBgeterrormsg(env)
      raise "ERROR: #{String.new(message)}\n"
    end
    ind[0] = 0
    ind[1] = 1
    val[0] = 2.0
    val[1] = 2.0
    error = LibGrb.GRBaddconstr(model, 2, ind.to_unsafe, val.to_unsafe, Mining::GE, 3.0, "c0")
    if error != 0
      message = LibGrb.GRBgeterrormsg(env)
      raise "ERROR: #{String.new(message)}\n"
    end
    ind[0] = 0
    ind[1] = 1
    val[0] = -2.0
    val[1] = 2.0
    error = LibGrb.GRBaddconstr(model, 2, ind.to_unsafe, val.to_unsafe, Mining::LE, 3.0, "c1")
    if error != 0
      message = LibGrb.GRBgeterrormsg(env)
      raise "ERROR: #{String.new(message)}\n"
    end
    ind[0] = 0
    ind[1] = 1
    val[0] = 4.0
    val[1] = 2.0
    error = LibGrb.GRBaddconstr(model, 2, ind.to_unsafe, val.to_unsafe, Mining::LE, 19.0, "c2")
    if error != 0
      message = LibGrb.GRBgeterrormsg(env)
      raise "ERROR: #{String.new(message)}\n"
    end
    error = LibGrb.GRBoptimize(model)
    if error != 0
      message = LibGrb.GRBgeterrormsg(env)
      raise "ERROR: #{String.new(message)}\n"
    end
    error = LibGrb.GRBgetintattr(model, "Status", pointerof(optimstatus))
    if error != 0
      message = LibGrb.GRBgeterrormsg(env)
      raise "ERROR: #{String.new(message)}\n"
    end
    optimstatus.should eq(Mining::GRB_OPTIMAL)
    error = LibGrb.GRBgetdblattrarray(model, "X", 0, 2, sol.to_unsafe)
    if error != 0
      message = LibGrb.GRBgeterrormsg(env)
      raise "ERROR: #{String.new(message)}\n"
    end
    sol.should eq([3, 3])
    error = LibGrb.GRBgetdblattr(model, "ObjVal", pointerof(objval))
    if error != 0
      message = LibGrb.GRBgeterrormsg(env)
      raise "ERROR: #{String.new(message)}\n"
    end
    LibGrb.GRBfreemodel(model)
    LibGrb.GRBfreeenv(env)
    objval.should eq(6)
  end
  
  it "loads decision table from csv file" do
    tab = Mining.loadTable("./spec/data.csv")
    tab.size.should eq(4)
    tab[2].should eq(["3.20", "Jeff Smith", "2018", "Prescott House", "17-D"])
  end
  
  it "finds all descriptors from a decision table" do
    tab = [["0", "b", "a"], ["1", "c", "a"], ["1", "a", "b"], ["0", "c", "b"]]
    dict = Mining.findAllDescriptors(tab)
    dict.should eq({ {1, "b"} => 0, {2, "a"} => 1, {1, "c"} => 2, {1, "a"} => 3, {2, "b"} => 4 })
  end
  
  it "finds minimum test set" do
    tab = [["0", "e", "e", "f", "f"],
           ["1", "g", "f", "g", "f"],
           ["2", "e", "f", "g", "f"],
           ["0", "f", "f", "f", "g"],
           ["1", "e", "f", "e", "f"]]
    dict = Mining.findAllDescriptors(tab)
    result = Mining.findMinTestSet(tab, dict)
    result.size.should eq(3)
  end
  
  it "generates a decision tree" do
    tab = Mining.loadTable("./spec/data2.csv")
    dict = Mining.findAllDescriptors(tab)
    mts = Mining.findMinTestSet(tab, dict)
    root = Mining.buildTree((0...tab.size).to_set, mts, tab)
    root.question.should eq({3, "0"})
    root.yes.as(Mining::Node).decision.should eq("b")
    root.no.as(Mining::Node).question.should eq({1, "1"})
    root.no.as(Mining::Node).yes.as(Mining::Node).decision.should eq("a")
    root.no.as(Mining::Node).no.as(Mining::Node).decision.should eq("b")
  end

  it "can classify new objects" do
    tab = Mining.loadTable("./spec/agaricus-lepiota.data.csv")
    dict = Mining.findAllDescriptors(tab)
    mts = Mining.findMinTestSet(tab, dict)
    root = Mining.buildTree((0...tab.size).to_set, mts, tab)
    ob = {1 => "k", 2 => "y", 3 => "e", 4 => "f", 5 => "f", 6 => "f", 
          7 => "c", 8 => "n", 9 => "b", 10 => "t", 12 => "s", 13 => "s",
          14 => "p", 15 => "w", 16 => "p", 17 => "w", 18 => "o",
          19 => "e", 20 => "w", 21 => "v", 22 => "p"}
    result = Mining.classify ob, with: root
    result.should eq("p")
  end

  it "generates a decision tree for breast" do
    tab = Mining.loadTable("./spec/balance-scale_tr.csv")
    dict = Mining.findAllDescriptors(tab)
    mts = Mining.findMinTestSet(tab, dict)
    root = Mining.buildTree((0...tab.size).to_set, mts, tab)
    puts
    root.display
    puts
  end
end
