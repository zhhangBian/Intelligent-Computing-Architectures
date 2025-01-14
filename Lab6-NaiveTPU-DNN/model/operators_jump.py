# -*-coding: utf-8-*-
import numpy as np
np.set_printoptions(threshold=np.inf)
from multiprocessing import Process
import os, sys
sys.path.append(os.path.abspath('.'))   # 添加路径信息否则无法引用到tools

from tools import *

# 此文件中包含神经网络推理算子的具体实现

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
        # # 对数据进行对齐处理
        # if block_name == 'input':
        #     # 转置：写入时需要按照补零的方向写入
        #     data = data.T
        # data = self._zero_padding(data)
        # self.bram.write(data, block_name=block_name, offset=offset)
        
        # 对数据进行对齐处理
        if block_name == 'input':
            # 转置：写入时需要按照补零的方向写入
            data = data.T

        n, p = data.shape
        p = p if p % self.systolic_size == 0 else (p // self.systolic_size + 1) * self.systolic_size

        # C语言风格的内存布局：行优先
        data = data.copy(order='C')

        for i in range(n):
            self.bram.write(data[i], block_name=block_name, offset=i * p)

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
    '''relu激活函数'''
    def __call__(self, x):
        return self.forward(x)

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
    def __init__(self, w, b, quantization_parameters, matmul=np.matmul):
        self.w = w
        self.b = b
        self.scale = quantization_parameters.get_scale()
        self.zero_point = quantization_parameters.get_zero_point()
        self.matmul = matmul

    def __call__(self, x):
        input_data = x.astype(np.int32)
        output = np.clip(self.forward(input_data), -128, 127).astype(np.int8)
        return output

    def forward(self, x):
        w = self.w - self.zero_point['weight']
        input_data = x - self.zero_point['input']

        if isinstance(self.matmul, Matmul):
            input_data = input_data.astype(np.uint8)
        output = self.matmul(input_data, w.T) + self.b

        output = self.scale * output
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
        self.scale = quantization_parameters.get_scale()
        self.zero_point = quantization_parameters.get_zero_point()
        self.pad=pad
        self.stride=stride
        self.matmul = matmul

    def __call__(self, x):
        input_data = x.astype(np.int32)
        output = np.clip(self.forward(input_data), -128, 127).astype(np.int8)
        return output

    def calc_size(self, h, kh, pad, sh):
        """Calculate output image size on one dimension.

        Args:
            h: input image size.
            kh: kernel size.
            pad: padding strategy.
            sh: stride.

        Returns:
            s: output size.
        """

        if pad == 'VALID':
            return np.ceil((h - kh + 1) / sh)
        elif pad == 'SAME':
            return np.ceil(h / sh)
        else:
            return int(np.ceil((h - kh + pad + 1) / sh))

    def calc_pad(self, pad, in_siz, out_siz, stride, ksize):
        """Calculate padding width.

        Args:
            pad: padding method, "SAME", "VALID", or manually speicified.
            ksize: kernel size [I, J].

        Returns:
            pad_: Actual padding width.
        """
        if pad == 'SAME':
            return max((out_siz - 1) * stride + ksize - in_siz, 0)
        elif pad == 'VALID':
            return 0
        else:
            return pad

    def array_offset(self, x):
        """Get offset of array data from base data in bytes."""
        if x.base is None:
            return 0

        base_start = x.base.__array_interface__['data'][0]
        start = x.__array_interface__['data'][0]
        return start - base_start

    def extract_sliding_windows(self, x, ksize, pad, stride, floor_first=True):
        """Converts a tensor to sliding windows.

        Args:
            x: [N, H, W, C]
            k: [KH, KW]
            pad: [PH, PW]
            stride: [SH, SW]

        Returns:
            y: [N, (H-KH+PH+1)/SH, (W-KW+PW+1)/SW, KH * KW, C]
        """
        n = x.shape[0]
        h = x.shape[1]
        w = x.shape[2]
        c = x.shape[3]
        kh = ksize[0]
        kw = ksize[1]
        sh = stride[0]
        sw = stride[1]

        h2 = int(self.calc_size(h, kh, pad, sh))
        w2 = int(self.calc_size(w, kw, pad, sw))
        ph = int(self.calc_pad(pad, h, h2, sh, kh))
        pw = int(self.calc_pad(pad, w, w2, sw, kw))

        ph0 = int(np.floor(ph / 2))
        ph1 = int(np.ceil(ph / 2))
        pw0 = int(np.floor(pw / 2))
        pw1 = int(np.ceil(pw / 2))

        if floor_first:
            pph = (ph0, ph1)
            ppw = (pw0, pw1)
        else:
            pph = (ph1, ph0)
            ppw = (pw1, pw0)
        x = np.pad(
            x, ((0, 0), pph, ppw, (0, 0)),
            mode='constant',
            constant_values=(0.0, ))

        # The following code extracts window without copying the data:
        # y = np.zeros([n, h2, w2, kh, kw, c])
        # for ii in range(h2):
        #     for jj in range(w2):
        #         xx = ii * sh
        #         yy = jj * sw
        #         y[:, ii, jj, :, :, :] = x[:, xx:xx + kh, yy:yy + kw, :]
        x_sn, x_sh, x_sw, x_sc = x.strides  # batch_size, height, width, channel
        y_strides = (x_sn, sh * x_sh, sw * x_sw, x_sh, x_sw, x_sc)
        y = np.ndarray((n, h2, w2, kh, kw, c),
                    dtype=x.dtype,
                    buffer=x.data,
                    offset=self.array_offset(x),  # 0
                    strides=y_strides)
        return y

    def calc(self, x, w, pad, stride):
        '''将卷积核每次移动的感受野制作成矩阵

            Args:
                x: [N, H, W, C]
                w: [KH, KW, KC, KN]
                pad: [PH, PW]
                stride: [SH, SW]

            Return:
                x: 感受野数据的矩阵形式，行表示kernel的移动次数，列对应kernel大小（也有可能是通道深度）
                xs: (N, H', W', KH, KW, KC), 即图片数量、卷积输出高、卷积输出宽、kernel高、kernel宽、每个kernel通道数
        '''
        ksize = w.shape[:2]
        x = self.extract_sliding_windows(x, ksize, pad, stride)
        ws = w.shape
        w = w.reshape([ws[0] * ws[1] * ws[2], ws[3]])
        xs = x.shape
        x = x.reshape([xs[0] * xs[1] * xs[2], -1])

        if isinstance(self.matmul, Matmul):
            x = x.astype(np.uint8)
        y = self.matmul(x, w)

        y = y.reshape([xs[0], xs[1], xs[2], -1])
        return y

    def forward(self, x):
        input_data = x - self.zero_point['input']
        w = self.w - self.zero_point['weight']
        w = w.transpose(1,2,3,0)
        output = self.calc(input_data, w, self.pad, self.stride)
        output += self.b
        output = self.scale * output
        output += self.zero_point['output']
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
            pad: bool

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
        mat = x.transpose(1,2,0,3)

        m, n = mat.shape[:2]
        ky, kx = self.ksize

        _ceil = lambda x, y: int(np.ceil(x / float(y)))

        if self.pad:
            ny = _ceil(m, ky)
            nx = _ceil(n, kx)
            size = (ny * ky, nx * kx) + mat.shape[2:]
            mat_pad = np.full(size, np.nan)
            mat_pad[:m, :n, ...] = mat
        else:
            ny = m // ky
            nx = n // kx
            mat_pad = mat[:ny*ky, :nx*kx, ...]

        new_shape = (ny, ky, nx, kx) + mat.shape[2:]

        if self.method == 'max':
            result = np.nanmax(mat_pad.reshape(new_shape), axis=(1,3))
        elif self.method == 'mean':
            result = np.nanmean(mat_pad.reshape(new_shape), axis=(1,3))
        else:
            raise ValueError('Pooling operator does not support method %s' % self.method)

        # result = np.clip(result, -128, 127)
        return result.transpose(2,0,1,3)


# 展平层
class Flatten(object):
    '''将矩阵展平'''
    def __call__(self, x):
        return self.forward(x)

    def forward(self, x):
        return x.reshape(x.shape[0], -1)


# 量化参数
class Quantization(object):
    '''层级量化参数存储和处理'''
    def __init__(self, scale, zero_point):
        '''
            Args:
                scale: dict, 包含input, weight, output
                zero_point: dict, 包含input, weight, output
        '''
        # 检查scale和zero_point是否符合要求
        assert type(scale) is dict
        assert type(zero_point) is dict
        self.__check_dict(scale)
        self.__check_dict(zero_point)

        self.scale = scale
        self.zero_point = zero_point

        # 将字典值转换为ndarray
        self.__val2ndarray(self.scale)
        self.__val2ndarray(self.zero_point)

    def __check_dict(self, x):
        if ('input' in x) and ('weight' in x) and ('output' in x) == False:
            raise KeyError('scale or zero_point must have input, weight and output items')

    def __val2ndarray(self, x):
        for key in x:
            x[key] = np.array(x[key])

    def get_ori_scale(self):
        return self.scale

    def get_scale(self):
        '''
            Return:
                input_scale * weight_scale / output_scale
        '''
        return self.scale['input'] * self.scale['weight'] / self.scale['output']

    def get_zero_point(self):
        return self.zero_point

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