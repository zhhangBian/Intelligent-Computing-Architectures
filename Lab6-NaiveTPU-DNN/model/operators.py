# -*-coding: utf-8-*-
import numpy as np
np.set_printoptions(threshold=np.inf)
from multiprocessing import Process
import os, sys
sys.path.append(os.path.abspath('.'))   # 添加路径信息否则无法引用到tools

from tools import *

# 此文件中包含神经网络推理算子的具体实现

# 量化参数
# 用于进行模型量化
class Quantization(object):
    '''层级量化参数存储和处理'''
    def __init__(self, scale, zero_point):
        '''
            Args:
                scale: dict, 包含input, weight, output
                zero_point: dict, 包含input, weight, output
        '''
        # 检查scale和zero_point是否符合要求
        # 检查数据类型为dict且包含input, weight, output
        self._check_dict(scale)
        self._check_dict(zero_point)

        # 赋值
        # 量化尺度
        self.scale = scale
        # 量化零点
        self.zero_point = zero_point

        # 将字典值转换为ndarray
        self._dict2nparray(self.scale)
        self._dict2nparray(self.zero_point)

    def _check_dict(self, x):
        assert type(x) is dict
        if ('input' in x) and ('weight' in x) and ('output' in x) == False:
            raise KeyError('scale or zero_point must have input, weight and output items')

    def _dict2nparray(self, x):
        for key in x:
            x[key] = np.array(x[key])

    # 获取原始量化尺度
    def get_ori_scale(self):
        return self.scale

    # 获取量化尺度
    def get_scale(self):
        '''
            Return:
                input_scale * weight_scale / output_scale
        '''
        return self.scale['input'] * self.scale['weight'] / self.scale['output']

    # 获取量化零点
    def get_zero_point(self):
        return self.zero_point

# 矩阵乘算子
class Matmul(object):
    '''矩阵乘法
        Args: uint8, (m, n)
        Args: int8, (n, p)
    '''

    def __init__(self):
        self.systolic_size = 4 # 脉动阵列大小
        self.bram = BRAM()

    def __call__(self, input: np.uint8, weight: np.int8):
        m, n = input.shape
        n, p = weight.shape
        # 传送数据
        self.send_data(input, 'input')
        self.send_data(weight, 'weight')
        # 传送指令
        self.send_instr(m, p, n)
        # 等待计算完成
        self.send_flag()
        self.wait_flag()
        # 接受数据
        output_arr = self.recv_output((m, p))
        return output_arr

    def send_data(self, data, block_name, offset='default'):
        '''
        写入input或weight至bram
            假设两个矩阵分别是(m,n) x (n,p), m和p的维度需要补全至self.systolic_size的倍数，
            并且写入时需要按照补零的方向写入，例如：
                1. 矩阵(m, n)是m补零，则m个m个写入BRAM中。（行方向补零，列方向写入）
                2. 矩阵(n, p)是p补零，则p个p个写入BRAM中。（列方向补零，行方向写入）
            Args:
                data: 要写入的数据
                block_name: input, weight
                offset: 偏移地址名称，默认为default
        '''
        # 对数据进行对齐处理
        if block_name == 'input':
            # 转置：写入时需要按照补零的方向写入
            data = data.T
        data = self._zero_padding(data)
        self.bram.write(data, block_name=block_name, offset=offset)

    def send_instr(self, m, p, n):
        '''构建并发送指令
            两个矩阵shape分别为(m,n) x (n,p)
        '''
        # 63:48       47:32             31:16       15：0
        # null        inputN/weightN    weightP     inputM
        ir = 0
        # inputN/weightN
        ir <<= 16
        ir += n
        # weightP
        ir <<= 16
        ir += p
        # inputM
        ir <<= 16
        ir += m
        # 使用小端序
        instr = ir.to_bytes(8, byteorder='little', signed=False)
        # print(f"[instr]:\t{instr}")
        self.bram.write(instr, block_name='ir', offset='instr')

    # 写入flag信息
    def send_flag(self):
        '''发送flag=1信号'''
        # 左侧是地址地位
        flag = b"\x01\x00\x00\x00"
        self.bram.write(flag, 'ir', offset='flag')

    # 读取flag信息
    def read_flag(self):
        '''读取flag信号'''
        flag = self.bram.read(1, block_name='ir', offset='flag')[0]
        return flag

    def wait_flag(self):
        '''等待flag=1信号'''
        value = 1
        while value != 0:
            value = self.read_flag()

    def recv_output(self, output_shape: tuple):
        '''接收结果
            Args:
                output_shape: 输出的shape，类型tuple
            Return:
                output_arr: shape为output_shape的np.ndarray
        '''
        row, col = output_shape
        output_arr = self.bram.read(len=row * col * 4,
                                    block_name='output',
                                    dtype=np.int32).reshape(row, col)
        # print(f"output is:\n {output_arr}")
        return output_arr

    def _zero_padding(self, data):
        if data.shape[1] % self.systolic_size != 0:
            row = data.shape[0]
            col = self.systolic_size - data.shape[1] % self.systolic_size
            data = np.hstack((data, np.zeros((row, col), dtype=data.dtype)))
        return data

# ReLU激活函数
class ReLU(object):
    '''ReLU激活函数'''
    def __call__(self, x):
        return self.forward(x)

    # ReLU：大于0保留，小于等于0的部分置0
    def forward(self, x):
        return np.maximum(0, x, dtype=x.dtype)

# 全连接层
# 使用方法为:
# dense = Dense(weights, bias, quantization_parameters, matmul=matmul)
# output = dense(x)
class Dense(object):
    '''全连接层
        输入: int8
        输出: int8
    '''
    # weights: 权重
    # bias: 偏置
    # quantization_parameters: 量化参数
    # matmul: 矩阵乘法算子，np.matmul / Matmul()
    def __init__(self, w, b, quantization_parameters: Quantization, matmul=np.matmul):
        self.w = w
        self.b = b
        # 量化参数--------------------------------
        # 量化尺度
        self.scale = quantization_parameters.get_scale()
        # 量化零点
        self.zero_point = quantization_parameters.get_zero_point()
        # 矩阵乘法算子：可选为np或matmul
        self.matmul = matmul

    def __call__(self, x):
        input_data = x.astype(np.int32)
        output = np.clip(self.forward(input_data), -128, 127).astype(np.int8)
        return output

    def forward(self, x):
        # 权重数据量化
        w = self.w - self.zero_point['weight']
        # 输入数据量化
        input_data = x - self.zero_point['input']
        # 矩阵乘法算子为Matmul时，将输入数据转换为uint8
        if isinstance(self.matmul, Matmul):
            input_data = input_data.astype(np.uint8)

        # 矩阵乘法
        output = self.matmul(input_data, w.T) + self.b
        # 量化输出
        output = self.scale * output
        # 加上量化零点
        output = output + self.zero_point['output']
        return output

# 卷积层
# 使用方法为:
# conv2d = Conv2D(weights, bias, quantization_parameters, pad='VALID', stride=(1,1), matmul=matmul)
# output = conv2d(x)
class Conv2D(object):
    '''卷积层
        输入: int8
        输出: int8
    '''
    def __init__(self, w, b, quantization_parameters, pad='SAME', stride=(1,1), matmul=np.matmul):
        self.w = w
        self.b = b
        # 量化参数--------------------------------
        # 量化尺度
        self.scale = quantization_parameters.get_scale()
        # 量化零点
        self.zero_point = quantization_parameters.get_zero_point()

        # 卷积参数--------------------------------
        # 填充方式
        self.pad=pad
        # 卷积步长
        self.stride=stride
        # 矩阵乘法算子
        self.matmul = matmul

    def __call__(self, x):
        # 输入数据量化
        input_data = x.astype(np.int32)
        # 输出数据量化
        output = np.clip(self.forward(input_data), -128, 127).astype(np.int8)
        return output

    # 计算卷积输出大小
    def _calc_size(self, h, kernel_size, pad, stride):
        """计算卷积输出大小
        Args:
            h: input image size.输入图像大小
            kernel_size: kernel size.卷积核大小
            pad: padding strategy.填充策略
            stride: stride.移动步长
        Returns:
            s: output size.
        """

        # valid策略为不填充
        if pad == 'VALID':
            return np.ceil((h - kernel_size + 1) / stride)
        # same策略为填充至输出大小为输入大小的整数倍
        elif pad == 'SAME':
            return np.ceil(h / stride)
        # 手动填充
        else:
            return int(np.ceil((h - kernel_size + pad + 1) / stride))

    def _calc_pad(self, pad, in_siz, out_siz, stride, ksize):
        """计算卷积填充部分的大小
        Args:
            pad: padding method, "SAME", "VALID", or manually speicified.
            ksize: kernel size [I, J].
        Returns:
            pad_: 实际填充大小
        """
        # valid策略为不填充
        if pad == 'VALID':
            return 0
        # same策略为填充至输出大小为输入大小的整数倍
        elif pad == 'SAME':
            return max((out_siz - 1) * stride + ksize - in_siz, 0)
        else:
            return pad

    # 计算数组偏移量，按照字节byte进行计算
    def _array_offset(self, x):
        if x.base is None:
            return 0

        base_start = x.base.__array_interface__['data'][0]
        start = x.__array_interface__['data'][0]
        return start - base_start

    # 提取滑动窗口
    def _extract_sliding_windows(self, data, ksize, pad, stride, floor_first=True):
        """Converts a tensor to sliding windows.
        Args:
            x: [N, H, W, C]
            k: [KH, KW]
            pad: [PH, PW]
            stride: [SH, SW]
        Returns:
            y: [N, (H-KH+PH+1)/SH, (W-KW+PW+1)/SW, KH * KW, C]
        """
        # batch size
        n = data.shape[0]
        # 输入高度
        h = data.shape[1]
        # 输入宽度
        w = data.shape[2]
        # 通道数
        c = data.shape[3]
        # 卷积核高度
        kh = ksize[0]
        # 卷积核宽度
        kw = ksize[1]
        # 垂直步长
        sh = stride[0]
        # 水平步长
        sw = stride[1]

        # 计算输出特征图大小
        output_height = int(self._calc_size(h, kh, pad, sh))
        output_width  = int(self._calc_size(w, kw, pad, sw))
        # 计算卷积填充大小
        pad_height = int(self._calc_pad(pad, h, output_height, sh, kh))
        pad_width  = int(self._calc_pad(pad, w, output_width, sw, kw))

        # 计算卷积填充大小
        ph0 = int(np.floor(pad_height / 2))
        ph1 = int(np.ceil (pad_height / 2))
        pw0 = int(np.floor(pad_width  / 2))
        pw1 = int(np.ceil (pad_width  / 2))

        # 计算卷积填充大小
        # 根据floor_first决定填充顺序：floor_first是指先填充0，再填充1
        if floor_first:
            pph, ppw = (ph0, ph1), (pw0, pw1)
        else:
            pph, ppw = (ph1, ph0), (pw1, pw0)

        # 填充数据
        # 对输入数据进行填充
        data = np.pad(
            data,     # 输入数组
            (
              (0, 0), # batch维度不填充
              pph,    # 高度维度填充
              ppw,    # 宽度维度填充
              (0, 0)  # 通道维度不填充
            ),
            mode='constant',           # 填充模式：常数
            constant_values=(0.0, )    # 填充值：0
        )

        # The following code extracts window without copying the data:
        # y = np.zeros([n, h_output, w_output, kh, kw, c])
        # for ii in range(h_output):
        #     for jj in range(w_output):
        #         xx = ii * sh
        #         yy = jj * sw
        #         y[:, ii, jj, :, :, :] = x[:, xx:xx + kh, yy:yy + kw, :]

        # 计算步长
        x_sn, x_sh, x_sw, x_sc = x.strides  # 获取原始数组的步长
        # 计算输出数组的步长
        y_strides = (
            x_sn,           # batch维度步长
            sh * x_sh,      # 输出高度维度步长
            sw * x_sw,      # 输出宽度维度步长
            x_sh,           # 卷积核高度维度步长
            x_sw,           # 卷积核宽度维度步长
            x_sc            # 通道维度步长
        )
        # 创建视图
        y = np.ndarray(
            (n, output_height, output_width, kh, kw, c),  # 输出形状
            dtype=x.dtype,           # 数据类型
            buffer=x.data,           # 数据缓冲区：数据存储的内存地址
            offset=self._array_offset(x),  # 数组偏移量
            strides=y_strides       # 步长
        )
        return y

    def _calc(self, data, weight, pad, stride):
        '''将卷积核每次移动的感受野制作成矩阵
            Args:
                data: [N, H, W, C]
                w: [KH, KW, KC, KN]
                pad: [PH, PW]
                stride: [SH, SW]
            Return:
                data: 感受野数据的矩阵形式
                  - 行表示kernel的移动次数
                  - 列对应kernel大小（也有可能是通道深度）
                xs: (N, H', W', KH, KW, KC), 即图片数量、卷积输出高、卷积输出宽、kernel高、kernel宽、每个kernel通道数
        '''
        ksize = weight.shape[:2]
        # 从原始输入数据中提取感受视野
        data = self._extract_sliding_windows(data, ksize, pad, stride)
        
        # 将权重数据进行展平
        weight_shape = weight.shape
        weight = weight.reshape([weight_shape[0] * weight_shape[1] * weight_shape[2], weight_shape[3]])
        # 将感受视野数据进行展平
        data_shape = data.shape
        data = data.reshape([data_shape[0] * data_shape[1] * data_shape[2], -1])
        
        # 矩阵乘法算子为Matmul时，将输入数据转换为uint8
        if isinstance(self.matmul, Matmul):
            data = data.astype(np.uint8)
        # 利用矩阵乘法进行卷积操作
        y = self.matmul(data, weight)
        # 将结果进行reshape，恢复到卷积输出的形状
        y = y.reshape([data_shape[0], data_shape[1], data_shape[2], -1])
        return y

    # 卷积层前向传播
    def forward(self, x):
        # 输入数据量化
        input_data = x - self.zero_point['input']
        # 权重数据量化
        w = self.w - self.zero_point['weight']
        # 权重数据转置
        w = w.transpose(1,2,3,0)
        # 计算卷积输出
        output = self._calc(input_data, w, self.pad, self.stride)
        # 加上偏置
        output += self.b
        # 量化输出
        output = self.scale * output
        # 加上量化零点
        output += self.zero_point['output']
        # 输出数据截断
        output = np.clip(output, -128, 127)
        return output

# 池化层
# 使用方法为:
# maxpooling = Pooling(ksize=(2,2), method='max', pad=False)
# output = maxpooling(x)
class Pooling(object):
    '''池化层，可使用最大池化方式或者平均池化方式
        输入: int8
        输出: int8
    '''
    # ksize:滤波器大小
    # method:池化方法，max/min
    # pad:是否进行填充
    def __init__(self, ksize, method, pad=False):
        '''
          Args:
              ksize: tuple, (ky, kx)
              method: str, 'max': 最大池化
                          'mean': 平均池化
              pad: bool, 是否进行填充
          Return:
              返回池化层结果矩阵
        '''
        self.ksize = ksize
        self.method = method
        self.pad = pad

    def __call__(self, x):
        '''
            Args:
                x: ndarray, [N, H, W, C]
        '''
        input_data = x.astype(np.int32)
        output = np.clip(self.forward(input_data), -128, 127).astype(np.int8)
        return output

    def forward(self, x):
        # 将输入数据进行转置，将通道维度放在最后
        mat = x.transpose(1,2,0,3)
        # 获取输入数据的高度和宽度
        m, n = mat.shape[:2]
        # 获取池化核的大小
        ky, kx = self.ksize
        
        # 计算池化输出的大小的lambda函数：除并向上取整
        _ceil = lambda x, y: int(np.ceil(x / float(y)))
        # 利用向上取整的特性进行填充
        if self.pad:
            # 计算池化输出的高度
            ny = _ceil(m, ky)
            # 计算池化输出的宽度
            nx = _ceil(n, kx)
            # 计算池化输出的大小
            size = (ny * ky, nx * kx) + mat.shape[2:]
            # 创建一个全为nan的数组，用于填充
            mat_pad = np.full(size, np.nan)
            # 将输入数据填充到池化输出中
            mat_pad[:m, :n, ...] = mat
        else:
            ny = m // ky
            nx = n // kx
            mat_pad = mat[:ny*ky, :nx*kx, ...]

        new_shape = (ny, ky, nx, kx) + mat.shape[2:]

        # 根据池化方法进行池化
        if self.method == 'max':
            result = np.nanmax(mat_pad.reshape(new_shape), axis=(1,3))
        elif self.method == 'mean':
            result = np.nanmean(mat_pad.reshape(new_shape), axis=(1,3))
        else:
            raise ValueError('Pooling operator does not support method %s' % self.method)

        # 将结果进行转置，将通道维度放在最后
        return result.transpose(2,0,1,3)


# 展平层
class Flatten(object):
    '''将矩阵展平'''
    def __call__(self, x):
        return self.forward(x)

    # 展平层前向传播：利用reshape进行展平
    def forward(self, x):
        return x.reshape(x.shape[0], -1)

if __name__ == '__main__':

    Logger('DEBUG')
    logger = Logger.get_logger()

    matmul = Matmul()
    # np.random.seed(0)

    # 随机数种子固定
    np.random.seed(0)

    ############ matrix 1
    x = np.random.randint(0, 2, (4,8), dtype=np.uint8)
    w = np.random.randint(-1, 2, (8,4), dtype=np.int8)
    #x = np.ones( [ 16 , 16 ]  , dtype = np.uint8)
    #w = np.ones( [ 16 , 16 ]  , dtype = np.int8)

    std_output = np.matmul( x , w )
    output = matmul(x, w)

    err = output - std_output
    logger.debug( err )
    assert( (output == std_output).all() )


    ############ matrix 2
    x = np.random.randint(0, 5, (16,20), dtype=np.uint8)
    w = np.random.randint(-5, 5, (20,10), dtype=np.int8)
    # x = np.ones( [ 16 , 16 ]  , dtype = np.int8) * 2
    # w = np.ones( [ 16 , 16 ]  , dtype = np.int8) * 2

    output = matmul(x, w)
    std_output = np.matmul( x , w )

    err = output - std_output
    logger.debug( err )
    assert( (output == std_output).all() )