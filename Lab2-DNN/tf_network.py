import tensorflow as tf
from tensorflow import keras
from keras.layers import *


class LeNet:
    def __init__(self, input_shape, kernel_size=(5, 5), activation='softmax'):
        self.filters = 6
        self.kernel_size = kernel_size
        self.input_shape = input_shape

        self.net = keras.Sequential([
            # layer1
            Conv2D(self.filters, kernel_size=self.kernel_size),
            MaxPooling2D(pool_size=2, strides=2),
            ReLU(),

            # layer2
            Conv2D(16, kernel_size=self.kernel_size),
            MaxPooling2D(pool_size=2, strides=2),
            ReLU(),

            # layer3
            Conv2D(120, kernel_size=self.kernel_size),
            ReLU(),
            Flatten(),

            # fc1
            Dense(84, activation='relu'),

            # fc2
            Dense(10, activation=activation)
        ])

        self.net.build(input_shape=input_shape)

    def train(self,
              train_db,
              epoch=50,
              log_dir='logs/',
              lr=0.001,
              batch_size=32,
              loss=keras.losses.CategoricalCrossentropy(),
              metrics=['accuracy'],
              verbose=1):
        self.net.compile(optimizer=keras.optimizers.Adam(lr), loss=loss, metrics=metrics)
        history = self.net.fit(train_db,
                               epochs=epoch,
                               batch_size=batch_size,
                               callbacks=[tf.keras.callbacks.TensorBoard(log_dir)],
                               verbose=verbose)

        return history

    def test(self, test_db, verbose=1):
        return self.net.evaluate(test_db, verbose=verbose)

    def save(self, path='./model'):
        tf.keras.models.save_model(self.net, path, save_format='tf')

    def summary(self):
        return self.net.summary()
