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
    tab[2].should eq(["3.20", "Jeff Smith", "2018", "Prescott House", "17-D"])
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
  
  it "generates a decision tree" do
    tab = Mining.loadTable("./spec/data2.csv")
    dict = Mining.findAllDescriptors(tab)
    mts = Mining.findMinTestSet(tab, dict)
    root = Mining.buildTree((0...tab.size).to_set, mts, tab)
    root.question.should eq({1, "0"})
    root.yes.as(Mining::Node).decision.should eq("b")
    root.no.as(Mining::Node).question.should eq({3, "0"})
    root.no.as(Mining::Node).yes.as(Mining::Node).decision.should eq("b")
    root.no.as(Mining::Node).no.as(Mining::Node).decision.should eq("a")
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
end
