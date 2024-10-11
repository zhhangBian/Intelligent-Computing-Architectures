import tensorflow as tf
from tensorflow import keras


class LeNet:
    def __init__(self, input_shape, kernel_size=(5, 5)):
        self.filters = 6
        self.kernel_size = kernel_size
        self.input_shape = input_shape

        self.net = keras.Sequential([
            # 卷积层1
            keras.layers.Conv2D(self.filters,
                                kernel_size=self.kernel_size),
            keras.layers.MaxPooling2D(pool_size=2, strides=2),
            keras.layers.ReLU(),

            # 卷积层2
            keras.layers.Conv2D(16, kernel_size=self.kernel_size),
            keras.layers.MaxPooling2D(pool_size=2, strides=2),
            keras.layers.ReLU(),

            # 卷积层3
            keras.layers.Conv2D(120, kernel_size=self.kernel_size),
            keras.layers.ReLU(),
            keras.layers.Flatten(),

            # 全连接层1
            # 120*84
            keras.layers.Dense(84, activation='relu'),

            # 全连接层2
            # 84*10
            keras.layers.Dense(10, activation='softmax')
        ])
        self.net.build(input_shape=input_shape)

    def train(self,
              train_db,
              epoch=50,
              log_dir='logs/',
              optimizer=keras.optimizers.Adam(),
              loss=keras.losses.CategoricalCrossentropy(),
              metrics=['accuracy']):
        self.net.compile(optimizer=optimizer, loss=loss, metrics=metrics)
        history = self.net.fit(train_db,
                               epochs=epoch,
                               callbacks=[tf.keras.callbacks.TensorBoard(log_dir)])

        return history

    def test(self, test_db):
        return self.net.evaluate(test_db)
