# AFL CLI

A command line interface to view standings and live scores for AFLW and AFL.

![afl ladder](assets/afl.png)



## Installation (Linux/Mac)

This tool is written in R. To run it, you'll need R installed on your machine, as well as the following packages: `dplyr`, `knitr`, `memoise`, `cachem`, `glue`, `docopt` and `fitzRoy`.

Clone this repository.

```bash
git clone https://github.com/jackhiggins458/afl_cli
```

Make `afl.R` executable.

```bash
cd afl_cli
chmod +x afl.R
```

If you want to be able to run the tool from any directory by entering `afl <command>`, you'll need to add a symlink to a directory listed in `$PATH`. I recommend using `/usr/local/bin`, but you can choose any directory in `$PATH`. From the directory you cloned `afl.R` into, run the following.

```bash
ln -s afl.R /usr/local/bin/afl
```
