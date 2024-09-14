import numpy as np


# neural network class
class neuralNetwork:

    # initialize the neural network
    def __init__(self, input_nodes, hidden_nodes, hidden_depth, output_nodes, learning_rate=0.1):
        """
        The network consists of three layers: input layer, hidden layer and output layer.
        Here defined these layers.
        :param input_nodes: dimension of input
        :param hidden_nodes: dimension of hidden nodes
        :param output_nodes: dimension of output
        :param learning_rate: the learning rate of neural network
        """
        # set number of nodes in each input, hidden, output layer
        self.input_nodes = input_nodes
        self.hidden_nodes = hidden_nodes
        self.hidden_depth = hidden_depth
        self.output_nodes = output_nodes

        # Some parameters that will be used next
        self.inputs = None  # input data
        # the output of hidden layer
        self.hidden_outputs_list = [None for _ in range(hidden_depth)]
        self.final_outputs = None  # the output of output layer
        self.learning_rate = learning_rate  # learning rate

        # link weight matrices, wih and who
        # weights inside the arrays are w_i_j, where link is from node i to node j in the next layer
        # w11 w21
        # w12 w22 etc

        # init the weight of input layers to hidden layers
        self.wih = np.random.normal(0.0, pow(self.input_nodes, -0.5),
                                    (self.hidden_nodes, self.input_nodes))
        # init the weight of hidden layers to hidden layers
        self.whh_list = [np.random.normal(0.0, pow(self.hidden_nodes, -0.5),
                                          (self.hidden_nodes, self.hidden_nodes))
                         for _ in range(hidden_depth - 1)]
        # init the weight of hidden layers to output layers
        self.who = np.random.normal(0.0, pow(self.hidden_nodes, -0.5),
                                    (self.output_nodes, self.hidden_nodes))

        # activation function is the sigmoid function
        self.activation_function = lambda x: 1. / (1 + np.exp(-x))

    def forward(self, input_feature):
        """
        Forward the neural network
        :param input_feature: single input image, flattened [784, ]
        """
        # convert inputs list to 2d array
        self.inputs = np.array(input_feature, ndmin=2).T

        # calculate signals into hidden layer
        hidden_inputs = np.dot(self.wih, self.inputs)
        for i in range(self.hidden_depth):
            self.hidden_outputs_list[i] = self.activation_function(hidden_inputs)
            hidden_inputs = np.dot(self.whh_list[i - 1], self.hidden_outputs_list[i])

        # calculate the signals emerging from hidden layer
        # self.hidden_outputs = self.activation_function(hidden_inputs)

        # calculate signals into final output layer
        final_inputs = np.dot(self.who, self.hidden_outputs_list[self.hidden_depth - 1])
        # calculate the signals emerging from final output layer
        self.final_outputs = self.activation_function(final_inputs)

    def backpropagation(self, targets_list):
        """
        Propagate backwards
        :param targets_list: output onehot code of a single image, [10, ]
        """
        targets = np.array(targets_list, ndmin=2).T

        # loss
        loss = np.sum(np.square(self.final_outputs - targets)) / 2

        # output layer error is the (final_outputs - target)
        output_error = self.final_outputs - targets
        # 计算输出层的梯度
        output_delta = output_error * self.final_outputs * (1.0 - self.final_outputs)

        # update the weights for the links between the hidden and output layers
        self.who -= self.learning_rate * np.dot(output_delta,
                                                np.transpose(self.hidden_outputs_list[self.hidden_depth - 1]))

        # hidden layer error
        hidden_error = [None for _ in range(self.hidden_depth)]
        hidden_delta = [None for _ in range(self.hidden_depth)]

        # calculate hidden layer error and delta
        for i in reversed(range(self.hidden_depth)):
            if i == self.hidden_depth - 1:
                hidden_error[i] = np.dot(self.who.T, output_delta)
                hidden_delta[i] = hidden_error[i] * self.hidden_outputs_list[i] * (1.0 - self.hidden_outputs_list[i])
            else:
                hidden_error[i] = np.dot(self.whh_list[i - 1].T, hidden_delta[i + 1])
                hidden_delta[i] = hidden_error[i] * self.hidden_outputs_list[i] * (1.0 - self.hidden_outputs_list[i])

        # update the weights for the links between the hidden layers
        for i in reversed(range(self.hidden_depth - 1)):
            self.whh_list[i] -= self.learning_rate * np.dot(hidden_delta[i + 1],
                                                            np.transpose(self.hidden_outputs_list[i]))

        # update the weights for the links between the input and hidden layers
        self.wih -= self.learning_rate * np.dot(hidden_delta[0], np.transpose(self.inputs))

        return loss
