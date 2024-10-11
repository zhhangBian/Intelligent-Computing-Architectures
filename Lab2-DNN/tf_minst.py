import datetime
import time
import tensorflow as tf
import matplotlib.pyplot as plt

from tf_network import LeNet
from tf_data import get_train_test_data


def plot_loss(loss):
    plt.plot(loss)
    plt.title('net loss')
    plt.ylabel('loss')
    plt.xlabel('epoch')
    plt.show()


if __name__ == "__main__":
    program_start_time = time.time()
    # 创建 TensorBoard 的日志写入器
    current_time = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
    log_dir = 'logs/' + current_time
    writer = tf.summary.create_file_writer(log_dir)

    train_db, test_db = get_train_test_data()

    batch = 32

    # 创建模型
    net = LeNet(input_shape=(batch, 32, 32, 1))

    # 输出模型的summary信息
    # net.summary()

    # 训练
    history = net.train(train_db, epoch=50, log_dir=log_dir)
    plot_loss(history['loss'])

    net.test(test_db)

    writer.close()
