# ch64edit for C64 #

C64 character set editor

Hint: SPACE toggles pixel.  Menus are on screen.

Note: saves to FONT.BIN overwriting any existing file.   Manual load from BASIC is initially required to edit a font (after running/initializing program, and exiting).

``
LOAD "FONT.BIN",8,1
``

And wrote a [blog entry](https://techwithdave.davevw.com/2024/04/edit-vic-20-programmable-characters.html).  Includes more details on keys for operations.

![prototype](media/functional.png)

Abbreviated Memory map - C64

    0000-03FF lower RAM
    0400-07FF video RAM
    0800-17FF character RAM sets (was program RAM) ****
    3800-3FFF duplicate of second character set (temporary for display on screen)
    1800-9FFF program RAM (reduced)
    D000-D7FF character RAM set 1 (uppercase/graphics) -- banked
    D800-DFFF character RAM set 2 (lowercase/uppercase) -- banked

There is also [ch20edit](https://github.com/davervw/ch20edit) for Vic-20
