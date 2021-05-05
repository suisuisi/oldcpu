# FPGA project 1: MC14500B

This is my first "real" project with FPGAs: An implementation of the old MC14500B ICU.

At the moment, it is "complete-ish", with almost everything working feature wise according to initial unit tests.
There are probably still some minor errata that need to be taken care of as I haven't written anything
meaningful with it yet.


## Features

* 8 inputs and outputs
* 1 byte of RAM
* 4k bytes of ROM

## Other notes
There is one intentional errata: in a typical system, the WRITE flag is removed at the next positive edge of the clock, as opposed to the negative edge (which all other flags get removed on). However, due to the nature of the Flip-Flops in the Artix-7 powering this system, it is impossible to "double clock" and run on both positive and negative edges of a clock. Thus, there are two ways to get around this, but both involve negative side effects. The first solution is to double the clock rate, and simply ignore every other clock. This would allow for seemingly typical behavior, but would also mean it would have to cross a clock domain if it were to be dropped in to an existing system. The second is to create a doubly clocked flip flop. I have been told that this is a crime against the world, so I will not implement it. However, further research revealed that the WRITE flag behavior was so that "interlaced" memory could be used, with a 4 bit width instead of 8. As a result, this errata is irrelevant for most applications.

Another design choice that had to be made involved the bidirectional data bus of the MC14500B. Since FPGAs do not allow (to my knowledge) bidirectional lines inside the FPGA itself, a whole system could not be done on one chip. Therefore, it is possible for data to be read and written simultaneosly.
Perhaps I will add instructions to build on this behavior.
