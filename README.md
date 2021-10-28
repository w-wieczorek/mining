# mining

This is the implementation of an algorithm for the genaration of decision
trees from csv databases.  Please read and cite the following article:

W. Wieczorek et al.: Minimum query set for decision tree construction, 2022.

Our program uses [Gurobi Optimizer](https://www.gurobi.com/products/gurobi-optimizer/),
which is a powerful mathematical programming solver available for LP and MIP problems
(free for academic purposes).

The language of implementation is [Crystal](https://crystal-lang.org/) and we
tested the program under [Ubuntu 20.04.3 LTS](https://ubuntu.com/) operating system.

## Installation and usage

1. Install the LP solver as descibed on the
   page [Gurobi for Academics and Researchers](https://www.gurobi.com/academia/academic-program-and-licenses/).

2. Clone our repository:

   ```
   git clone https://github.com/w-wieczorek/mining.git
   ```

3. Find the source file `mining.cr` and change the first line by puting there
   a correct path to `libgurobi91.so` file.

4. Build and run the code:

   ```
   cd mining
   crystal build --no-debug --release src/mining.cr
   ./mining
   ```

## Contributing

1. Fork it (<https://github.com/w-wieczorek/mining/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Wojciech Wieczorek](https://github.com/w-wieczorek) - creator and maintainer
