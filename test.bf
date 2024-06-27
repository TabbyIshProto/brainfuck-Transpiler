# comment.
// another comment.
/ yet another comment.
/* also a comment */


[
    ^-[-v+>^]<<<<<<<<<<<--->>>>>>>>>>>>>>>> // relative movement, this initialises 255 cells with '1'.
    ^-[v<^] //moves memory tape back to cell 0.
    ++[-->++]-- = ?254
    d
    x
]

/* print sequence is 129 by 49 */