# Graph Viewer | CPU-Only ForceAtlas2 for Weighted Graphs

This repository features a modified CPU implementation of the ForceAtlas2 algorithm for **weighted graphs**. The original version was developed by [GPUGraphLayout](https://github.com/govertb/GPUGraphLayout), but this adaptation focuses on CPU execution, making it suitable for large-scale networks.

## Overview

- **Algorithm**: Modified ForceAtlas2 for weighted, undirected graphs.
- **Performance**: Optimized for use on the CPU.

## System Requirements

- **Operating System**: Linux
- **Dependencies**: Install `libpng` and its development headers. Use:
  ```bash
  git submodule init && git submodule update
  ```

## Compilation

1. Navigate to `builds/linux`.
2. Run the following command:
   ```bash
   make graph_viewer
   ```

## Usage

```bash
graph_viewer cpu max_iterations num_snaps sg|wg scale gravity exact edgelist_path out_path [png|csv|bin]
```

### Arguments

- **cpu**: Use CPU implementation.
- **max_iterations**: Number of layout iterations.
- **num_snaps**: Number of times to render snapshots during layout computation.
- **sg|wg**: Choose between strong (`sg`) or weak gravity (`wg`).
- **scale**: Repulsive force scaling factor.
- **gravity**: Gravitational force scaling factor.
- **exact**: Use exact O(|V|^2) force calculations.
- **edgelist_path**: Path to the edge list file (text format, whitespace-separated).
- **out_path**: Path for the output file.
- **[png|csv|bin]**: Optional output format; defaults to `png`.

## Citing

- G.G. Brinkmann et al., ICPP 2017
- M. Jacomy et al., PLoS ONE, 2014

## License

This project is licensed under the GNU Affero General Public License.
