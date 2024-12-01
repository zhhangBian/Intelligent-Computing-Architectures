### MAtmul中的修改

由于进行了跳写，故可以不用对原始数据进行padding操作，而是直接在对应偏移量处直接写入数据。

核心在于每次对BRAM写入一行的数据，把所有的行进行写入。

```py
n, p = data.shape
p = p if p % self.systolic_size == 0 else (p // self.systolic_size + 1) * self.systolic_size

# C语言风格的内存布局：行优先
data = data.copy(order='C')

for i in range(n):
    self.bram.write(data[i], block_name=block_name, offset=i * p)
```

同时，需要注意对不满一行数据的特殊处理，并将数据按照行优先的方式进行排列。

### BRAM中的修改

为了支持直接在offset处进行写操作，对`bram.py`文件中封装的`wrtie`函数进行修改，使得能够直接写对应offset处的数据。

```py
mem_offset = self.block_info[block_name]['offset'][offset] if isinstance(offset, str) else offset
```
