>>>>>>>>>>>>>>>>>>>> ++++++[->++++++<]-
>>++++++++++ <<<<<<<<<<<<<<<<<<
+[->+]-
>.>.


+-><[],.
^v

0-f         -> {
    2 => cur_cell = 32 aka 2* 16
    f => cur_cell = 240
    0 => set cur_cell to 0

    +3 => cur_cell += 48 aka 3 * 16
    -8 => cur_cell -= 128

    1f => 31
    ff => 255
}

.[temp name], .px, .p => print cur_cell as hex col to screen, 12 bit -> 0xfff
.x
.y


70f ^ +400 [
    .y > +240 [
        .x v .[p // px] ^ -
    ]
    < -
] = set_violet

70f^+400[.y>+240[.xv.p^-]<-] = set_violet

&set_violet $set_violet
,func or ,[some identifyer] ,var // ,v // ,val

,v-.v = 1_less       # compiler should recognise the 1 ,v in there and accept 1 input to the function "1_less"
$1_less|c|.      # output should be 'b',    the whole function should be run on a parrallel tape which doesnt interfear with itsself
            #^^ note that this can be done with traditional brainfuck using an "anchor / tether" -> +[->+]- and either sacrificing 255 and 254 and- 
            #-253 for each function, or having mutliple searched / nested loops to search for N 255's ahead


macros vs function calls, same tape vs alt tape,
