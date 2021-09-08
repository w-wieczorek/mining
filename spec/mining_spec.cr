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
end
