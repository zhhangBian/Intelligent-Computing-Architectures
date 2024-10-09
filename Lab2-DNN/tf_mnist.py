import tensorboard
import tensorflow as tf
import input_data
from tensorflow.python.framework.convert_to_constants import \
    convert_variables_to_constants_v2 as convert_variables_to_constants
from tf_network import LeNet
from data_object import provide_data
import datetime
import time
import os

# Disable eager execution for compatibility with TensorFlow 1.x code
tf.compat.v1.disable_eager_execution()


def train_net(train_set, val_set):
    """
    Train your network.
    The model will be saved as .pb format in ./model directory.
    :param train_set: training dataset
    :param val_set: validation dataset
    :return: None
    """
    # Initialize variables
    sess.run(tf.compat.v1.global_variables_initializer())
    train_samples = train_set.num_samples  # get number of samples
    train_images = train_set.images  # get training images
    train_labels = train_set.labels  # get training labels, noting that it is one_hot format

    print("=" * 50)
    print("\nStart training...\n")

    # Start training
    global_step = 0
    for i in range(epochs):
        total_loss = 0

        for offset in range(0, train_samples, batch_size):
            # "offset" is the start position of the index, "end" is the end position of the index.
            end = offset + batch_size
            # get images and labels according to the batch number
            batch_train_images, batch_train_labels = train_images[offset:end], train_labels[offset:end]
            _, loss, loss_summary = sess.run([training_operation, loss_operation, merge_summary],
                                             feed_dict={images: batch_train_images, labels: batch_train_labels})
            total_loss += loss

            # Record summary
            summary_writer.add_summary(loss_summary, global_step=global_step)
            global_step += 1

        validation_accuracy = test_net(val_set)
        loss_avg = total_loss * batch_size / train_samples
        print("EPOCH {:>3d}: Loss = {:.5f}, Validation Accuracy = {:.5f}".format(i + 1, loss_avg, validation_accuracy))

    # Save model
    if not os.path.exists('./model'):
        os.makedirs('./model')

    frozen_func = convert_variables_to_constants(sess, sess.graph_def, output_node_names=['output', 'loss', 'accuracy'])
    with tf.io.gfile.GFile('model/model.pb', mode='wb') as f:
        f.write(frozen_func.graph.as_graph_def().SerializeToString())

    print("=" * 50)
    print("\nThe model has been saved to ./model directory.")


def test_net(dataset):
    """
    Test your model with dataset.
    :param dataset: you can choose validation or test dataset
    :return: None
    """

    num_samples = dataset.num_samples
    data_images = dataset.images
    data_labels = dataset.labels

    total_accuracy = 0
    for offset in range(0, num_samples, batch_size):
        # "offset" is the start position of the index, "end" is the end position of the index.
        end = offset + batch_size
        # get images and labels according to the batch number
        batch_images, batch_labels = data_images[offset:end], data_labels[offset:end]
        total_accuracy += sess.run(accuracy_operation, feed_dict={images: batch_images, labels: batch_labels})

    return total_accuracy * batch_size / num_samples


if __name__ == "__main__":
    """
    To use tensorboard:
    0. Ensure your current environment has tensorboard
    1. Enter this code in the terminal: 
        tensorboard --logdir=./logs
    2. Open the URL address in your browser
    """

    # record program start time
    program_start_time = time.time()

    # create summary environment
    current_time = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
    log_dir = 'logs/' + current_time

    # Parameter configuration
    lr = 0.001  # learning rate
    batch_size = 1000  # batch size
    epochs = 10  # training period

    # Prepare training and validation datasets
    mnist = input_data.read_data_sets('mnist_data/')  # load mnist dataset
    data = provide_data(mnist)

    # Create input and output placeholders
    images = tf.compat.v1.placeholder(dtype=tf.float32, shape=[None, 28, 28, 1], name='images')
    labels = tf.compat.v1.placeholder(dtype=tf.float32, shape=[None, 10], name='labels')

    # Create instance of neural network
    net = LeNet()

    # Forward pass
    out = net.forward(images)

    # Compute loss
    cross_entropy = tf.nn.softmax_cross_entropy_with_logits(logits=out, labels=labels)
    loss_operation = tf.reduce_mean(cross_entropy, name="loss")

    # Set up optimizer
    optimizer = tf.compat.v1.train.AdamOptimizer(learning_rate=lr)
    training_operation = optimizer.minimize(loss_operation)

    # Compute accuracy
    prediction = tf.argmax(out, axis=1, name='output')
    correct_prediction = tf.equal(prediction, tf.argmax(labels, axis=1))
    accuracy_operation = tf.reduce_mean(tf.cast(correct_prediction, tf.float32), name="accuracy")

    # Create session
    with tf.compat.v1.Session() as sess:
        # Create summary scalars
        tf.compat.v1.summary.scalar('Loss', loss_operation)
        tf.compat.v1.summary.scalar('Accuracy', accuracy_operation)
        merge_summary = tf.compat.v1.summary.merge_all()
        summary_writer = tf.compat.v1.summary.FileWriter(log_dir, sess.graph)

        start_training_time = time.time()
        train_net(data.train, data.validation)
        print("Training time: {:.3f}s.\n".format(time.time() - start_training_time))

        start_testing_time = time.time()
        print("=" * 50)
        print("\nStart testing...")
        acc = test_net(data.test)
        print("Test Accuracy = {:.5f}".format(acc))
        print("Testing time: {:.5f}s\n".format(time.time() - start_testing_time))

    print("Program running time: {:.3f}s.".format(time.time() - program_start_time))
