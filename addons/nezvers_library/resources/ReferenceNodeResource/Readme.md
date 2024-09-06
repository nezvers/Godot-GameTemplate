# ReferenceNodeResource

Instead of creating references in global singleton and creating same functionality for every instance you need to reference use this resource.

Instances that fulfill same functionality, for an example a level camera, should `add(self)` and listeners that are depending on this reference can `listen(self, OnUpdateCallable)` or use `updated` signal, or just check `.node`.

`add(self)` will remove reference automatically when instance exits the tree, and same for listeneres using `listen(self, OnUpdateCallable)` will be disconnected on exiting tree automatically.
