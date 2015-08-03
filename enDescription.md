The graph represents nodes and edges. Nodes it is functions, and edges it is calls. The edge label is inclusive time spent for this call. The node label is inclusive time spent for execution of this function, - execution time not one call, and all calls of the given function. That is if to the node there is 1 edge the edge label and a node label will coincide and if some edges the sum of labels of all edges will be equal to a node label.

Self time is time of execution of function without time of execution of its children.

Inclusive time is the sum of self time of function and all its children. That is if function does not have children "Self time" is equal "Inclusive time".

CachegrindVisualizer more informative graph builds, than KCacheGrind — on an head edge there is a label typed by a font of the smaller size, is self time spent for execution of this function, - self execution time of this call, instead of all calls of the given function.