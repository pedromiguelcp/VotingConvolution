<h1> Voting convolution </h1>

<p> Hardware implementation of the voting scheme-based convolution. The proposed hardware design was empowered with the ability to detect the presence of null filter weights to discard unnecessary calculations and use stride to reduce the communication between components to the minimum necessary, leading to overall improvements of around 55% in processing time.</p>

<h1 align="center">
    <img alt="Voting_architecture" title="Voting_architecture" src="Voting_architecture.png" />
</h1>

<p> Despite of beeing a sparse convolution, it is an operation mathematically equivalent to a dense convolution.</p>

<h1 align="center">
    <img alt="operation" title="operation" src="operation.png" />
</h1>

<p> Tests case for a convolution in dense data.</p>

<h1 align="center">
    <img alt="Voting_conv_test" title="Voting_conv_test" src="Voting_conv_test.png" />
</h1>


<p> Processing time comparasion with the dense convolution.</p>

<h1 align="center">
    <img alt="Sparsity_graph" title="Sparsity_graph" src="Sparsity_graph.png" />
</h1>

<p> Null weights effect on processing time.</p>

<h1 align="center">
    <img alt="Null_weights_graph" title="Null_weights_graph" src="Null_weights_graph.png" />
</h1>



<br>
<h4 align="center">
    Made with ❤ by pedromiguelcp. Project under development. 🖥⌨🖱

    Contact me.pedropereira@gmail.com for more information!
</h4>
