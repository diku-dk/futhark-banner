# futhark-banner

Draw text in the terminal. Based on [Martin Elsman's code for
rendering Bezier curves](https://github.com/melsman/futhark-bezier).

## Compiling

```
$ make
```

## Use

```
$ ./futhark-banner X Y SCALE TEXT
```

You can pass multiple additional sets of four options to print
multiple texts. Note that the scale is inverted: larger numbers
produce smaller text.
