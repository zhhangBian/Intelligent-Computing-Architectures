# -*-coding: utf-8-*-
import numpy as np
import mmap
import os, sys

class BramConfig(object):
    # BRAM信息配置
    # **代表以字典形式传递参数，会进行解包
    def _construct_block_info(address, size, **offset) -> dict:
        '''
        构造block信息
            Args:
                name: 块名称
                address: 块起始地址
                size: 块大小
                offset: 偏移量，字典

            Return:
                返回字典，包含address, size, offset字段。
                其中offset是一个字典，表示各块内偏移的用途
        '''
        info = {
            'address': address,
            'size': size,
            'offset': offset
        }
        return info


    # 用于存储需要计算的信息
    # 若块内偏移量无特殊含义，则约定key为default，值为0，可根据实际需求修改
    block_info = {
        # 输入的矩阵数据 M*N
        'input': _construct_block_info(
            address=0x40000000,
            size=32*1024,   # 32KB
            **{'default': 0x0}
        ),

        # 权重矩阵 N*P
        'weight': _construct_block_info(
            address=0x40020000,
            size=128*1024,  # 128KB
            **{'default': 0x0}
        ),

        # 输出
        'output': _construct_block_info(
            address=0x40040000,
            size=32*1024,   # 32KB
            **{'default': 0x0}
        ),

        # 存储标记和指令，对应偏移量名称为 flag，instr
        # 63:48       47:32             31:16       15：0
        # null        inputN/weightN    weightP     inputM
        # flag用于PS，PL交互
        # 从块头部开始存储，instr从偏移0x10字节的位置开始存储
        'ir': _construct_block_info(
            address=0x40060000,
            size=4*1024,    # 4KB
            **{'flag': 0x0, 'instr': 0x10}
        )
    }

# 对挂载的BRAM进行读写，分别为write和read方法
class BRAM(object):
    '''实现对Bram读写的类，需要先配置BramConfig类'''
    def __init__(self):
        self.block_info = BramConfig.block_info
        self.block_map = self._mapping('/dev/mem')

    def __del__(self):
        os.close(self.file)
        for block_name, block_map in self.block_map.items():
            block_map.close()

    # 将文件映射到内存中，以像访问内存一样访问文件的内容
    def _mapping(self, path):
        # 将路径打开为文件描述符
        # 权限控制，表示 只读 | 文件写后即同步
        self.file = os.open(path, os.O_RDWR | os.O_SYNC)

        # 建立内存映射关系
        block_map = {}
        for name, info in self.block_info.items():
            # 使用mmap.mmap创建一个内存映射对象
            block_map[name] = mmap.mmap(
                self.file,    # 打开的文件的文件描述符
                info['size'], # 块大小
                flags=mmap.MAP_SHARED,  # 创建一个可共享的内存映射
                prot=mmap.PROT_READ | mmap.PROT_WRITE,  # 映射区域的保护权限是可读可写
                offset=info['address']  # 块在文件中的偏移地址
            )
        return block_map

    # 将data写道block块的offset偏移量处
    def write(self, data, block_name: str, offset='default'):
        '''写入数据
            由于数据位宽32bit，因此最好以4的倍数Byte写入(还不知道以1Byte单位写进去会有什么效果)
            Args：
                data: 输入的数据，可为np.arry或bytes
                block_name: BramConfig中配置的block_info的key值
                offset: BramConfig中配置的offset字典的key值，用于寻找真正的offest
        '''
        # 展平为一维数组
        data = data.reshape(-1) if isinstance(data, np.ndarray) else data

        # 获取name对应的内存映射区域
        mem_map = self.block_map[block_name]
        # print("Data: \n%s" % data)
        mem_offset = self.block_info[block_name]['offset'][offset] if isinstance(offset, str) else offset
        # 将内存指针移动到mem_offset处
        mem_map.seek(mem_offset)
        # 通过写内存（映射）方式写文件
        mem_map.write(data)

    # 读len**字节**的数据，以dtype形式返回
    def read(self, len, block_name, offset='default', dtype=np.uint8) -> np.ndarray:
        '''
        按字节依次从低字节读取
            Args：
                len: 读取数据长度，单位字节
                block_name: BramConfig中配置的block_info的key值
                offset: BramConfig中配置的offset字典key值
                dtype: 要求数据按相应的格式输出，
                        np.int8, np.int16, np.int32, np.int64,
                        np.uint8, np.uint16, np.uint32, np.uint64

            Return:
                np.adarray
        '''
        # print("Read data from BRAM via AXI_bram_ctrl_1")
        mem_map = self.block_map[block_name]
        mem_offset = self.block_info[block_name]['offset'][offset]
        mem_map.seek(mem_offset)

        data = []
        for _ in range(len):
            data.append(mem_map.read_byte())
        # 初始数据类型为np.uint8
        data = np.array(data, dtype=np.uint8)
        # 按dtype整理数据
        data.dtype=dtype

        return data


if __name__ == '__main__':
    # 创建BRAM类实例
    bram = BRAM()

    # 向input块中写入int8类型的ndarray
    data_wirte = np.random.randint(-1, 2, (8,4), dtype=np.int8)
    bram.write(data_wirte, 'input')
    print('write data')
    print(data_wirte)
    print()

    data_read = bram.read(data_wirte.size, 'input', dtype=np.int8).reshape(8,4)
    print('read data')
    print(data_read)
    print()

    # 向ir块中写入flag信息
    # 最左侧字节存储在低地址处，往右依次存储在更高地址
    flag_00 = b"\x00\x00\x00\x00"
    flag_01 = b"\x01\x00\x00\x00"

    bram.write(flag_00, 'ir', offset='flag')
    flag_00_read = bram.read(1, 'ir', offset='flag', dtype=np.int8)

    bram.write(flag_01, 'ir', offset='flag')
    flag_01_read = bram.read(1, 'ir', offset='flag', dtype=np.int8)

    print('write flag_00:', flag_00)
    print('read flag_00:', flag_00_read)
    print()
    print('write flag_01:', flag_01)
    print('read flag_01:', flag_01_read)
