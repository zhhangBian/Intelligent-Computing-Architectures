import tensorflow as tf


def dense_to_one_hot(x, y):
    x = tf.cast(x, dtype=tf.float32) / 255.
    x = tf.reshape(x, [-1, 32, 32, 1])
    y = tf.one_hot(y, depth=10)  # one_hot 编码
    return x, y


def _get_train_data(x_train, y_train):
    train_db = tf.data.Dataset.from_tensor_slices((x_train, y_train)).shuffle(10000)
    train_db = train_db.batch(128)
    train_db = train_db.map(dense_to_one_hot)

    return train_db


def _get_test_data(x_test, y_test):
    test_db = tf.data.Dataset.from_tensor_slices((x_test, y_test)).shuffle(10000)
    test_db = test_db.batch(128)
    test_db = test_db.map(dense_to_one_hot)

    return test_db


def get_train_test_data():
    # load mnist
    (x_train, y_train), (x_test, y_test) = tf.keras.datasets.fashion_mnist.load_data()

    # padding 28*28 to 32*32
    paddings = tf.constant([[0, 0], [2, 2], [2, 2]])
    x_train = tf.pad(x_train, paddings)
    x_test = tf.pad(x_test, paddings)

    train_db = _get_train_data(x_train, y_train)
    test_db = _get_test_data(x_test, y_test)

    return train_db, test_db
