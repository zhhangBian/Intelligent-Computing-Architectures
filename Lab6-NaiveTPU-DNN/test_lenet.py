# -*- coding: utf-8 -*-
import numpy as np
import os, sys

from model import lenet
from tools import load_mnist, Logger, Timer

Logger('INFO')  # 初始化参数
logger = Logger.get_logger()


# 输入数据量化参数
input_scale = 0.003921568859368563
input_zero_point = -128

##################### 准备数据集 ##################### 
(x_train, y_train), (x_test, y_test) = load_mnist('data/mnist.npz')
x_test = x_test / 255.

# 对输入数据进行量化处理
x_test = x_test / input_scale + input_zero_point
x_test = x_test.round().astype(np.int8)

# 加入单通道的维度
x_test = x_test[..., np.newaxis]

##################### 创建实例 ##################### 
# net = lenet.LeNetNumpy('np')
net = lenet.LeNetNumpy('Matmul')
timer = Timer()

##################### 测试模型 ##################### 
correct = 0
samples_num = 20 #len(x_test)
for i in range(samples_num):
    logger.info("{}/{}".format(i, samples_num))

    # 获取测试集中的图片和标签
    image = x_test[i][np.newaxis, :]
    label = y_test[i]   # 这里的label就是一个数字，如7，表示这张图片是7

    # 推理并记录时间
    timer.start()
    # 执行推理
    prediction = net(image)
    timer.end()
    logger.info("Inference time: {}".format(timer.current_time()))
    logger.info("Average time: {}".format(timer.avg_time()))

    # 判断推理正确性
    if np.argmax(prediction, axis=1)[0] == label:
        correct += 1
logger.info('Accuracy: {}%'.format(correct / samples_num * 100))
logger.info("Average time: {}".format(timer.avg_time()))