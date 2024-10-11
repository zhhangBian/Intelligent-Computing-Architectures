import datetime
import time
import tensorflow as tf
import matplotlib.pyplot as plt

from tf_network import LeNet
from tf_data import get_train_test_data


def plot_loss(loss, filename='./img/loss.png'):
    plt.plot(loss)
    plt.title('net loss')
    plt.ylabel('loss')
    plt.xlabel('epoch')

    # plt.show()
    plt.savefig(filename)


batch = 32
epoch = 50

if __name__ == "__main__":
    program_start_time = time.time()

    current_time = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
    log_dir = 'logs/' + current_time
    writer = tf.summary.create_file_writer(log_dir)

    train_db, test_db = get_train_test_data()

    net = LeNet(input_shape=(batch, 32, 32, 1))
    net.summary()

    # train
    start_training_time = time.time()
    history = net.train(train_db, epoch=epoch, log_dir=log_dir)
    plot_loss(history.history['loss'])
    print("Training time: {:.3f}s.\n".format(time.time() - start_training_time))

    # test
    start_testing_time = time.time()
    [loss, accuracy] = net.test(test_db)
    print("Test Accuracy = {:.5f}".format(accuracy))
    print("Testing time: {:.5f}s\n".format(time.time() - start_testing_time))

    # save
    net.save()

    print("Program running time: {:.3f}s.".format(time.time() - program_start_time))
