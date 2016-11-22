# p5-Plugin-Pipe

## Structure
* PipeLine keep all pipes, workers
* Each pipe holds actions and given workers information

```
root                      + action31 -> action32
  |                       |
  + action1 -> pipe2 -> pipe3 -> action4
                 |
                 + action21 -> pipe22 -> action23
                                  |
                                  + action221 -> action222
```

* Each pipe executes actions, pipes in itself.
* `root` is top pipe.
* `provider` can hold own pipes and execute.
  * if `provider` is not joined to root in advance, `provider`'s pipe can be left an orphan
  * TODO : if a provider register pipe to pipeline with explicity action, then it might be solved ( not practally. )
  * provider should register array of caller of pipe. and they should be actions ( in strict mode )

* each piping pass and hold common `$data` hash ref like a brief case.
  * every pipe has own process id per each piping ( incremental number )
    * or just top pipe?
  * pipe name and process id is stacked in each piping

```
[root,0],[pipe1:0]
or
[root,1],[pipe1,10] : because a pipe can be added to several other pipe

* action also?
[root,0,0],[action1,0,0],[pipe2,0,0],[action21,0,0]

* pipeline doesn't keep whole history, but just incremental id var.
```
