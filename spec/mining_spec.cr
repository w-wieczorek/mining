require "spec"
require "../src/mining.cr"

describe "Mining" do
  it "uses the lp-solve MIP solver" do
    lp = LibLpSolve.make_lp(0, 2)
    LibLpSolve.set_verbose(lp, 0)
    LibLpSolve.add_constraint(lp, [0.0, 2.0, 2.0].to_unsafe, Mining::GE, 3.0)
    LibLpSolve.add_constraint(lp, [0.0, -2.0, 2.0].to_unsafe, Mining::LE, 3.0)
    LibLpSolve.add_constraint(lp, [0.0, 4.0, 2.0].to_unsafe, Mining::LE, 19.0)
    LibLpSolve.set_int(lp, 1, Mining::TRUE)
    LibLpSolve.set_int(lp, 2, Mining::TRUE)
    LibLpSolve.set_lowbo(lp, 1, 0.0)
    LibLpSolve.set_lowbo(lp, 2, 0.0)
    LibLpSolve.set_obj_fn(lp, [0.0, 1.0, 1.0].to_unsafe)
    LibLpSolve.set_maxim(lp)
    LibLpSolve.solve(lp)
    status = LibLpSolve.get_status(lp)
    status.should eq(Mining::OPTIMAL)
    result = Array(Float64).new(2, 0.0)
    LibLpSolve.get_variables(lp, result.to_unsafe)
    result.should eq([3, 3])
    profit = LibLpSolve.get_objective(lp)
    LibLpSolve.delete_lp(lp)
    profit.should eq(6) 
  end
  
  it "loads decision table from csv file" do
    tab = Mining.loadTable("./spec/data.csv")
    tab.size.should eq(4)
    tab[2].should eq(["Jeff Smith", "2018", "Prescott House", "17-D", "3.20"])
  end
  
  it "finds all descriptors from a decision table" do
    tab = [["0", "b", "a"], ["1", "c", "a"], ["1", "a", "b"], ["0", "c", "b"]]
    dict = Mining.findAllDescriptors(tab)
    dict.should eq({ {1, "b"} => 1, {2, "a"} => 2, {1, "c"} => 3, {1, "a"} => 4, {2, "b"} => 5 })
  end
  
  it "finds minimum test set" do
    tab = [["0", "e", "e", "f", "f"],
           ["1", "g", "f", "g", "f"],
           ["2", "e", "f", "g", "f"],
           ["0", "f", "f", "f", "g"],
           ["1", "e", "f", "e", "f"]]
    dict = Mining.findAllDescriptors(tab)
    result = Mining.findMinTestSet(tab, dict)
    result.should eq(Set{ {1, "e"}, {3, "f"}, {3, "g"} })
  end
  
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
end
