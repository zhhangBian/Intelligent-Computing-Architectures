评测了多组参数下的分类表现，记录了不同参数下的表现。

在此文件夹中，文件夹的命名格式为`depth-nodes-epoch-lr`。
在其中可以找到对应参数的隐藏层权重文件

- `whi.npy`：输入层与第一个隐藏层之间的权重文件
- `whh_{i}.npy`：第i个隐藏层和第i+1个隐藏层之间的权重文件
- `who.npy`：最后一个隐藏层和输出层之间的权重文件