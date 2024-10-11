import tensorflow as tf
from tensorflow import keras


class LeNet:
    def __init__(self, input_shape, kernel_size=(5, 5)):
        self.filters = 6
        self.kernel_size = kernel_size
        self.input_shape = input_shape

        self.net = keras.Sequential([
            # layer1
            keras.layers.Conv2D(self.filters,
                                kernel_size=self.kernel_size),
            keras.layers.MaxPooling2D(pool_size=2, strides=2),
            keras.layers.ReLU(),

            # layer2
            keras.layers.Conv2D(16, kernel_size=self.kernel_size),
            keras.layers.MaxPooling2D(pool_size=2, strides=2),
            keras.layers.ReLU(),

            # layer3
            keras.layers.Conv2D(120, kernel_size=self.kernel_size),
            keras.layers.ReLU(),
            keras.layers.Flatten(),

            # fc1
            keras.layers.Dense(84, activation='relu'),

            # fc2
            keras.layers.Dense(10, activation='softmax')
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
